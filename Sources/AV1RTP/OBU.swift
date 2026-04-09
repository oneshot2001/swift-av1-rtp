import Foundation

/// AV1 Open Bitstream Unit type.
public enum OBUType: UInt8, Sendable, Equatable {
    case sequenceHeader = 1
    case temporalDelimiter = 2
    case frameHeader = 3
    case tileGroup = 4
    case metadata = 5
    case frame = 6
    case redundantFrameHeader = 7
    case tileList = 8
    case padding = 15
}

/// A single Open Bitstream Unit extracted from an RTP payload.
public struct OBU: Sendable {
    /// The OBU type.
    public let type: OBUType

    /// Whether the OBU has an extension header (temporal_id, spatial_id).
    public let hasExtension: Bool

    /// Temporal ID from the extension header (nil if no extension).
    public let temporalID: UInt8?

    /// Spatial ID from the extension header (nil if no extension).
    public let spatialID: UInt8?

    /// OBU payload data (without the OBU header bytes).
    public let data: Data

    public init(type: OBUType, hasExtension: Bool, temporalID: UInt8?, spatialID: UInt8?, data: Data) {
        self.type = type
        self.hasExtension = hasExtension
        self.temporalID = temporalID
        self.spatialID = spatialID
        self.data = data
    }
}

/// Parses OBU headers from raw element data.
///
/// In RTP, OBUs have `obu_has_size_field = 0` — the size field is stripped.
/// The OBU header is 1 byte (+ 1 byte extension if present).
///
/// ```
/// OBU header byte:
///  0 1 2 3 4 5 6 7
/// +-+-+-+-+-+-+-+-+
/// |  type |X|S| 0 |
/// +-+-+-+-+-+-+-+-+
///
/// X = obu_extension_flag
/// S = obu_has_size_field (always 0 in RTP)
/// ```
public enum OBUParser {

    /// Parse a single OBU from element data (as extracted from an RTP payload).
    /// The element data starts with the OBU header byte.
    /// Returns the parsed OBU.
    public static func parse(elementData: Data) throws -> OBU {
        guard !elementData.isEmpty else {
            throw OBUParserError.emptyData
        }

        let base = elementData.startIndex
        let headerByte = elementData[base]

        let typeRaw = (headerByte >> 3) & 0x0F
        guard let type = OBUType(rawValue: typeRaw) else {
            throw OBUParserError.unknownType(typeRaw)
        }

        let extensionFlag = (headerByte >> 2) & 1 == 1
        // obu_has_size_field at bit 1 — always 0 in RTP, we don't validate

        var dataStart = 1
        var temporalID: UInt8?
        var spatialID: UInt8?

        if extensionFlag {
            guard elementData.count >= 2 else {
                throw OBUParserError.truncatedExtension
            }
            let extByte = elementData[base + 1]
            temporalID = (extByte >> 5) & 0x07
            spatialID = (extByte >> 3) & 0x03
            dataStart = 2
        }

        let payload = elementData.count > dataStart
            ? elementData[base + dataStart..<elementData.endIndex]
            : Data()

        return OBU(
            type: type,
            hasExtension: extensionFlag,
            temporalID: temporalID,
            spatialID: spatialID,
            data: payload
        )
    }
}

public enum OBUParserError: Error, Equatable {
    case emptyData
    case unknownType(UInt8)
    case truncatedExtension
}
