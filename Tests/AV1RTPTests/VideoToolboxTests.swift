import XCTest
@testable import AV1RTP
@testable import AV1VideoToolbox

final class VideoToolboxTests: XCTestCase {

    func testAV1CodecConfigInit() {
        let seqHeader = SequenceHeader(
            seqProfile: 0,
            seqLevelIdx0: 8,
            seqTier0: false,
            highBitdepth: false,
            twelveBit: false,
            monochrome: false,
            chromaSubsamplingX: true,
            chromaSubsamplingY: true,
            chromaSamplePosition: 0,
            colorPrimaries: nil,
            transferCharacteristics: nil,
            matrixCoefficients: nil,
            maxFrameWidth: 1920,
            maxFrameHeight: 1080,
            rawOBUData: Data([0x00, 0x01, 0x02])
        )

        let config = AV1CodecConfig(sequenceHeader: seqHeader)
        XCTAssertEqual(config.sequenceHeader.seqProfile, 0)
        XCTAssertEqual(config.sequenceHeader.maxFrameWidth, 1920)
        // configOBUs is stub for now
        XCTAssertTrue(config.configOBUs.isEmpty)
    }

    func testAV1FormatDescriptionInit() {
        let seqHeader = SequenceHeader(
            seqProfile: 0,
            seqLevelIdx0: 8,
            seqTier0: false,
            highBitdepth: false,
            twelveBit: false,
            monochrome: false,
            chromaSubsamplingX: true,
            chromaSubsamplingY: true,
            chromaSamplePosition: 0,
            colorPrimaries: nil,
            transferCharacteristics: nil,
            matrixCoefficients: nil,
            maxFrameWidth: 3840,
            maxFrameHeight: 2160,
            rawOBUData: Data()
        )

        let config = AV1CodecConfig(sequenceHeader: seqHeader)
        let formatDesc = AV1FormatDescription(config: config)
        XCTAssertEqual(formatDesc.config.sequenceHeader.maxFrameWidth, 3840)
    }

    func testAV1SampleBufferInit() {
        let obu = OBU(type: .frame, hasExtension: false, temporalID: nil, spatialID: nil, data: Data([0xDE, 0xAD]))
        let tu = TemporalUnit(obus: [obu], timestamp: 90000, isKeyframe: false, sequenceHeader: nil)

        let seqHeader = SequenceHeader(
            seqProfile: 0, seqLevelIdx0: 8, seqTier0: false,
            highBitdepth: false, twelveBit: false, monochrome: false,
            chromaSubsamplingX: true, chromaSubsamplingY: true,
            chromaSamplePosition: 0, colorPrimaries: nil,
            transferCharacteristics: nil, matrixCoefficients: nil,
            maxFrameWidth: 1920, maxFrameHeight: 1080, rawOBUData: Data()
        )
        let config = AV1CodecConfig(sequenceHeader: seqHeader)
        let formatDesc = AV1FormatDescription(config: config)

        let sampleBuffer = AV1SampleBuffer(temporalUnit: tu, formatDescription: formatDesc)
        XCTAssertEqual(sampleBuffer.temporalUnit.timestamp, 90000)
    }
}
