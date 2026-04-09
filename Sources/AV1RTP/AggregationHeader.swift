import Foundation

/// AV1 RTP aggregation header (1 byte, present in every AV1 RTP packet).
///
/// ```
///  0 1 2 3 4 5 6 7
/// +-+-+-+-+-+-+-+-+
/// |Z|Y| W |N|  0  |
/// +-+-+-+-+-+-+-+-+
/// ```
///
/// Per the [AOMedia AV1 RTP Payload Format](https://aomediacodec.github.io/av1-rtp-spec/).
public struct AggregationHeader: Sendable, Equatable {
    /// First OBU element is a continuation fragment from previous packet.
    public let z: Bool

    /// Last OBU element will continue in the next packet.
    public let y: Bool

    /// OBU element count.
    /// - 0: each element has leb128 size prefix
    /// - 1, 2, 3: literal count, last element size is implicit (to end of packet)
    public let w: UInt8

    /// First packet of a new coded video sequence (contains Sequence Header).
    public let n: Bool

    public init(byte: UInt8) {
        self.z = (byte >> 7) & 1 == 1
        self.y = (byte >> 6) & 1 == 1
        self.w = (byte >> 4) & 0x03
        self.n = (byte >> 3) & 1 == 1
    }

    /// Convenience initializer for testing.
    public init(z: Bool, y: Bool, w: UInt8, n: Bool) {
        self.z = z
        self.y = y
        self.w = w
        self.n = n
    }

    /// Encode back to a single byte.
    public var byte: UInt8 {
        var b: UInt8 = 0
        if z { b |= 0x80 }
        if y { b |= 0x40 }
        b |= (w & 0x03) << 4
        if n { b |= 0x08 }
        return b
    }
}
