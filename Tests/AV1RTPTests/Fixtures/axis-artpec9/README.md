# Axis ARTPEC-9 Test Fixtures

Anonymized RTP payload captures from Axis cameras with AV1 encoding.

## How Captures Are Made

1. Configure camera for AV1 encoding via VAPIX or web UI
2. Start RTSP stream via VLC or FFmpeg
3. Capture RTP packets via Wireshark
4. Export individual payloads as raw binary (strip UDP/IP headers)
5. Anonymize: remove source IP, port, SDP credentials

## Adding Fixtures

When adding new captures:
- Use descriptive filenames: `keyframe-4k.bin`, `interframe-1080p.bin`
- Add a `capture-params.json` with resolution, bitrate, profile settings
- Never include camera credentials or network details
