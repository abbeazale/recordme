# RecordMe

RecordMe is a lightweight native macOS screen recorder built with SwiftUI, ScreenCaptureKit, AVFoundation, and CoreImage.

It records locally, keeps the app dependency-light, and focuses on the core workflows needed to capture a display or window with optional audio and camera overlay.

## Features

- Display and window recording with ScreenCaptureKit
- Live preview before recording
- System audio and microphone capture options
- Camera overlay with corner placement, adjustable size, and rounded, circular, or rectangular shapes
- Camera layout is selected before recording and matches the saved video
- Saved MP4 output using AVFoundation
- Open existing videos, trim them, and save a separate edited copy
- Save and reopen portable `.recordme` projects with source video, click data, and edit settings
- Styled exports with gradient backgrounds, padding, rounded corners, shadows, and aspect ratio presets
- Optional Capture Clicks records local click data beside the video for editor-controlled click highlights and automatic zooms
- H.264 export settings for source/1080p/720p size, 24/30/60 fps, and compact/balanced/high quality
- Native SwiftUI interface
- Local-first operation with no account requirement
- Small release footprint with no third-party runtime dependencies

## Editing and projects

Open a video from the capture screen or permission screen, or stop a recording to enter the editor. Use Canvas to style the video, Cursor Effects to highlight recorded clicks or add automatic zoom, and Export Settings to choose output size, frame rate, and quality. Save Edited Copy writes a new MP4 and keeps the editor open.

Save Project, also available with Command-S, creates a `.recordme` package containing a copy of the original video, click data, trim range, and editor settings. Open it from RecordMe or Finder to continue editing. Project saves are explicit; save before closing the app. Keeping a copy of the source makes the project portable and uses additional disk space.

Camera layout is selected before capture and becomes part of the recording. Click effects require Capture Clicks to have been enabled while recording; imported videos without click data can still be trimmed and styled.

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
xcodebuild -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Run tests:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
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
