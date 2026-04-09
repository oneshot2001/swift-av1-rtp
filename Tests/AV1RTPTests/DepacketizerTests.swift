import XCTest
@testable import AV1RTP

final class DepacketizerTests: XCTestCase {

    // MARK: - Basic temporal unit emission

    func testSinglePacketKeyframe() {
        let depak = AV1Depacketizer()

        // W=1, N=1 keyframe with sequence header OBU
        let payload = Data([0x18, 0x08, 0xAA, 0xBB])
        let packet = RTPPacket(
            marker: true,
            payloadType: 96,
            sequenceNumber: 1,
            timestamp: 90000,
            ssrc: 1,
            payload: payload
        )

        let result = depak.process(packet: packet)
        if case .temporalUnit(let unit) = result {
            XCTAssertTrue(unit.isKeyframe)
            XCTAssertEqual(unit.timestamp, 90000)
            XCTAssertEqual(unit.obus.count, 1)
            XCTAssertEqual(unit.obus[0].type, .sequenceHeader)
        } else {
            XCTFail("Expected temporalUnit, got \(result)")
        }
    }

    func testSinglePacketInterframe() {
        let depak = AV1Depacketizer()

        // First: keyframe to activate
        let kfPayload = Data([0x18, 0x08, 0xAA])
        let kfPacket = RTPPacket(marker: true, payloadType: 96, sequenceNumber: 1, timestamp: 90000, ssrc: 1, payload: kfPayload)
        _ = depak.process(packet: kfPacket)

        // Second: interframe (W=1, N=0)
        let ifPayload = Data([0x10, 0x30, 0xCC, 0xDD])
        let ifPacket = RTPPacket(marker: true, payloadType: 96, sequenceNumber: 2, timestamp: 93000, ssrc: 1, payload: ifPayload)

        let result = depak.process(packet: ifPacket)
        if case .temporalUnit(let unit) = result {
            XCTAssertFalse(unit.isKeyframe)
            XCTAssertEqual(unit.timestamp, 93000)
            XCTAssertEqual(unit.obus.count, 1)
            XCTAssertEqual(unit.obus[0].type, .frame)
        } else {
            XCTFail("Expected temporalUnit, got \(result)")
        }
    }

    // MARK: - W=2 multi-OBU packet

    func testW2KeyframeWithSeqHeaderAndFrame() {
        let depak = AV1Depacketizer()

        // W=2, N=1: Sequence Header + Frame in one packet
        let payload = Data([
            0x28,                       // W=2, N=1
            0x03,                       // first element size = 3
            0x08, 0xAA, 0xBB,          // seq header OBU
            0x30, 0xCC, 0xDD, 0xEE     // frame OBU (implicit size)
        ])
        let packet = RTPPacket(marker: true, payloadType: 96, sequenceNumber: 1, timestamp: 90000, ssrc: 1, payload: payload)

        let result = depak.process(packet: packet)
        if case .temporalUnit(let unit) = result {
            XCTAssertTrue(unit.isKeyframe)
            XCTAssertEqual(unit.obus.count, 2)
            XCTAssertEqual(unit.obus[0].type, .sequenceHeader)
            XCTAssertEqual(unit.obus[1].type, .frame)
        } else {
            XCTFail("Expected temporalUnit, got \(result)")
        }
    }

    // MARK: - Waiting for keyframe

    func testRejectsInterframeBeforeKeyframe() {
        let depak = AV1Depacketizer()
        XCTAssertEqual(depak.state, .waitingForKeyframe)

        // Interframe without preceding keyframe
        let payload = Data([0x10, 0x30, 0xAA])
        let packet = RTPPacket(marker: true, payloadType: 96, sequenceNumber: 1, timestamp: 90000, ssrc: 1, payload: payload)

        let result = depak.process(packet: packet)
        if case .incomplete = result {
            // Expected: dropped because waiting for keyframe
        } else {
            XCTFail("Expected incomplete, got \(result)")
        }
    }

    // MARK: - Packet loss detection

    func testPacketLossDetected() {
        let depak = AV1Depacketizer()

        // Keyframe
        let kf = RTPPacket(marker: true, payloadType: 96, sequenceNumber: 1, timestamp: 90000, ssrc: 1, payload: Data([0x18, 0x08, 0xAA]))
        _ = depak.process(packet: kf)

        // Skip seq 2, send seq 3
        let p3 = RTPPacket(marker: true, payloadType: 96, sequenceNumber: 3, timestamp: 96000, ssrc: 1, payload: Data([0x10, 0x30, 0xBB]))
        let result = depak.process(packet: p3)

        if case .error(.packetLoss(let expected, let received)) = result {
            XCTAssertEqual(expected, 2)
            XCTAssertEqual(received, 3)
        } else {
            XCTFail("Expected packetLoss error, got \(result)")
        }

        // After packet loss, should be back to waitingForKeyframe
        XCTAssertEqual(depak.state, .waitingForKeyframe)
    }

