import XCTest
@testable import AV1RTP

final class BitstreamReaderTests: XCTestCase {

    func testReadSingleBits() throws {
        // 0b10110100 = 0xB4
        var reader = BitstreamReader(data: Data([0xB4]))
        XCTAssertEqual(try reader.read(1), 1)
        XCTAssertEqual(try reader.read(1), 0)
        XCTAssertEqual(try reader.read(1), 1)
        XCTAssertEqual(try reader.read(1), 1)
        XCTAssertEqual(try reader.read(1), 0)
        XCTAssertEqual(try reader.read(1), 1)
        XCTAssertEqual(try reader.read(1), 0)
        XCTAssertEqual(try reader.read(1), 0)
        XCTAssertTrue(reader.isExhausted)
    }

    func testReadMultipleBits() throws {
        // 0b10110100 = 0xB4
        var reader = BitstreamReader(data: Data([0xB4]))
        XCTAssertEqual(try reader.read(3), 0b101) // 5
        XCTAssertEqual(try reader.read(5), 0b10100) // 20
    }

    func testReadCrossByteBoundary() throws {
        // 0xFF 0x00 → bits: 11111111 00000000
        var reader = BitstreamReader(data: Data([0xFF, 0x00]))
        XCTAssertEqual(try reader.read(4), 0xF)
        XCTAssertEqual(try reader.read(8), 0xF0)  // crosses boundary
        XCTAssertEqual(try reader.read(4), 0x00)
    }

    func testReadBool() throws {
        var reader = BitstreamReader(data: Data([0x80]))
        XCTAssertTrue(try reader.readBool())
        XCTAssertFalse(try reader.readBool())
    }

    func testRemainingBits() throws {
        var reader = BitstreamReader(data: Data([0x00, 0x00]))
        XCTAssertEqual(reader.remainingBits, 16)
        _ = try reader.read(5)
        XCTAssertEqual(reader.remainingBits, 11)
    }

    func testSkip() throws {
        var reader = BitstreamReader(data: Data([0xFF, 0x0F]))
        try reader.skip(12)
        XCTAssertEqual(try reader.read(4), 0x0F)
    }

    func testInsufficientData() {
        var reader = BitstreamReader(data: Data([0x00]))
        XCTAssertThrowsError(try reader.read(9)) { error in
            guard case BitstreamReaderError.insufficientData = error else {
                XCTFail("Expected insufficientData error")
                return
            }
        }
    }

    func testReadZeroBits() throws {
        var reader = BitstreamReader(data: Data([0xFF]))
        XCTAssertEqual(try reader.read(0), 0)
        XCTAssertEqual(reader.remainingBits, 8)
    }

    func testRead32Bits() throws {
        var reader = BitstreamReader(data: Data([0xDE, 0xAD, 0xBE, 0xEF]))
        XCTAssertEqual(try reader.read(32), 0xDEADBEEF)
    }
}
