# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-09

### Added

- `RTPPacket` — minimal 12-byte RTP common header parser
- `AggregationHeader` — AV1 aggregation header (Z/Y/W/N) parsing
- `LEB128` — variable-length unsigned integer encode/decode
- `OBU` — Open Bitstream Unit header parsing and type identification
- `BitstreamReader` — bit-level reader for AV1 bitstream fields
- `TemporalUnit` — complete temporal unit container
- `AV1Depacketizer` — stateful packet processor for single-packet temporal units (W=1/2/3)
- `AV1VideoToolbox` module stubs for future VideoToolbox integration
- `av1dump` example CLI tool
- 20+ unit tests with hand-crafted binary fixtures