    // MARK: - Empty payload

    func testEmptyPayloadError() {
        let depak = AV1Depacketizer()
        let packet = RTPPacket(marker: true, payloadType: 96, sequenceNumber: 1, timestamp: 90000, ssrc: 1, payload: Data())
        let result = depak.process(packet: packet)
        if case .error(.emptyPayload) = result {
            // Expected
        } else {
            XCTFail("Expected emptyPayload error")
        }
    }

    // MARK: - Fragment rejection (v0.1.0)

    func testFragmentedPacketRejected() {
        let depak = AV1Depacketizer()

        // Y=1 (fragment continues) — not supported in v0.1.0
        let payload = Data([0x58, 0x30, 0xAA])  // Y=1, W=1, N=1
        let packet = RTPPacket(marker: false, payloadType: 96, sequenceNumber: 1, timestamp: 90000, ssrc: 1, payload: payload)
        let result = depak.process(packet: packet)
        if case .error(.unexpectedFragment) = result {
            // Expected
        } else {
            XCTFail("Expected unexpectedFragment error")
        }
    }

    // MARK: - Statistics

    func testStatsTracking() {
        let depak = AV1Depacketizer()

        let kf = RTPPacket(marker: true, payloadType: 96, sequenceNumber: 1, timestamp: 90000, ssrc: 1, payload: Data([0x18, 0x08, 0xAA]))
        _ = depak.process(packet: kf)

        XCTAssertEqual(depak.stats.packetsProcessed, 1)
        XCTAssertEqual(depak.stats.temporalUnitsEmitted, 1)
    }

    // MARK: - Reset

    func testReset() {
        let depak = AV1Depacketizer()

        let kf = RTPPacket(marker: true, payloadType: 96, sequenceNumber: 1, timestamp: 90000, ssrc: 1, payload: Data([0x18, 0x08, 0xAA]))
        _ = depak.process(packet: kf)
        XCTAssertEqual(depak.state, .active)

        depak.reset()
        XCTAssertEqual(depak.state, .waitingForKeyframe)
        XCTAssertEqual(depak.stats.packetsProcessed, 0)
    }

    // MARK: - Timestamp change flushes

    func testTimestampChangeFlushes() {
        let depak = AV1Depacketizer()

        // First packet: keyframe, no marker (multi-packet TU)
        let p1 = RTPPacket(marker: false, payloadType: 96, sequenceNumber: 1, timestamp: 90000, ssrc: 1, payload: Data([0x18, 0x08, 0xAA]))
        let r1 = depak.process(packet: p1)
        if case .incomplete = r1 {} else { XCTFail("Expected incomplete") }

        // Second packet: different timestamp — should flush the first TU
        let p2 = RTPPacket(marker: true, payloadType: 96, sequenceNumber: 2, timestamp: 93000, ssrc: 1, payload: Data([0x10, 0x30, 0xBB]))
        let r2 = depak.process(packet: p2)

        // Should get the first TU flushed by timestamp change
        if case .temporalUnit(let unit) = r2 {
            XCTAssertEqual(unit.timestamp, 90000)
        } else {
            XCTFail("Expected temporalUnit from timestamp flush, got \(r2)")
        }
    }

    // MARK: - Padding OBU skipped

    func testPaddingOBUSkipped() {
        let depak = AV1Depacketizer()

        // W=2, N=1: Sequence Header + Padding
        let payload = Data([
            0x28,                       // W=2, N=1
            0x03,                       // first element size = 3
            0x08, 0xAA, 0xBB,          // seq header
            0x78, 0x00, 0x00            // padding OBU (type=15)
        ])
        let packet = RTPPacket(marker: true, payloadType: 96, sequenceNumber: 1, timestamp: 90000, ssrc: 1, payload: payload)
        let result = depak.process(packet: packet)

        if case .temporalUnit(let unit) = result {
            // Padding should be filtered out
            XCTAssertEqual(unit.obus.count, 1)
            XCTAssertEqual(unit.obus[0].type, .sequenceHeader)
        } else {
            XCTFail("Expected temporalUnit")
        }
    }
}
