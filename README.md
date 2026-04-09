<p align="center">
  <img src=".github/banner.svg" alt="swift-av1-rtp" width="100%">
</p>

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9+-FA7343?style=flat&logo=swift&logoColor=white" alt="Swift 5.9+"></a>
  <a href="https://developer.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-13%2B-000000?style=flat&logo=apple&logoColor=white" alt="macOS 13+"></a>
  <a href="https://developer.apple.com/ios/"><img src="https://img.shields.io/badge/iOS-16%2B-000000?style=flat&logo=apple&logoColor=white" alt="iOS 16+"></a>
  <a href="https://developer.apple.com/tvos/"><img src="https://img.shields.io/badge/tvOS-16%2B-000000?style=flat&logo=apple&logoColor=white" alt="tvOS 16+"></a>
  <a href="https://www.swift.org/package-manager/"><img src="https://img.shields.io/badge/SPM-compatible-brightgreen?style=flat" alt="SPM Compatible"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=flat" alt="MIT License"></a>
</p>

<p align="center">
  <b>The first pure Swift AV1 RTP depacketizer for Apple platforms.</b><br>
  Reassemble AV1 video from RTP streams and decode with VideoToolbox.<br>
  Zero dependencies. Built from the AOMedia spec. The 6th implementation worldwide.
</p>

---

## What is this?

`swift-av1-rtp` depacketizes AV1 video from RTP streams per the [AOMedia AV1 RTP Payload Format v1.0.0](https://aomediacodec.github.io/av1-rtp-spec/). It extracts OBU (Open Bitstream Unit) elements from RTP packets, reassembles fragmented frames, and outputs complete temporal units ready for hardware decode via Apple's VideoToolbox.

## Why?

**Zero Swift AV1 RTP implementations exist.** Only 5 implementations exist worldwide (Chromium C++, GStreamer Rust, FFmpeg C, Pion Go, MediaMTX Go). This is the 6th globally and the first on any Apple platform. As AV1 RTSP cameras ship (Axis ARTPEC-9 today, more manufacturers coming), Swift developers need a native way to consume these streams.

## Architecture

```
Raw RTP Packet (UDP payload)
        |
        v
+---------------------------+
|  RTPPacket                |  Parse 12-byte RTP header
|  - sequenceNumber         |
|  - timestamp, marker      |
+----------+----------------+
           |
           v
+---------------------------+
|  AggregationHeader        |  Parse Z/Y/W/N fields
|  + OBU Element Extraction |  Handle W=0 (leb128) and
|  + LEB128 Decoding        |  W=1/2/3 (implicit last)
+----------+----------------+
           |
           v
+---------------------------+
|  OBU Parser               |  Parse OBU headers, types,
|  + Fragment Reassembly    |  extension fields, reassemble
|                           |  fragments across packets
+----------+----------------+
           |
           v
+---------------------------+
|  TemporalUnit             |  Complete frame with all OBUs,
|  - obus: [OBU]            |  timestamp, keyframe flag,
|  - sequenceHeader         |  parsed Sequence Header
+----------+----------------+
           |
           v  (Optional AV1VideoToolbox module)
+---------------------------+
|  AV1CodecConfig           |  AV1CodecConfigurationRecord
|  AV1FormatDescription     |  CMVideoFormatDescription
|  AV1SampleBuffer          |  CMSampleBuffer for decode
+---------------------------+
```

## Quick Start

```swift
import AV1RTP

// 1. Create depacketizer
let depacketizer = AV1Depacketizer()

// 2. Feed RTP packets (from your RTSP client, WebRTC stack, or raw UDP)
let packet = try RTPPacket(data: rawUDPPayload)
let result = depacketizer.process(packet: packet)

switch result {
case .incomplete:
    break  // Waiting for more packets

case .temporalUnit(let unit):
    // Complete frame ready for decode
    unit.obus              // [OBU] — reassembled OBUs
    unit.timestamp         // UInt32 — RTP timestamp (90kHz)
    unit.isKeyframe        // Bool — contains Sequence Header
    unit.sequenceHeader    // SequenceHeader? — parsed codec config
    unit.data              // Data — OBUs in Low Overhead Bitstream Format

case .error(let error):
    // Depacketizer auto-resets, waits for next keyframe
    break
}
```

### VideoToolbox Integration (coming v0.3.0)

```swift
import AV1VideoToolbox

let config = AV1CodecConfig(sequenceHeader: unit.sequenceHeader!)
let formatDesc = AV1FormatDescription(config: config)
let sampleBuffer = AV1SampleBuffer(temporalUnit: unit, formatDescription: formatDesc)

// Feed to VTDecompressionSession or AVSampleBufferDisplayLayer
displayLayer.enqueue(sampleBuffer.cmSampleBuffer!)
```

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/oneshot2001/swift-av1-rtp.git", from: "0.1.0")
]
```

Then add to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "AV1RTP", package: "swift-av1-rtp"),
        // Optional: Apple-only VideoToolbox bridge
        .product(name: "AV1VideoToolbox", package: "swift-av1-rtp"),
    ]
)
```

