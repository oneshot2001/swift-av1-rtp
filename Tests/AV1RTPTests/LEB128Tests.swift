import XCTest
@testable import AV1RTP

final class LEB128Tests: XCTestCase {

    // MARK: - Decode

    func testDecodeZero() throws {
        let (value, bytesRead) = try LEB128.decode(Data([0x00]))
        XCTAssertEqual(value, 0)
        XCTAssertEqual(bytesRead, 1)
    }

    func testDecodeSingleByte() throws {
        let (value, bytesRead) = try LEB128.decode(Data([0x7F]))
        XCTAssertEqual(value, 127)
        XCTAssertEqual(bytesRead, 1)
    }

    func testDecodeTwoBytes() throws {
        // 128 = 0x80 0x01
        let (value, bytesRead) = try LEB128.decode(Data([0x80, 0x01]))
        XCTAssertEqual(value, 128)
        XCTAssertEqual(bytesRead, 2)
    }

    func testDecodeMultiByte300() throws {
        // 300 = 0xAC 0x02
        let (value, bytesRead) = try LEB128.decode(Data([0xAC, 0x02]))
        XCTAssertEqual(value, 300)
        XCTAssertEqual(bytesRead, 2)
    }

    func testDecodeWithOffset() throws {
        let data = Data([0xFF, 0xFF, 0x05])  // skip first byte
        let (value, bytesRead) = try LEB128.decode(data, offset: 2)
        XCTAssertEqual(value, 5)
        XCTAssertEqual(bytesRead, 1)
    }

    func testDecodeOverflow() {
        // 9 continuation bytes — exceeds 8-byte max
        let data = Data([0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01])
        XCTAssertThrowsError(try LEB128.decode(data)) { error in
            XCTAssertEqual(error as? LEB128Error, .overflow)
        }
    }

    func testDecodeUnexpectedEnd() {
        // Continuation bit set but no more data
        XCTAssertThrowsError(try LEB128.decode(Data([0x80]))) { error in
            XCTAssertEqual(error as? LEB128Error, .unexpectedEnd)
        }
    }

    // MARK: - Encode

    func testEncodeZero() {
        XCTAssertEqual(LEB128.encode(0), Data([0x00]))
    }

    func testEncodeSingleByte() {
        XCTAssertEqual(LEB128.encode(127), Data([0x7F]))
    }

    func testEncode128() {
        XCTAssertEqual(LEB128.encode(128), Data([0x80, 0x01]))
    }

    func testEncode300() {
        XCTAssertEqual(LEB128.encode(300), Data([0xAC, 0x02]))
    }

    // MARK: - Round-trip

    func testRoundTrip() throws {
        let values: [UInt64] = [0, 1, 127, 128, 255, 256, 300, 16383, 16384, 1_000_000]
        for value in values {
            let encoded = LEB128.encode(value)
            let (decoded, _) = try LEB128.decode(encoded)
            XCTAssertEqual(decoded, value, "Round-trip failed for \(value)")
        }
    }
}
