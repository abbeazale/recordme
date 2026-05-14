# Contributing

Thanks for helping improve RecordMe. Keep changes focused on the native macOS recording experience and avoid adding weight unless it clearly supports the core product.

## Local Setup

Requirements:

- macOS 15.1 or later
- Xcode 16.1 or later

Clone and open the project:

```bash
git clone https://github.com/abbeazale/recordme.git
cd recordme
open recordme.xcodeproj
```

Build from the command line:

```bash
xcodebuild -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Run tests:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Check release size:

```bash
./scripts/measure-release-size.sh
```

## Coding Expectations

- Keep RecordMe native and dependency-light.
- Prefer SwiftUI, ScreenCaptureKit, AVFoundation, CoreImage, and Apple platform APIs already used by the app.
- Preserve existing recording features unless the change intentionally and explicitly modifies them.
- Keep display recording, window recording, live preview, system audio, microphone capture, camera overlay, and saved MP4 output working.
- Add Swift Testing coverage for pure logic where behavior can be tested without macOS permission prompts or capture hardware.
- Keep permission-sensitive behavior manually verifiable and document what was checked in the pull request.

## Manual Verification

Some macOS capture behavior depends on system permissions, hardware, and privacy prompts. For changes in those areas, document manual checks for:

- Screen recording permission request and recovery
- Microphone permission request and recovery
- Camera permission request and recovery
- Display and window source selection
- Live preview behavior
- System audio, microphone, and camera overlay combinations
- Saved MP4 playback
- Camera shutdown after recording stops

## Pull Requests

Include a concise summary, the commands you ran, and any manual verification notes. Mention any release size change if `./scripts/measure-release-size.sh` reports a meaningful difference.