### Requirements

| Platform | Minimum Version | Notes |
|----------|----------------|-------|
| macOS | 13.0+ | Core + VideoToolbox |
| iOS | 16.0+ | Core + VideoToolbox |
| tvOS | 16.0+ | Core + VideoToolbox |
| Swift | 5.9+ | |

**Hardware AV1 decode** requires M3+ (Mac) or A17 Pro+ (iPhone/iPad) at runtime. The library compiles on all listed platforms; VideoToolbox will use software decode on older hardware.

## Modules

| Module | Dependencies | Purpose |
|--------|-------------|---------|
| **AV1RTP** | Foundation only | Core depacketizer. Parses RTP packets, extracts OBUs, reassembles temporal units. Theoretically Linux-portable. |
| **AV1VideoToolbox** | AV1RTP + CoreMedia + VideoToolbox | Apple-only bridge. Builds AV1CodecConfigurationRecord, CMVideoFormatDescription, and CMSampleBuffer for hardware decode. |

## CLI Tool

The repo includes `av1dump`, a command-line tool for inspecting AV1 RTP payloads:

```bash
# Dump OBU structure from a binary file
swift run av1dump keyframe.bin

# Parse hex-encoded payload
swift run av1dump --hex 18080a30010480...
```

## Roadmap

| Version | Status | What |
|---------|--------|------|
| **v0.1.0** | **Released** | Core depacketizer, single-packet temporal units (W=0/1/2/3), 71 tests |
| v0.2.0 | Planned | Fragment reassembly (Z/Y flags), packet loss recovery, multi-packet temporal units |
| v0.3.0 | Planned | VideoToolbox module: AV1CodecConfigurationRecord, CMFormatDescription, CMSampleBuffer |
| v1.0.0 | Planned | Axis ARTPEC-9 test fixtures, AV1Player example app, full documentation |

## Spec References

- [AOMedia AV1 RTP Payload Format v1.0.0](https://aomediacodec.github.io/av1-rtp-spec/)
- [AV1 Codec ISO Media File Format Binding (av1-isobmff)](https://aomediacodec.github.io/av1-isobmff/)
- [AV1 Bitstream & Decoding Process Specification](https://aomediacodec.github.io/av1-spec/)
- [RFC 3550 — RTP](https://www.rfc-editor.org/rfc/rfc3550)

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

The most valuable contributions right now:
- **AV1 camera packet captures** — if you have access to an Axis ARTPEC-9 or any AV1-capable camera, anonymized RTP payload captures are extremely helpful
- **Testing on diverse hardware** — verify VideoToolbox decode on M3/M4/A17 Pro devices
- **Fragment reassembly edge cases** — help with v0.2.0 Z/Y flag handling

## License

MIT License. See [LICENSE](LICENSE) for details.

## Author

**Matthew Visher** -- [@oneshot2001](https://github.com/oneshot2001)

---

<p align="center">
  <sub>Built for the Swift camera ecosystem. If this library is useful to you, a star helps others find it.</sub>
</p>
