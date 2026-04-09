import Foundation

/// Parsed AV1 Sequence Header fields needed for codec configuration.
///
/// These fields are extracted by bitstream-parsing the Sequence Header OBU payload
/// per the [AV1 Bitstream Specification](https://aomediacodec.github.io/av1-spec/).
public struct SequenceHeader: Sendable, Equatable {
    /// AV1 profile: 0=Main (4:2:0/mono 8/10-bit), 1=High (4:4:4 8/10-bit), 2=Professional (all).
    public let seqProfile: UInt8

    /// Level index for operating point 0.
    public let seqLevelIdx0: UInt8

    /// Tier for operating point 0 (false=Main, true=High).
    public let seqTier0: Bool

    /// Whether bitdepth > 8.
    public let highBitdepth: Bool

    /// Whether bitdepth is 12 (only valid when profile == 2 and highBitdepth).
    public let twelveBit: Bool

    /// Monochrome (single-plane) video.
    public let monochrome: Bool

    /// Chroma subsampling in X direction.
    public let chromaSubsamplingX: Bool

    /// Chroma subsampling in Y direction.
    public let chromaSubsamplingY: Bool

    /// Chroma sample position (0=Unknown, 1=Vertical, 2=Colocated).
    public let chromaSamplePosition: UInt8

    /// Color primaries (nil if not present in bitstream).
    public let colorPrimaries: UInt8?

    /// Transfer characteristics (nil if not present in bitstream).
    public let transferCharacteristics: UInt8?

    /// Matrix coefficients (nil if not present in bitstream).
    public let matrixCoefficients: UInt8?

    /// Maximum frame width in pixels.
    public let maxFrameWidth: UInt32

    /// Maximum frame height in pixels.
    public let maxFrameHeight: UInt32

    /// Raw Sequence Header OBU bytes (without OBU header, for embedding in config records).
    public let rawOBUData: Data

    public init(
        seqProfile: UInt8,
        seqLevelIdx0: UInt8,
        seqTier0: Bool,
        highBitdepth: Bool,
        twelveBit: Bool,
        monochrome: Bool,
        chromaSubsamplingX: Bool,
        chromaSubsamplingY: Bool,
        chromaSamplePosition: UInt8,
        colorPrimaries: UInt8?,
        transferCharacteristics: UInt8?,
        matrixCoefficients: UInt8?,
        maxFrameWidth: UInt32,
        maxFrameHeight: UInt32,
        rawOBUData: Data
    ) {
        self.seqProfile = seqProfile
        self.seqLevelIdx0 = seqLevelIdx0
        self.seqTier0 = seqTier0
        self.highBitdepth = highBitdepth
        self.twelveBit = twelveBit
        self.monochrome = monochrome
        self.chromaSubsamplingX = chromaSubsamplingX
        self.chromaSubsamplingY = chromaSubsamplingY
        self.chromaSamplePosition = chromaSamplePosition
        self.colorPrimaries = colorPrimaries
        self.transferCharacteristics = transferCharacteristics
        self.matrixCoefficients = matrixCoefficients
        self.maxFrameWidth = maxFrameWidth
        self.maxFrameHeight = maxFrameHeight
        self.rawOBUData = rawOBUData
    }
}

/// Parses AV1 Sequence Header OBU payload into a `SequenceHeader`.
///
/// This is a partial parser — it extracts the fields needed for
/// `AV1CodecConfigurationRecord` construction. Full spec parsing
/// is deferred to v0.3.0.
public enum SequenceHeaderParser {

