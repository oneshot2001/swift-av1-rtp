import Foundation

/// leb128 (Little Endian Base 128) variable-length unsigned integer encoding.
///
/// Used in AV1 RTP payloads for OBU element sizes when W=0,
/// and for all-but-last element sizes when W>1.
/// Each byte: 7 data bits (LSB first) + 1 continuation bit (MSB).
/// Maximum 8 bytes (56 bits of data).
public enum LEB128 {

    /// Decode a leb128 value from the given data starting at `offset`.
    /// Returns the decoded value and the number of bytes consumed.
    public static func decode(_ data: Data, offset: Int = 0) throws -> (value: UInt64, bytesRead: Int) {
        var result: UInt64 = 0
        var bytesRead = 0
        let maxBytes = 8  // AV1 spec: leb128 max 8 bytes

        while true {
            guard offset + bytesRead < data.count else {
                throw LEB128Error.unexpectedEnd
            }

            let byte = data[data.startIndex + offset + bytesRead]
            let value = UInt64(byte & 0x7F)
            result |= value << (7 * bytesRead)
            bytesRead += 1

            // No continuation bit — we're done
            if byte & 0x80 == 0 {
                return (result, bytesRead)
            }

            if bytesRead >= maxBytes {
                throw LEB128Error.overflow
            }
        }
    }

    /// Encode a `UInt64` value as leb128 bytes.
    public static func encode(_ value: UInt64) -> Data {
        if value == 0 {
            return Data([0x00])
        }

        var remaining = value
        var bytes = [UInt8]()

        while remaining > 0 {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining > 0 {
                byte |= 0x80  // Set continuation bit
            }
            bytes.append(byte)
        }

        return Data(bytes)
    }
}

public enum LEB128Error: Error, Equatable {
    case overflow
    case unexpectedEnd
}
