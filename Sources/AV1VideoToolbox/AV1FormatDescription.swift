// AV1FormatDescription — Create CMVideoFormatDescription with av1C atoms
//
// TODO: Full implementation in v0.3.0
// Placeholder for now to ensure the module compiles.

import Foundation
import AV1RTP

#if canImport(CoreMedia)
import CoreMedia
#endif

/// Creates a `CMVideoFormatDescription` suitable for AV1 VideoToolbox decode.
///
/// Wraps the `AV1CodecConfig` record into the format description's
/// `SampleDescriptionExtensionAtoms` under the `av1C` key.
public struct AV1FormatDescription {
    /// The codec configuration used to build this format description.
    public let config: AV1CodecConfig

    #if canImport(CoreMedia)
    /// The resulting format description for VTDecompressionSession.
    /// TODO: v0.3.0 — create actual CMVideoFormatDescription
    public var cmFormatDescription: CMVideoFormatDescription? { nil }
    #endif

    public init(config: AV1CodecConfig) {
        self.config = config
    }
}
