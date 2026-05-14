# Release Size Baseline

Measured with `./scripts/measure-release-size.sh`.

| Metric | Baseline |
| --- | ---: |
| App bundle | 1.2 MB |
| Executable | 340 KB |
| Assets.car | 820 KB |
| AppIcon.icns | 44 KB |
| Compressed DMG | 1.3 MB |

## Notes

The distributed app is already small. Future changes should preserve the native SwiftUI/ScreenCaptureKit/AVFoundation stack and should not add third-party runtime dependencies without a concrete size and maintenance reason.

The local repository can be much larger than the app because Git history stores old binary assets. Treat Git history cleanup as a separate release-management decision.

## How To Measure

```bash
./scripts/measure-release-size.sh
```

Commit size changes only when the feature or cleanup explains the difference.
