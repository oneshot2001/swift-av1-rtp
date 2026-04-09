import XCTest
@testable import AV1RTP

final class OBUTests: XCTestCase {

    func testParseSequenceHeader() throws {
        // OBU header: type=1 (seq header), no extension, no size field
        // 0b00001000 = 0x08
        let data = Data([0x08, 0xAA, 0xBB])
        let obu = try OBUParser.parse(elementData: data)
        XCTAssertEqual(obu.type, .sequenceHeader)
        XCTAssertFalse(obu.hasExtension)
        XCTAssertNil(obu.temporalID)
        XCTAssertNil(obu.spatialID)
        XCTAssertEqual(obu.data, Data([0xAA, 0xBB]))
    }

    func testParseFrame() throws {
        // OBU header: type=6 (frame), no extension
        // 0b00110000 = 0x30
        let data = Data([0x30, 0x01, 0x02, 0x03])
        let obu = try OBUParser.parse(elementData: data)
        XCTAssertEqual(obu.type, .frame)
        XCTAssertEqual(obu.data, Data([0x01, 0x02, 0x03]))
    }

    func testParseFrameHeader() throws {
        // type=3, no extension → 0b00011000 = 0x18
        let data = Data([0x18, 0xFF])
        let obu = try OBUParser.parse(elementData: data)
        XCTAssertEqual(obu.type, .frameHeader)
    }

    func testParseTileGroup() throws {
        // type=4 → 0b00100000 = 0x20
        let data = Data([0x20, 0x00])
        let obu = try OBUParser.parse(elementData: data)
        XCTAssertEqual(obu.type, .tileGroup)
    }

    func testParseMetadata() throws {
        // type=5 → 0b00101000 = 0x28
        let data = Data([0x28])
        let obu = try OBUParser.parse(elementData: data)
        XCTAssertEqual(obu.type, .metadata)
        XCTAssertTrue(obu.data.isEmpty)
    }

    func testParsePadding() throws {
        // type=15 → 0b01111000 = 0x78
        let data = Data([0x78, 0x00, 0x00])
        let obu = try OBUParser.parse(elementData: data)
        XCTAssertEqual(obu.type, .padding)
    }

    func testParseWithExtension() throws {
        // OBU header: type=6 (frame), extension=1, no size field
        // 0b00110100 = 0x34
        // Extension byte: temporal_id=2, spatial_id=1 → 0b01001000 = 0x48
        let data = Data([0x34, 0x48, 0xDE, 0xAD])
        let obu = try OBUParser.parse(elementData: data)
        XCTAssertEqual(obu.type, .frame)
        XCTAssertTrue(obu.hasExtension)
        XCTAssertEqual(obu.temporalID, 2)
        XCTAssertEqual(obu.spatialID, 1)
        XCTAssertEqual(obu.data, Data([0xDE, 0xAD]))
    }

    func testParseEmptyDataThrows() {
        XCTAssertThrowsError(try OBUParser.parse(elementData: Data())) { error in
            XCTAssertEqual(error as? OBUParserError, .emptyData)
        }
    }

    func testParseTruncatedExtensionThrows() {
        // Extension flag set but only 1 byte total
        let data = Data([0x34])  // type=6, extension=1
        XCTAssertThrowsError(try OBUParser.parse(elementData: data)) { error in
            XCTAssertEqual(error as? OBUParserError, .truncatedExtension)
        }
    }

    func testParseUnknownTypeThrows() {
        // type=0 is reserved → 0b00000000 = 0x00
        let data = Data([0x00])
        XCTAssertThrowsError(try OBUParser.parse(elementData: data)) { error in
            guard case OBUParserError.unknownType(0) = error else {
                XCTFail("Expected unknownType(0)")
                return
            }
        }
    }

    func testHeaderOnlyOBU() throws {
        // Just the header byte, no payload
        let data = Data([0x30])  // type=6, no extension
        let obu = try OBUParser.parse(elementData: data)
        XCTAssertEqual(obu.type, .frame)
        XCTAssertTrue(obu.data.isEmpty)
    }
}
