import Foundation

/// Bit-level reader for AV1 bitstream fields.
///
/// AV1 Sequence Headers are not byte-aligned — fields can span byte boundaries.
/// This reader tracks a bit offset into a `Data` buffer and reads arbitrary
/// numbers of bits (up to 32) at a time.
public struct BitstreamReader {
    private let data: Data
    private var bitOffset: Int

    /// Total number of bits available.
    public var totalBits: Int { data.count * 8 }

    /// Number of bits remaining to be read.
    public var remainingBits: Int { max(0, totalBits - bitOffset) }

    /// Whether all bits have been consumed.
    public var isExhausted: Bool { remainingBits == 0 }

    /// Current bit position in the stream.
    public var position: Int { bitOffset }

    public init(data: Data) {
        self.data = data
        self.bitOffset = 0
    }

    /// Read `count` bits as a `UInt32`. Maximum 32 bits per call.
    public mutating func read(_ count: Int) throws -> UInt32 {
        guard count >= 0 && count <= 32 else {
            throw BitstreamReaderError.invalidBitCount(count)
        }
        guard count == 0 || bitOffset + count <= totalBits else {
            throw BitstreamReaderError.insufficientData(
                requested: count, available: remainingBits
            )
        }
        if count == 0 { return 0 }

        var result: UInt32 = 0
        for _ in 0..<count {
            let byteIndex = bitOffset / 8
            let bitIndex = 7 - (bitOffset % 8)  // MSB first
            let bit = (UInt32(data[data.startIndex + byteIndex]) >> bitIndex) & 1
            result = (result << 1) | bit
            bitOffset += 1
        }
        return result
    }

    /// Read a single bit as a Bool.
    public mutating func readBool() throws -> Bool {
        try read(1) == 1
    }

    /// Skip `count` bits without reading.
    public mutating func skip(_ count: Int) throws {
        guard bitOffset + count <= totalBits else {
            throw BitstreamReaderError.insufficientData(
                requested: count, available: remainingBits
            )
        }
        bitOffset += count
    }
}

public enum BitstreamReaderError: Error, Equatable {
    case invalidBitCount(Int)
    case insufficientData(requested: Int, available: Int)
}