    /// Parse a Sequence Header from OBU payload data.
    public static func parse(data: Data) throws -> SequenceHeader {
        var reader = BitstreamReader(data: data)

        let seqProfile = UInt8(try reader.read(3))
        let _ = try reader.readBool()  // still_picture
        let reducedStillPictureHeader = try reader.readBool()

        var seqLevelIdx0: UInt8 = 0
        var seqTier0 = false

        if reducedStillPictureHeader {
            seqLevelIdx0 = UInt8(try reader.read(5))
            seqTier0 = false
        } else {
            let timingInfoPresent = try reader.readBool()
            if timingInfoPresent {
                // num_units_in_display_tick (32) + time_scale (32)
                try reader.skip(64)
                let equalPictureInterval = try reader.readBool()
                if equalPictureInterval {
                    // num_ticks_per_picture_minus_1 as uvlc
                    _ = try readUVLC(&reader)
                }
            }

            let decoderModelInfoPresent = try reader.readBool()
            if decoderModelInfoPresent {
                // buffer_delay_length_minus_1 (5) + num_units_in_decoding_tick (32)
                // + buffer_removal_time_length_minus_1 (5) + frame_presentation_time_length_minus_1 (5)
                try reader.skip(47)
            }

            let operatingPointsCntMinus1 = Int(try reader.read(5))
            for i in 0...operatingPointsCntMinus1 {
                // operating_point_idc (12) + seq_level_idx (5)
                let _ = try reader.read(12)  // operating_point_idc
                let levelIdx = UInt8(try reader.read(5))
                if i == 0 { seqLevelIdx0 = levelIdx }

                var tier = false
                if levelIdx > 7 {
                    tier = try reader.readBool()
                }
                if i == 0 { seqTier0 = tier }

                if decoderModelInfoPresent {
                    let decoderModelPresent = try reader.readBool()
                    if decoderModelPresent {
                        // operating_parameters_info — skip for now
                        // This is complex; we only need profile/level/color for config
                        // TODO: Full parsing in v0.3.0
                    }
                }

                // initial_display_delay_present_for_this_op not present when
                // initial_display_delay_present_flag is 0 (simplified path)
            }
        }

        // frame_width_bits_minus_1 (4) + frame_height_bits_minus_1 (4)
        let frameWidthBits = Int(try reader.read(4)) + 1
        let frameHeightBits = Int(try reader.read(4)) + 1
        let maxFrameWidth = try reader.read(frameWidthBits) + 1
        let maxFrameHeight = try reader.read(frameHeightBits) + 1

        // For reduced_still_picture_header, frame_id is not used
        if !reducedStillPictureHeader {
            let frameIdNumbersPresent = try reader.readBool()
            if frameIdNumbersPresent {
                // delta_frame_id_length_minus_2 (4) + additional_frame_id_length_minus_1 (3)
                try reader.skip(7)
            }
        }

        // use_128x128_superblock, enable_filter_intra, enable_intra_edge_filter
        try reader.skip(3)

        if !reducedStillPictureHeader {
            // enable_interintra_compound, enable_masked_compound,
            // enable_warped_motion, enable_dual_filter, enable_order_hint
            let _ = try reader.read(4) // skip 4 flags
            let enableOrderHint = try reader.readBool()
            if enableOrderHint {
                // enable_jnt_comp, enable_ref_frame_mvs
                try reader.skip(2)
            }

            let seqChooseScreenContentTools = try reader.readBool()
            var seqForceScreenContentTools: UInt32 = 2 // SELECT_SCREEN_CONTENT_TOOLS
            if !seqChooseScreenContentTools {
                seqForceScreenContentTools = try reader.read(1)
            }

            if seqForceScreenContentTools > 0 {
                let seqChooseIntegerMv = try reader.readBool()
                if !seqChooseIntegerMv {
                    try reader.skip(1) // seq_force_integer_mv
                }
            }

            if enableOrderHint {
                try reader.skip(3) // order_hint_bits_minus_1
            }
        }

        // enable_superres, enable_cdef, enable_restoration
        try reader.skip(3)

        // color_config
        let highBitdepth = try reader.readBool()
        var twelveBit = false
        if seqProfile == 2 && highBitdepth {
            twelveBit = try reader.readBool()
        }

        var monochrome = false
        if seqProfile != 1 {
            monochrome = try reader.readBool()
        }

        let colorDescriptionPresent = try reader.readBool()
        var colorPrimaries: UInt8?
        var transferCharacteristics: UInt8?
        var matrixCoefficients: UInt8?

        if colorDescriptionPresent {
            colorPrimaries = UInt8(try reader.read(8))
            transferCharacteristics = UInt8(try reader.read(8))
            matrixCoefficients = UInt8(try reader.read(8))
        }

        var chromaSubsamplingX = false
        var chromaSubsamplingY = false
        var chromaSamplePosition: UInt8 = 0 // CSP_UNKNOWN

        if monochrome {
            // No chroma info for monochrome
            chromaSubsamplingX = true
            chromaSubsamplingY = true
        } else {
            let cp = colorPrimaries ?? 2  // CP_UNSPECIFIED
            let tc = transferCharacteristics ?? 2
            let mc = matrixCoefficients ?? 2

            let bitDepth: Int = twelveBit ? 12 : (highBitdepth ? 10 : 8)
            let isSRGB = cp == 1 && tc == 13 && mc == 0

            if isSRGB || seqProfile == 1 {
                // 4:4:4
                chromaSubsamplingX = false
                chromaSubsamplingY = false
            } else if seqProfile == 2 {
                if bitDepth == 12 {
                    chromaSubsamplingX = try reader.readBool()
                    if chromaSubsamplingX {
                        chromaSubsamplingY = try reader.readBool()
                    }
                } else {
                    // 4:2:2
                    chromaSubsamplingX = true
                    chromaSubsamplingY = false
                }
            } else {
                // Profile 0 — always 4:2:0
                chromaSubsamplingX = true
                chromaSubsamplingY = true
            }

            if chromaSubsamplingX && chromaSubsamplingY {
                chromaSamplePosition = UInt8(try reader.read(2))
            }
        }

        // separate_uv_delta_q
        if !monochrome {
            try reader.skip(1)
        }

        return SequenceHeader(
            seqProfile: seqProfile,
            seqLevelIdx0: seqLevelIdx0,
            seqTier0: seqTier0,
            highBitdepth: highBitdepth,
            twelveBit: twelveBit,
            monochrome: monochrome,
            chromaSubsamplingX: chromaSubsamplingX,
            chromaSubsamplingY: chromaSubsamplingY,
            chromaSamplePosition: chromaSamplePosition,
            colorPrimaries: colorPrimaries,
            transferCharacteristics: transferCharacteristics,
            matrixCoefficients: matrixCoefficients,
            maxFrameWidth: maxFrameWidth,
            maxFrameHeight: maxFrameHeight,
            rawOBUData: data
        )
    }

    /// Read unsigned variable-length code (uvlc) from the bitstream.
    private static func readUVLC(_ reader: inout BitstreamReader) throws -> UInt32 {
        var leadingZeros = 0
        while true {
            let bit = try reader.readBool()
            if bit { break }
            leadingZeros += 1
            if leadingZeros > 32 {
                throw SequenceHeaderParserError.invalidUVLC
            }
        }
        if leadingZeros >= 32 {
            return UInt32.max
        }
        let value = try reader.read(leadingZeros)
        return value + (1 << leadingZeros) - 1
    }
}

public enum SequenceHeaderParserError: Error, Equatable {
    case invalidUVLC
}
