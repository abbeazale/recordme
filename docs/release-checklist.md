# Release Checklist

Use this checklist before publishing a RecordMe release.

## Automated Checks

Build:

```bash
xcodebuild -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Test:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Measure release size:

```bash
./scripts/measure-release-size.sh
```

Create a release build:

```bash
./scripts/build-release.sh
```

## Manual Checks

- Display recording starts, stops, and saves successfully.
- Window recording starts, stops, and saves successfully.
- Live preview renders the selected source before recording.
- System audio is captured when enabled.
- Microphone audio is captured when enabled.
- Camera overlay appears in the expected position while enabled.
- Saved MP4 opens and plays with expected video and audio.
- Camera capture stops after recording stops or the overlay is disabled.
- Permission recovery works after screen recording, microphone, or camera permissions are denied and later granted.

## Release Notes

Include:

- New features and user-visible improvements
- Bug fixes
- Known issues or permission caveats
- macOS and Xcode requirements
- Signing and notarization status
- Release size summary from `./scripts/measure-release-size.sh`
