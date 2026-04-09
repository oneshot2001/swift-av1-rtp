// AV1SampleBuffer — Create CMSampleBuffer from TemporalUnit
//
// TODO: Full implementation in v0.3.0
// Placeholder for now to ensure the module compiles.

import Foundation
import AV1RTP

#if canImport(CoreMedia)
import CoreMedia
#endif

/// Creates a `CMSampleBuffer` from a depacketized AV1 temporal unit.
///
/// The sample buffer wraps the temporal unit's OBU data in a `CMBlockBuffer`
/// and attaches the format description and timing info.
public struct AV1SampleBuffer {
    /// The source temporal unit.
    public let temporalUnit: TemporalUnit

    /// The format description for this sample.
    public let formatDescription: AV1FormatDescription

    #if canImport(CoreMedia)
    /// The resulting sample buffer for VTDecompressionSession or AVSampleBufferDisplayLayer.
    /// TODO: v0.3.0 — create actual CMSampleBuffer
    public var cmSampleBuffer: CMSampleBuffer? { nil }
    #endif

    public init(temporalUnit: TemporalUnit, formatDescription: AV1FormatDescription) {
        self.temporalUnit = temporalUnit
        self.formatDescription = formatDescription
    }
}
