import XCTest
@testable import AV1RTP

final class WFieldTests: XCTestCase {

    private let assembler = OBUAssembler()

    // MARK: - W=1: Single OBU, no size prefix

    func testW1SingleOBU() throws {
        // Aggregation: W=1, N=0 → 0x10
        // OBU: type=6 (frame), no extension → 0x30, followed by payload
        let payload = Data([0x10, 0x30, 0xAA, 0xBB, 0xCC])
        let header = AggregationHeader(byte: 0x10)
        let elements = try assembler.extractElements(payload: payload, header: header)
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0], Data([0x30, 0xAA, 0xBB, 0xCC]))
    }

    // MARK: - W=2: Two OBUs, first has leb128 size, last implicit

    func testW2TwoOBUs() throws {
        // Aggregation: W=2, N=1 → 0x28
        // First element: leb128 size = 3, then 3 bytes (OBU header + 2 payload)
        // Second element: implicit size (rest of packet)
        let payload = Data([
            0x28,        // aggregation header: W=2, N=1
            0x03,        // leb128 size of first element = 3
            0x08, 0xAA, 0xBB,  // first OBU: seq header type, 2 bytes payload
            0x30, 0xCC, 0xDD   // second OBU: frame type, 2 bytes payload (implicit size)
        ])
        let header = AggregationHeader(byte: 0x28)
        let elements = try assembler.extractElements(payload: payload, header: header)
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[0], Data([0x08, 0xAA, 0xBB]))
        XCTAssertEqual(elements[1], Data([0x30, 0xCC, 0xDD]))
    }

    // MARK: - W=3: Three OBUs, first two have leb128, last implicit

    func testW3ThreeOBUs() throws {
        // Aggregation: W=3, N=0 → 0x30
        let payload = Data([
            0x30,               // aggregation header: W=3
            0x02,               // leb128 size of first element = 2
            0x08, 0xAA,         // first OBU: seq header, 1 byte payload
            0x02,               // leb128 size of second element = 2
            0x30, 0xBB,         // second OBU: frame, 1 byte payload
            0x30, 0xCC          // third OBU: frame, 1 byte payload (implicit)
        ])
        let header = AggregationHeader(byte: 0x30)
        let elements = try assembler.extractElements(payload: payload, header: header)
        XCTAssertEqual(elements.count, 3)
        XCTAssertEqual(elements[0], Data([0x08, 0xAA]))
        XCTAssertEqual(elements[1], Data([0x30, 0xBB]))
        XCTAssertEqual(elements[2], Data([0x30, 0xCC]))
    }

    // MARK: - W=0: All leb128 sizes

    func testW0VariableLength() throws {
        // Aggregation: W=0, N=0 → 0x00
        let payload = Data([
            0x00,               // aggregation header: W=0
            0x02,               // leb128 size = 2
            0x30, 0xAA,         // first OBU
            0x03,               // leb128 size = 3
            0x30, 0xBB, 0xCC   // second OBU
        ])
        let header = AggregationHeader(byte: 0x00)
        let elements = try assembler.extractElements(payload: payload, header: header)
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[0], Data([0x30, 0xAA]))
        XCTAssertEqual(elements[1], Data([0x30, 0xBB, 0xCC]))
    }

    // MARK: - Edge cases

    func testW1SingleByteOBU() throws {
        // W=1, OBU is just a header byte with no payload
        let payload = Data([0x10, 0x30])
        let header = AggregationHeader(byte: 0x10)
        let elements = try assembler.extractElements(payload: payload, header: header)
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0], Data([0x30]))
    }

    func testW2LastElementOneByte() throws {
        // W=2, last element is just 1 byte (OBU header only)
        let payload = Data([
            0x20,        // W=2
            0x02,        // first element size = 2
            0x30, 0xAA,  // first element
            0x30         // second element: just header byte (implicit size = 1)
        ])
        let header = AggregationHeader(byte: 0x20)
        let elements = try assembler.extractElements(payload: payload, header: header)
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[1], Data([0x30]))
    }

    func testEmptyPayloadThrows() {
        // Just the aggregation header, nothing else
        let payload = Data([0x10])
        let header = AggregationHeader(byte: 0x10)
        XCTAssertThrowsError(try assembler.extractElements(payload: payload, header: header))
    }
}
