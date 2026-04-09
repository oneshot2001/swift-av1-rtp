// AV1CodecConfig — Build AV1CodecConfigurationRecord from SequenceHeader
//
// Implements the config record structure per the av1-isobmff spec:
// https://aomediacodec.github.io/av1-isobmff/
//
// TODO: Full implementation in v0.3.0
// Placeholder for now to ensure the module compiles.

import Foundation
import AV1RTP

#if canImport(CoreMedia)
import CoreMedia
#endif

/// Builds an AV1CodecConfigurationRecord from a parsed Sequence Header.
///
/// The config record is needed to create a `CMVideoFormatDescription` for
/// VideoToolbox AV1 hardware decode.
public struct AV1CodecConfig {
    /// The source Sequence Header.
    public let sequenceHeader: SequenceHeader

    /// The raw AV1CodecConfigurationRecord bytes.
    ///
    /// Structure (per av1-isobmff spec):
    /// ```
    /// Byte 0: [marker(1)=1] [version(7)=1]
    /// Byte 1: [seq_profile(3)] [seq_level_idx_0(5)]
    /// Byte 2: [seq_tier_0(1)] [high_bitdepth(1)] [twelve_bit(1)] [monochrome(1)]
    ///          [chroma_subsampling_x(1)] [chroma_subsampling_y(1)] [chroma_sample_position(2)]
    /// Byte 3: [reserved(3)=0] [initial_presentation_delay_present(1)=0] [reserved(4)=0]
    /// Bytes 4+: configOBUs[] — Sequence Header OBU with obu_has_size_field=1
    /// ```
    public var configOBUs: Data {
        // TODO: v0.3.0 — build full config record
        Data()
    }

    public init(sequenceHeader: SequenceHeader) {
        self.sequenceHeader = sequenceHeader
    }
}
