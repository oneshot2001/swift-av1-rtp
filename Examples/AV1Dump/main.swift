import Foundation
import AV1RTP

/// av1dump — CLI tool for inspecting AV1 RTP payloads.
///
/// Usage:
///   av1dump <file.bin>          Dump OBU structure from a single RTP payload
///   av1dump --help              Show this help
///
/// Input files should contain raw RTP payload bytes (not full UDP packets).

func printUsage() {
    print("""
    av1dump — AV1 RTP payload inspector

    Usage:
      av1dump <file.bin>    Dump OBU structure from a raw RTP payload file
      av1dump --hex <hex>   Parse hex-encoded RTP payload

    Examples:
      av1dump keyframe.bin
      av1dump --hex 18080a30010480...
    """)
}

func dumpPayload(_ data: Data) {
    guard !data.isEmpty else {
        print("Error: empty input")
        return
    }

    print("Payload: \(data.count) bytes")
    print("Hex: \(data.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " "))\(data.count > 32 ? " ..." : "")")
    print()

    // Parse aggregation header
    let header = AggregationHeader(byte: data[data.startIndex])
    print("Aggregation Header: 0x\(String(format: "%02x", header.byte))")
    print("  Z (continuation): \(header.z)")
    print("  Y (will continue): \(header.y)")
    print("  W (element count): \(header.w)")
    print("  N (new sequence):  \(header.n)")
    print()

    // Extract OBU elements
    let assembler = OBUAssembler()
    do {
        let elements = try assembler.extractElements(payload: data, header: header)
        print("OBU Elements: \(elements.count)")
        print()

        for (i, element) in elements.enumerated() {
            do {
                let obu = try OBUParser.parse(elementData: element)
                print("  [\(i)] \(obuTypeName(obu.type)) (\(element.count) bytes)")
                if obu.hasExtension {
                    print("       temporal_id=\(obu.temporalID ?? 0) spatial_id=\(obu.spatialID ?? 0)")
                }
                print("       payload: \(obu.data.count) bytes")

                if obu.type == .sequenceHeader {
                    if let seqHeader = try? SequenceHeaderParser.parse(data: obu.data) {
                        print("       profile=\(seqHeader.seqProfile) level=\(seqHeader.seqLevelIdx0) tier=\(seqHeader.seqTier0 ? "High" : "Main")")
                        print("       \(seqHeader.maxFrameWidth)x\(seqHeader.maxFrameHeight)")
                        let depth = seqHeader.twelveBit ? 12 : (seqHeader.highBitdepth ? 10 : 8)
                        print("       \(depth)-bit \(seqHeader.monochrome ? "mono" : "color")")
                    }
                }
            } catch {
                print("  [\(i)] ERROR: \(error) (\(element.count) bytes)")
            }
        }
    } catch {
        print("Error extracting elements: \(error)")
    }
}

func obuTypeName(_ type: OBUType) -> String {
    switch type {
    case .sequenceHeader: return "SEQUENCE_HEADER"
    case .temporalDelimiter: return "TEMPORAL_DELIMITER"
    case .frameHeader: return "FRAME_HEADER"
    case .tileGroup: return "TILE_GROUP"
    case .metadata: return "METADATA"
    case .frame: return "FRAME"
    case .redundantFrameHeader: return "REDUNDANT_FRAME_HEADER"
    case .tileList: return "TILE_LIST"
    case .padding: return "PADDING"
    }
}

// MARK: - Main

let args = CommandLine.arguments.dropFirst()

guard !args.isEmpty else {
    printUsage()
    exit(0)
}

let firstArg = args.first!

if firstArg == "--help" || firstArg == "-h" {
    printUsage()
    exit(0)
}

if firstArg == "--hex" {
    guard args.count >= 2 else {
        print("Error: --hex requires a hex string argument")
        exit(1)
    }
    let hexString = String(args.dropFirst().first!)
    var bytes = [UInt8]()
    var chars = hexString.filter { $0.isHexDigit }.makeIterator()
    while let hi = chars.next(), let lo = chars.next() {
        if let byte = UInt8(String([hi, lo]), radix: 16) {
            bytes.append(byte)
        }
    }
    dumpPayload(Data(bytes))
} else {
    let path = firstArg
    guard let data = FileManager.default.contents(atPath: path) else {
        print("Error: cannot read file at \(path)")
        exit(1)
    }
    dumpPayload(data)
}
