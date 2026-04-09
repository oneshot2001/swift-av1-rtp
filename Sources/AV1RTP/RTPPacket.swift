import Foundation

/// Minimal RTP common header parser (12 bytes minimum).
///
/// Parses the fixed 12-byte RTP header per RFC 3550. Does not handle
/// CSRC lists or header extensions — those bytes are skipped and the
/// remaining data is returned as the payload.
public struct RTPPacket: Sendable {
    /// RTP version (always 2).
    public let version: UInt8

    /// Whether the packet contains padding at the end.
    public let padding: Bool

    /// Whether the RTP marker bit is set.
    /// For AV1, this indicates the last packet of a temporal unit.
    public let marker: Bool

    /// RTP payload type number.
    public let payloadType: UInt8

    /// RTP sequence number (wraps at 65535).
    public let sequenceNumber: UInt16

    /// RTP timestamp (90kHz clock for video).
    public let timestamp: UInt32

    /// Synchronization source identifier.
    public let ssrc: UInt32

    /// Payload data after the RTP header (and any CSRC/extension).
    public let payload: Data

    public init(data: Data) throws {
        guard data.count >= 12 else {
            throw RTPPacketError.tooShort(data.count)
        }

        let base = data.startIndex

        let byte0 = data[base]
        self.version = (byte0 >> 6) & 0x03
        guard self.version == 2 else {
            throw RTPPacketError.unsupportedVersion(self.version)
        }

        self.padding = (byte0 >> 5) & 0x01 == 1
        let extensionBit = (byte0 >> 4) & 0x01 == 1
        let csrcCount = Int(byte0 & 0x0F)

        let byte1 = data[base + 1]
        self.marker = (byte1 >> 7) & 0x01 == 1
        self.payloadType = byte1 & 0x7F

        self.sequenceNumber = UInt16(data[base + 2]) << 8 | UInt16(data[base + 3])
        self.timestamp = UInt32(data[base + 4]) << 24
            | UInt32(data[base + 5]) << 16
            | UInt32(data[base + 6]) << 8
            | UInt32(data[base + 7])
        self.ssrc = UInt32(data[base + 8]) << 24
            | UInt32(data[base + 9]) << 16
            | UInt32(data[base + 10]) << 8
            | UInt32(data[base + 11])

        var offset = 12 + csrcCount * 4

        // Skip header extension if present
        if extensionBit {
            guard data.count >= offset + 4 else {
                throw RTPPacketError.tooShort(data.count)
            }
            // Extension length is in 32-bit words, at bytes offset+2..offset+3
            let extLength = Int(UInt16(data[base + offset + 2]) << 8
                | UInt16(data[base + offset + 3]))
            offset += 4 + extLength * 4
        }

        guard data.count >= offset else {
            throw RTPPacketError.tooShort(data.count)
        }

        // Handle padding
        var payloadEnd = data.count
        if self.padding && data.count > offset {
            let paddingLength = Int(data[data.startIndex + data.count - 1])
            payloadEnd = max(offset, data.count - paddingLength)
        }

        self.payload = data[base + offset..<base + payloadEnd]
    }

    /// Convenience initializer for testing — construct a packet from fields.
    public init(
        marker: Bool,
        payloadType: UInt8,
        sequenceNumber: UInt16,
        timestamp: UInt32,
        ssrc: UInt32,
        payload: Data
    ) {
        self.version = 2
        self.padding = false
        self.marker = marker
        self.payloadType = payloadType
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.ssrc = ssrc
        self.payload = payload
    }
}

public enum RTPPacketError: Error, Equatable {
    case tooShort(Int)
    case unsupportedVersion(UInt8)
}
