import Foundation

/// A complete AV1 temporal unit — one decoded frame.
///
/// All OBUs sharing an RTP timestamp belong to one temporal unit.
/// The RTP marker bit (M=1) or a timestamp change signals the boundary.
public struct TemporalUnit: Sendable {
    /// Reassembled OBUs in this temporal unit.
    public let obus: [OBU]

    /// RTP timestamp (90kHz clock).
    public let timestamp: UInt32

    /// Whether this temporal unit starts a new coded video sequence (contains Sequence Header).
    public let isKeyframe: Bool

    /// Parsed Sequence Header, if present.
    public let sequenceHeader: SequenceHeader?

    /// Concatenated OBU data in Low Overhead Bitstream Format.
    /// Each OBU has `obu_has_size_field = 1` with leb128 size for VideoToolbox consumption.
    public var data: Data {
        var result = Data()
        for obu in obus {
            // Re-add OBU header with obu_has_size_field = 1
            var headerByte: UInt8 = (obu.type.rawValue & 0x0F) << 3
            if obu.hasExtension { headerByte |= 0x04 }
            headerByte |= 0x02  // obu_has_size_field = 1
            result.append(headerByte)

            if obu.hasExtension {
                var extByte: UInt8 = 0
                if let tid = obu.temporalID { extByte |= (tid & 0x07) << 5 }
                if let sid = obu.spatialID { extByte |= (sid & 0x03) << 3 }
                result.append(extByte)
            }

            // leb128 size of OBU payload
            result.append(LEB128.encode(UInt64(obu.data.count)))
            result.append(obu.data)
        }
        return result
    }

    public init(obus: [OBU], timestamp: UInt32, isKeyframe: Bool, sequenceHeader: SequenceHeader?) {
        self.obus = obus
        self.timestamp = timestamp
        self.isKeyframe = isKeyframe
        self.sequenceHeader = sequenceHeader
    }
}
