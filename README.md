# RecordMe

RecordMe is a lightweight native macOS screen recorder built with SwiftUI, ScreenCaptureKit, AVFoundation, and CoreImage.

It records locally, keeps the app dependency-light, and focuses on the core workflows needed to capture a display or window with optional audio and camera overlay.

## Features

- Display and window recording with ScreenCaptureKit
- Live preview before recording
- System audio and microphone capture options
- Camera overlay composited with CoreImage
- Saved MP4 output using AVFoundation
- Native SwiftUI interface
- Local-first operation with no account requirement
- Small release footprint with no third-party runtime dependencies

## Requirements

- macOS 15.1 or later
- Xcode 16.1 or later for source builds

## Install

Download the latest `RecordMe.dmg` from the [latest release](https://github.com/abbeazale/recordme/releases/latest), open it, and drag RecordMe to Applications.

Current community builds may be unsigned. If macOS blocks the first launch, right-click RecordMe in Applications, choose Open, and confirm that you want to open it. You will also need to grant the requested macOS recording permissions.

## Build From Source

```bash
git clone https://github.com/abbeazale/recordme.git
cd recordme
open recordme.xcodeproj
```

Build and run from Xcode, or use `xcodebuild`:

```bash
xcodebuild -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' build
```

Run tests:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS'
```

Measure the release size:

```bash
./scripts/measure-release-size.sh
```

## Privacy

Recording stays local to your Mac. RecordMe does not include analytics, telemetry, account signup, or network upload code.

The app requests macOS permissions required for recording features, such as screen recording, microphone access, and camera access when those options are used.

## Distribution

Release builds should be signed and notarized before broad distribution. Unsigned builds are useful for local development and community testing, but users should expect macOS Gatekeeper warnings.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, coding expectations, and verification guidance.

## License

RecordMe is available under the [MIT License](LICENSE).
