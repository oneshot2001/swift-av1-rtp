# Reddit Posts for swift-av1-rtp

## r/swift Post

**Title:** I built the first Swift AV1 RTP depacketizer — the 6th implementation worldwide

**Body:**

Hey r/swift,

I've been working on camera-related Swift libraries and just shipped something I'm pretty excited about: **swift-av1-rtp**, a pure Swift implementation of the AOMedia AV1 RTP Payload Format.

**Why this exists:** AV1 is the next-gen video codec (successor to H.264/HEVC, royalty-free). Cameras are starting to ship AV1 RTSP streams — Axis Communications has the first one (ARTPEC-9 SoC). But there's no Swift library to depacketize AV1 from RTP. Only 5 implementations exist worldwide (Chromium C++, GStreamer Rust, FFmpeg C, Pion Go, MediaMTX Go). This is the 6th, and the first for any Apple platform.

**What it does (v0.1.0):**
- Parses RTP packet headers (12-byte common header with CSRC/extension handling)
- Parses AV1 aggregation headers (Z/Y/W/N fields)
- Extracts OBU elements from packets (W=0 variable-length, W=1/2/3 fixed count with implicit last size)
- Decodes leb128 variable-length integers
- Parses AV1 Sequence Headers via bitstream reader (bit-level, not byte-aligned)
- Assembles complete temporal units (frames) from packet streams
- Detects packet loss, auto-recovers by waiting for next keyframe

**The interesting technical bits:**
- AV1 Sequence Headers are a bitstream — fields aren't byte-aligned. Built a `BitstreamReader` that tracks bit offsets across byte boundaries
- Apple provides `CMVideoFormatDescriptionCreateFromH264ParameterSets` and the HEVC equivalent, but NO AV1 equivalent. You have to manually construct the `AV1CodecConfigurationRecord` and feed it to VideoToolbox. That's coming in v0.3.0.
- OBUs arrive in RTP with `obu_has_size_field = 0`, but VideoToolbox expects them with `obu_has_size_field = 1`. The library handles this conversion.

**Two modules:**
- `AV1RTP` — Foundation only, zero dependencies, theoretically Linux-portable
- `AV1VideoToolbox` — Apple-only bridge for CMSampleBuffer creation (stubbed, v0.3.0)

71 tests passing. MIT licensed.

GitHub: https://github.com/oneshot2001/swift-av1-rtp

If you have access to an AV1-capable camera, anonymized RTP packet captures are the most valuable contribution right now. Issues and PRs welcome.

---

## r/iOSProgramming Post

**Title:** Open-sourced a pure Swift AV1 RTP depacketizer — decode AV1 video streams on iOS/macOS

**Body:**

If you're building an iOS or macOS app that deals with video streaming, AV1 is coming whether you want it or not. It's royalty-free, 30-50% better compression than HEVC, and cameras are starting to ship it.

Problem: there's no Swift library to handle AV1 RTP streams. You'd have to wrap FFmpeg or write your own packet parser. So I did the latter.

**swift-av1-rtp** depacketizes AV1 video from RTP streams per the AOMedia spec:

```swift
import AV1RTP

let depacketizer = AV1Depacketizer()

// Feed packets from your RTSP client or WebRTC stack
let packet = try RTPPacket(data: rawUDPPayload)
let result = depacketizer.process(packet: packet)

switch result {
case .temporalUnit(let unit):
    // Complete frame — unit.obus, unit.timestamp, unit.isKeyframe
    // unit.sequenceHeader has parsed codec config (profile, level, resolution)
    // unit.data has OBUs in Low Overhead Bitstream Format for VideoToolbox
case .incomplete:
    break // Waiting for more packets
case .error(let error):
    break // Auto-recovers, waits for next keyframe
}
```

v0.1.0 handles single-packet temporal units. Fragment reassembly and the VideoToolbox bridge (AV1CodecConfigurationRecord → CMSampleBuffer → hardware decode on M3+) are next.

Zero dependencies. 71 tests. MIT licensed.

GitHub: https://github.com/oneshot2001/swift-av1-rtp

Use cases: RTSP camera viewers, video surveillance apps, WebRTC AV1 decode, any app consuming AV1 streams on Apple platforms.

---

## r/av1 Post

**Title:** New AV1 RTP implementation in Swift — 6th worldwide, first for Apple platforms

**Body:**

Just shipped an open-source AV1 RTP depacketizer written in pure Swift: https://github.com/oneshot2001/swift-av1-rtp

Implements the AOMedia AV1 RTP Payload Format v1.0.0 spec. As far as I can tell, the existing implementations are:

1. libwebrtc (Chromium) — C++
2. GStreamer rsrtp — Rust
3. FFmpeg rtpdec_av1 — C (merged Feb 2025)
4. Pion rtp — Go
5. MediaMTX (uses Pion) — Go

This is #6, and the first for Swift / Apple platforms.

**v0.1.0 covers:**
- Aggregation header parsing (Z/Y/W/N)
- OBU extraction with W=0 (leb128 sizes) and W=1/2/3 (implicit last element)
- Sequence Header bitstream parsing for codec configuration
- Temporal unit assembly via marker bit and timestamp change detection
- Packet loss detection with keyframe-gated recovery

**Coming next:**
- v0.2: Z/Y fragment reassembly across packets
- v0.3: VideoToolbox bridge — constructing `AV1CodecConfigurationRecord` (the av1C box from av1-isobmff) and `CMVideoFormatDescription` for hardware decode on M3+/A17 Pro
- v1.0: Axis ARTPEC-9 test fixtures, example player app

The main motivation is camera-side AV1 streams — Axis ARTPEC-9 is the only camera SoC shipping AV1 RTSP today, but more are coming. If anyone has AV1 RTP packet captures from any source (cameras, WebRTC, test streams), I'd love to add them as test fixtures.

MIT licensed, contributions welcome. Happy to discuss spec edge cases or interop.

---

## r/homeautomation or r/videosurveillance Post (optional, lower priority)

**Title:** Built a Swift library for decoding AV1 video streams from IP cameras on iOS/macOS

**Body:**

AV1 is coming to IP cameras — Axis has the first one shipping (ARTPEC-9). Better compression, royalty-free, same quality at lower bitrates.

If you're building a camera viewer app for iOS or macOS, there was no way to consume AV1 RTSP streams in Swift. So I built a library that handles the RTP depacketization (turning network packets back into video frames).

v0.1.0 is live: https://github.com/oneshot2001/swift-av1-rtp

VideoToolbox hardware decode support coming in v0.3.0 — that's when you'll be able to go from RTP packets → decoded video frames on M3/M4 Macs and A17+ iPhones.

Open source (MIT), happy to answer questions.

---

## Posting Strategy

1. **r/swift** — Post first, this is the primary audience. Tuesday-Thursday 10am-12pm ET.
2. **r/av1** — Post same day or next day. This community is small but deeply engaged on implementation details.
3. **r/iOSProgramming** — Wait 24-48 hours after r/swift. Don't overlap.
4. **r/homeautomation** or **r/videosurveillance** — Optional, only if the first posts get traction. Different angle (practical use case, not technical).

## Engagement Rules
- Respond to every comment in the first 2 hours (algorithm boost)
- Be genuinely helpful — answer technical questions in detail
- Don't be defensive about "why not just use FFmpeg" — acknowledge it's valid, explain the pure Swift advantage (no binary deps, SPM, Sendable, App Store friendly)
- If someone asks about specific cameras, be honest about what's tested vs. theoretical
