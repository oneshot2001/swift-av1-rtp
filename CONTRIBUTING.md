# Contributing to swift-av1-rtp

Thanks for your interest in contributing! swift-av1-rtp aims to be the definitive AV1 RTP depacketizer for the Swift ecosystem, and contributions are welcome.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/swift-av1-rtp.git`
3. Create a branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Run tests: `swift test`
6. Push and open a Pull Request

## Development Setup

swift-av1-rtp is a standard Swift Package Manager project:

```bash
# Build
swift build

# Run tests
swift test

# Run the example CLI
swift run av1dump
```

**Requirements:** Swift 5.9+, macOS 13+ (for development)

## Code Style

- Use Swift's standard naming conventions
- All public APIs need documentation comments
- New types and operations need corresponding tests
- Models should be `Sendable` and use value types where possible
- Keep the core `AV1RTP` module free of Apple-specific frameworks (Foundation only)

## Testing

- All tests use binary fixtures in `Tests/AV1RTPTests/Fixtures/`
- When adding new packet handling, add corresponding binary fixture files
- Test both success cases and error handling
- If you have access to an AV1-capable camera (e.g., Axis ARTPEC-9), captured packet fixtures are extremely valuable

### Creating Test Fixtures

Fixtures are raw binary files representing RTP payloads (without the UDP/IP headers). To capture from a real camera:

1. Use Wireshark to capture RTP packets from an AV1 RTSP stream
2. Export individual RTP payloads as raw binary
3. Strip source IP, port, and any SDP credentials
4. Save as `.bin` files with descriptive names

## Adding New Features

1. Implement in the appropriate source file under `Sources/AV1RTP/` or `Sources/AV1VideoToolbox/`
2. Add test coverage with fixtures
3. Update the README if the public API changes
4. Update CHANGELOG.md

## Reporting Issues

- **Bugs:** Include the camera manufacturer/model if applicable, and a hex dump of the failing RTP payload
- **Feature requests:** Reference the relevant section of the [AOMedia AV1 RTP spec](https://aomediacodec.github.io/av1-rtp-spec/)
- **Security issues:** Email directly rather than opening a public issue

## Pull Request Guidelines

- Keep PRs focused on a single change
- Include tests for new functionality
- Update documentation if the public API changes
- Reference any related issues in the PR description

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
