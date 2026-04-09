import XCTest
@testable import AV1RTP

final class AggregationHeaderTests: XCTestCase {

    func testAllZeros() {
        let header = AggregationHeader(byte: 0x00)
        XCTAssertFalse(header.z)
        XCTAssertFalse(header.y)
        XCTAssertEqual(header.w, 0)
        XCTAssertFalse(header.n)
    }

    func testZFlagSet() {
        let header = AggregationHeader(byte: 0x80)
        XCTAssertTrue(header.z)
        XCTAssertFalse(header.y)
        XCTAssertEqual(header.w, 0)
        XCTAssertFalse(header.n)
    }

    func testYFlagSet() {
        let header = AggregationHeader(byte: 0x40)
        XCTAssertFalse(header.z)
        XCTAssertTrue(header.y)
        XCTAssertEqual(header.w, 0)
        XCTAssertFalse(header.n)
    }

    func testW1() {
        let header = AggregationHeader(byte: 0x10)
        XCTAssertEqual(header.w, 1)
    }

    func testW2() {
        let header = AggregationHeader(byte: 0x20)
        XCTAssertEqual(header.w, 2)
    }

    func testW3() {
        let header = AggregationHeader(byte: 0x30)
        XCTAssertEqual(header.w, 3)
    }

    func testNFlagSet() {
        let header = AggregationHeader(byte: 0x08)
        XCTAssertFalse(header.z)
        XCTAssertFalse(header.y)
        XCTAssertEqual(header.w, 0)
        XCTAssertTrue(header.n)
    }

    func testW1WithN() {
        // W=1, N=1 → 0x18
        let header = AggregationHeader(byte: 0x18)
        XCTAssertFalse(header.z)
        XCTAssertFalse(header.y)
        XCTAssertEqual(header.w, 1)
        XCTAssertTrue(header.n)
    }

    func testAllFlagsSet() {
        // Z=1, Y=1, W=3, N=1 → 0b11111000 = 0xF8
        let header = AggregationHeader(byte: 0xF8)
        XCTAssertTrue(header.z)
        XCTAssertTrue(header.y)
        XCTAssertEqual(header.w, 3)
        XCTAssertTrue(header.n)
    }

    func testByteRoundTrip() {
        for byte: UInt8 in [0x00, 0x08, 0x10, 0x18, 0x20, 0x30, 0x40, 0x80, 0xF8] {
            let header = AggregationHeader(byte: byte)
            XCTAssertEqual(header.byte, byte, "Round-trip failed for 0x\(String(format: "%02x", byte))")
        }
    }

    func testConvenienceInit() {
        let header = AggregationHeader(z: true, y: false, w: 2, n: true)
        XCTAssertTrue(header.z)
        XCTAssertFalse(header.y)
        XCTAssertEqual(header.w, 2)
        XCTAssertTrue(header.n)
        XCTAssertEqual(header.byte, 0xA8)
    }

    func testReservedBitsIgnored() {
        // Reserved bits (lower 3) should not affect Z/Y/W/N
        let headerA = AggregationHeader(byte: 0x18)
        let headerB = AggregationHeader(byte: 0x1F)  // reserved bits set
        XCTAssertEqual(headerA.z, headerB.z)
        XCTAssertEqual(headerA.y, headerB.y)
        XCTAssertEqual(headerA.w, headerB.w)
        XCTAssertEqual(headerA.n, headerB.n)
    }
}
