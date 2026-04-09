import XCTest
@testable import AV1RTP

final class RTPPacketTests: XCTestCase {

    /// Build a minimal valid RTP packet with the given payload.
    private func buildRTPData(
        marker: Bool = false,
        payloadType: UInt8 = 96,
        sequenceNumber: UInt16 = 1,
        timestamp: UInt32 = 1000,
        ssrc: UInt32 = 0x12345678,
        payload: Data
    ) -> Data {
        var data = Data(count: 12)
        data[0] = 0x80  // version=2, no padding, no extension, cc=0
        data[1] = payloadType | (marker ? 0x80 : 0x00)
        data[2] = UInt8(sequenceNumber >> 8)
        data[3] = UInt8(sequenceNumber & 0xFF)
        data[4] = UInt8(timestamp >> 24)
        data[5] = UInt8((timestamp >> 16) & 0xFF)
        data[6] = UInt8((timestamp >> 8) & 0xFF)
        data[7] = UInt8(timestamp & 0xFF)
        data[8] = UInt8(ssrc >> 24)
        data[9] = UInt8((ssrc >> 16) & 0xFF)
        data[10] = UInt8((ssrc >> 8) & 0xFF)
        data[11] = UInt8(ssrc & 0xFF)
        data.append(payload)
        return data
    }

    func testParseMinimalPacket() throws {
        let payload = Data([0x18, 0x08, 0xAA])  // W=1, N=1, seq header OBU
        let data = buildRTPData(marker: true, sequenceNumber: 42, timestamp: 90000, payload: payload)
        let packet = try RTPPacket(data: data)

        XCTAssertEqual(packet.version, 2)
        XCTAssertTrue(packet.marker)
        XCTAssertEqual(packet.payloadType, 96)
        XCTAssertEqual(packet.sequenceNumber, 42)
        XCTAssertEqual(packet.timestamp, 90000)
        XCTAssertEqual(packet.ssrc, 0x12345678)
        XCTAssertEqual(packet.payload, payload)
    }

    func testMarkerBitFalse() throws {
        let data = buildRTPData(marker: false, payload: Data([0x10, 0x30, 0x01]))
        let packet = try RTPPacket(data: data)
        XCTAssertFalse(packet.marker)
    }

    func testTooShortThrows() {
        XCTAssertThrowsError(try RTPPacket(data: Data([0x80, 0x60]))) { error in
            guard case RTPPacketError.tooShort = error else {
                XCTFail("Expected tooShort error")
                return
            }
        }
    }

    func testWrongVersionThrows() {
        var data = Data(count: 12)
        data[0] = 0x00  // version=0
        XCTAssertThrowsError(try RTPPacket(data: data)) { error in
            guard case RTPPacketError.unsupportedVersion(0) = error else {
                XCTFail("Expected unsupportedVersion(0)")
                return
            }
        }
    }

    func testConvenienceInit() {
        let packet = RTPPacket(
            marker: true,
            payloadType: 96,
            sequenceNumber: 100,
            timestamp: 3600,
            ssrc: 1,
            payload: Data([0x18, 0x08])
        )
        XCTAssertTrue(packet.marker)
        XCTAssertEqual(packet.sequenceNumber, 100)
        XCTAssertEqual(packet.timestamp, 3600)
        XCTAssertEqual(packet.payload, Data([0x18, 0x08]))
    }

    func testSequenceNumberWraparound() throws {
        let data = buildRTPData(sequenceNumber: 65535, payload: Data([0x10, 0x30]))
        let packet = try RTPPacket(data: data)
        XCTAssertEqual(packet.sequenceNumber, 65535)
    }
}
