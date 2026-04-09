# X/Twitter Posts for swift-av1-rtp

## Primary Launch Post (with demo GIF attached)

Just shipped swift-av1-rtp — the first AV1 RTP depacketizer for Swift.

Parses AV1 video from RTP streams per the AOMedia spec. Sequence Header parsing, OBU reassembly, VideoToolbox bridge coming next.

6th implementation worldwide. First on any Apple platform.

github.com/oneshot2001/swift-av1-rtp

#SwiftLang #iOSDev #OpenSource #AV1

---

## Thread Version (Post 1 of 4)

**Post 1:**
There are AV1 RTP depacketizers for C++ (Chromium), Rust (GStreamer), C (FFmpeg), and Go (Pion).

There were zero for Swift.

So I built one from the AOMedia spec. The 6th implementation worldwide. First for Apple platforms.

github.com/oneshot2001/swift-av1-rtp

#SwiftLang #AV1

**Post 2 (reply):**
What you get in v0.1.0:

- RTP header parsing
- AV1 aggregation header (Z/Y/W/N)
- OBU extraction and type identification
- leb128 variable-length decode
- Sequence Header bitstream parsing
- Temporal unit assembly
- 71 tests, zero dependencies

**Post 3 (reply):**
Why does this matter?

AV1 is the future of video compression. Axis just shipped the first AV1 RTSP cameras (ARTPEC-9). More manufacturers are coming.

If you're building a camera app on iOS/macOS and want AV1 streaming — this is the missing piece between your RTSP client and VideoToolbox.

**Post 4 (reply):**
Coming next:

- v0.2: Fragment reassembly across packets (Z/Y flags)
- v0.3: VideoToolbox bridge — AV1CodecConfigurationRecord → CMSampleBuffer
- v1.0: Hardware decode on M3+/A17 Pro, Axis camera test fixtures

MIT licensed. PRs and AV1 camera captures welcome.

---

## Shorter Variation (punchy)

5 lines of Swift to depacketize AV1 from an RTP stream:

let depacketizer = AV1Depacketizer()
let packet = try RTPPacket(data: udpPayload)
let result = depacketizer.process(packet: packet)
// → .temporalUnit(unit) when frame is ready

Zero dependencies. Built from the AOMedia spec.

github.com/oneshot2001/swift-av1-rtp

#SwiftLang #AV1 #OpenSource

---

## Technical Angle (for reaching protocol/codec people)

Fun project: I wrote a complete AV1 RTP depacketizer in pure Swift.

Had to build a bitstream reader for Sequence Header parsing — AV1 fields aren't byte-aligned, so you're reading 3 bits here, 5 bits there, across byte boundaries.

The hardest part: Apple has no CMVideoFormatDescriptionCreateFromAV1... function (unlike H.264/HEVC). You have to manually construct the AV1CodecConfigurationRecord. Coming in v0.3.

github.com/oneshot2001/swift-av1-rtp

---

## Hashtags to Use

Primary: #SwiftLang #iOSDev #OpenSource #AV1
Secondary (pick 1-2): #macOSDev #VideoToolbox #RTSP #Streaming #VideoCodec #AppleSilicon

## Best Times to Post (US tech audience)
- Tuesday-Thursday, 9-11am ET
- Avoid weekends and Mondays

## Who to Tag/Mention (optional, only if you've interacted with them before)
- @SwiftLang (official Swift account)
- @daveverwer (iOS Dev Weekly curator)
- @AOMAlliance (Alliance for Open Media)
- @AV1 community accounts
