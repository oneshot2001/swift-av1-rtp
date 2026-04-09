import Foundation

/// Processing result from the depacketizer.
public enum DepacketizerResult: Sendable {
    /// Fragment received, waiting for more packets to complete the temporal unit.
    case incomplete
    /// Complete temporal unit ready for decode.
    case temporalUnit(TemporalUnit)
    /// Error encountered — depacketizer auto-resets and waits for next keyframe.
    case error(AV1DepacketizerError)
}

/// Depacketizer error types.
public enum AV1DepacketizerError: Error, Sendable, Equatable {
    case packetLoss(expected: UInt16, received: UInt16)
    case malformedAggregationHeader
    case invalidOBUHeader
    case leb128Overflow
    case unexpectedFragment
    case emptyPayload
}

/// Depacketizer state.
public enum DepacketizerState: Sendable, Equatable {
    /// Waiting for a keyframe (N=1) to start processing.
    case waitingForKeyframe
    /// Actively processing packets.
    case active
    /// Assembling a fragmented OBU across packets (v0.2.0).
    case assemblingFragment
}

/// Runtime statistics.
public struct DepacketizerStats: Sendable {
    public var packetsProcessed: UInt64 = 0
    public var temporalUnitsEmitted: UInt64 = 0
    public var fragmentsReassembled: UInt64 = 0
    public var packetsDropped: UInt64 = 0
    public var errorsRecovered: UInt64 = 0
}

/// Stateful AV1 RTP depacketizer.
///
/// Feed RTP packets in order. The depacketizer reassembles OBU elements,
/// tracks temporal unit boundaries (via marker bit and timestamp changes),
/// and outputs complete `TemporalUnit` values.
///
/// v0.1.0 supports single-packet temporal units (W=1/2/3).
/// Fragment reassembly (Z/Y flags) arrives in v0.2.0.
public final class AV1Depacketizer {

    /// Current depacketizer state.
    public private(set) var state: DepacketizerState = .waitingForKeyframe

    /// Runtime statistics.
    public private(set) var stats = DepacketizerStats()

    private let assembler = OBUAssembler()
    private var currentOBUs: [OBU] = []
    private var currentTimestamp: UInt32?
    private var currentIsKeyframe = false
    private var currentSequenceHeader: SequenceHeader?
    private var lastSequenceNumber: UInt16?

    public init() {}

    /// Process a single RTP packet and return the result.
    ///
    /// - Parameter packet: A parsed RTP packet containing an AV1 payload.
    /// - Returns: `.incomplete` if more packets needed, `.temporalUnit` when a
    ///   complete frame is ready, or `.error` if something went wrong.
    public func process(packet: RTPPacket) -> DepacketizerResult {
        stats.packetsProcessed += 1

        guard !packet.payload.isEmpty else {
            stats.packetsDropped += 1
            return .error(.emptyPayload)
        }

        // Parse aggregation header
        let header = AggregationHeader(byte: packet.payload[packet.payload.startIndex])

        // Check for packet loss
        if let lastSeq = lastSequenceNumber {
            let expected = lastSeq &+ 1
            if packet.sequenceNumber != expected {
                stats.packetsDropped += 1
                stats.errorsRecovered += 1
                resetState()
                return .error(.packetLoss(expected: expected, received: packet.sequenceNumber))
            }
        }
        lastSequenceNumber = packet.sequenceNumber

        // v0.1.0: Reject fragmented packets (Z or Y flags)
        if header.z || header.y {
            stats.packetsDropped += 1
            return .error(.unexpectedFragment)
        }

        // If waiting for keyframe, only accept packets with N=1
        if state == .waitingForKeyframe && !header.n {
            stats.packetsDropped += 1
            return .incomplete
        }

        // Timestamp change flushes the current temporal unit
        if let currentTS = currentTimestamp, currentTS != packet.timestamp && !currentOBUs.isEmpty {
            let result = flushTemporalUnit()
            // Start new temporal unit with this packet
            currentTimestamp = packet.timestamp
            currentIsKeyframe = header.n
            currentSequenceHeader = nil
            currentOBUs = []
            processPacketOBUs(packet: packet, header: header)
            return result
        }

        // Track temporal unit state
        if currentTimestamp == nil || currentTimestamp != packet.timestamp {
            currentTimestamp = packet.timestamp
            currentIsKeyframe = header.n
            currentSequenceHeader = nil
            currentOBUs = []
        }

        if header.n {
            currentIsKeyframe = true
            state = .active
        }

        // Extract and parse OBUs
        processPacketOBUs(packet: packet, header: header)

        // Marker bit signals last packet of temporal unit
        if packet.marker {
            return flushTemporalUnit()
        }

        return .incomplete
    }

    /// Reset the depacketizer state (e.g., on stream switch or seek).
    public func reset() {
        resetState()
        stats = DepacketizerStats()
    }

    // MARK: - Private

    private func processPacketOBUs(packet: RTPPacket, header: AggregationHeader) {
        do {
            let elements = try assembler.extractElements(payload: packet.payload, header: header)
            for elementData in elements {
                let obu = try OBUParser.parse(elementData: elementData)

                // Parse Sequence Header if present
                if obu.type == .sequenceHeader {
                    if let seqHeader = try? SequenceHeaderParser.parse(data: obu.data) {
                        currentSequenceHeader = seqHeader
                    }
                }

                // Skip padding OBUs
                if obu.type == .padding { continue }

                currentOBUs.append(obu)
            }
        } catch {
            // Errors during OBU extraction — packet is malformed
            stats.packetsDropped += 1
        }
    }

    private func flushTemporalUnit() -> DepacketizerResult {
        guard !currentOBUs.isEmpty, let timestamp = currentTimestamp else {
            return .incomplete
        }

        let unit = TemporalUnit(
            obus: currentOBUs,
            timestamp: timestamp,
            isKeyframe: currentIsKeyframe,
            sequenceHeader: currentSequenceHeader
        )

        stats.temporalUnitsEmitted += 1
        currentOBUs = []
        currentTimestamp = nil
        currentIsKeyframe = false
        currentSequenceHeader = nil

        return .temporalUnit(unit)
    }

    private func resetState() {
        state = .waitingForKeyframe
        currentOBUs = []
        currentTimestamp = nil
        currentIsKeyframe = false
        currentSequenceHeader = nil
        lastSequenceNumber = nil
    }
}
