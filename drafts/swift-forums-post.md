# Swift Forums Post — Ready to Copy/Paste

**Category:** Community Showcase
**Title:** swift-av1-rtp — Pure Swift AV1 RTP depacketizer for Apple platforms

---

Hey everyone,

AV1 is the next-gen video codec — royalty-free, 30-50% better compression than HEVC, backed by every major tech company through the Alliance for Open Media. IP cameras are starting to ship AV1 RTSP streams (Axis Communications has the first SoC). WebRTC already supports it.

There are AV1 RTP depacketizers for C++ (Chromium), Rust (GStreamer), C (FFmpeg), and Go (Pion). Nothing for Swift. So I built one from the [AOMedia AV1 RTP Payload Format spec](https://aomediacodec.github.io/av1-rtp-spec/).

**swift-av1-rtp** is a pure Swift library that depacketizes AV1 video from RTP streams. Zero dependencies (Foundation only for the core module), SPM-compatible, MIT licensed.

What you get in v0.1.0:

- **RTP packet parsing** — 12-byte common header with CSRC and extension handling
- **Aggregation header** — Z/Y/W/N field parsing per the AV1 RTP spec
- **OBU extraction** — handles W=0 (leb128 variable-length sizes), W=1/2/3 (implicit last element)
- **Sequence Header parsing** — full bitstream reader for extracting codec configuration (profile, level, resolution, color config)
- **Temporal unit assembly** — collects OBUs per RTP timestamp, flushes on marker bit or timestamp change
- **Error recovery** — detects packet loss via sequence number gaps, auto-resets to wait for next keyframe

```swift
import AV1RTP

let depacketizer = AV1Depacketizer()
let packet = try RTPPacket(data: rawUDPPayload)
let result = depacketizer.process(packet: packet)

switch result {
case .temporalUnit(let unit):
    // Complete frame — ready for decode
    print("\(unit.obus.count) OBUs, keyframe=\(unit.isKeyframe)")
    if let seq = unit.sequenceHeader {
        print("Profile \(seq.seqProfile), \(seq.maxFrameWidth)x\(seq.maxFrameHeight)")
    }
case .incomplete:
    break  // Waiting for more packets
case .error(let error):
    break  // Auto-recovers
}
```

**Two modules:**
- `AV1RTP` — Foundation only, zero dependencies, theoretically Linux-portable
- `AV1VideoToolbox` — Apple-only bridge for `CMSampleBuffer` creation (stubbed in v0.1.0, implementation coming v0.3.0)

The interesting challenge with AV1 on Apple platforms: Apple provides convenience functions for H.264 and HEVC format descriptions (`CMVideoFormatDescriptionCreateFromH264ParameterSets`, etc.), but nothing for AV1. You have to manually construct the `AV1CodecConfigurationRecord` per the av1-isobmff spec, including a Sequence Header OBU with `obu_has_size_field` flipped from 0 (as received in RTP) to 1 (as VideoToolbox expects). That's the v0.3.0 milestone.

71 tests passing. Includes an `av1dump` CLI tool for inspecting AV1 RTP payloads.

https://github.com/oneshot2001/swift-av1-rtp

Roadmap:
- **v0.2.0** — Fragment reassembly across packets (Z/Y flags)
- **v0.3.0** — VideoToolbox integration (AV1CodecConfigurationRecord → CMFormatDescription → CMSampleBuffer)
- **v1.0.0** — Axis ARTPEC-9 camera test fixtures, example player app, full documentation

If you have access to an AV1-capable device or camera, packet captures are the most valuable contribution. Feedback, issues, and PRs all welcome.

---

# Hacker News Post

**Title:** Show HN: First Swift AV1 RTP depacketizer – 6th implementation worldwide

**URL:** https://github.com/oneshot2001/swift-av1-rtp

**Comment (post immediately after submission):**

Author here. AV1 is the royalty-free next-gen video codec. Only 5 RTP depacketizer implementations exist worldwide: Chromium (C++), GStreamer (Rust), FFmpeg (C, merged Feb 2025), Pion (Go), and MediaMTX (Go). This is the 6th, and the first for Swift / Apple platforms.

**Why it exists:** IP cameras are starting to ship AV1 RTSP streams — Axis Communications has the first SoC (ARTPEC-9). On the Apple side, M3+ and A17 Pro+ have hardware AV1 decode via VideoToolbox. But there's no Swift library connecting the two. You'd have to wrap FFmpeg or write your own depacketizer from the AOMedia spec. So I did the latter.

**What was interesting to build:**

The AV1 RTP spec uses a 1-byte aggregation header with Z/Y/W/N flags that control how OBUs (Open Bitstream Units) are packed into packets. The W field alone has four modes: W=0 means every element has a leb128 size prefix, W=1/2/3 means that many elements where the last one's size is implicit (to end of packet). Then fragments can span packets via Z (continuation from previous) and Y (continues in next).

The hardest part: Apple has convenience functions for creating H.264 and HEVC format descriptions, but nothing for AV1. You have to manually construct the AV1CodecConfigurationRecord by bitstream-parsing the Sequence Header — which isn't byte-aligned. Built a `BitstreamReader` that tracks bit offsets across byte boundaries.

v0.1.0 is the core depacketizer with 71 tests. Fragment reassembly and VideoToolbox integration coming in v0.2-v0.3. Zero dependencies, MIT licensed.

Happy to answer questions about the spec or implementation details.
