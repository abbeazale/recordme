# RecordMe Lightweight Open Source Design

Date: 2026-05-08

## Goal

Make RecordMe lightweight in three ways without removing features:

- Small download and installed app size.
- Low CPU, memory, and energy impact while previewing and recording.
- Clean, approachable source code and project structure for open source contributors.

All existing product features stay in scope:

- Display recording.
- Window recording.
- Live screen preview.
- Camera overlay.
- Microphone audio.
- System audio.
- MP4 output.
- Source selection.
- Screen recording, camera, microphone, and Downloads permission handling.
- Basic recorded video review and trim UI.

## Current Baseline

Measured on 2026-05-08 from the local repository:

- Release `.app`: about 2.8 MB.
- Compressed DMG: about 1.9 MB.
- App source and assets: about 3.3 MB.
- Full working tree: about 193 MB.
- `.git` directory: about 186 MB.
- Swift source: about 2,400 lines.
- No third-party packages or vendored dependencies were found.

The app is already lightweight as a shipped macOS binary. The main problems are release hygiene, runtime efficiency, repository size/history, and maintainability.

## Non-Goals

- Do not replace the native SwiftUI, ScreenCaptureKit, AVFoundation, and CoreImage stack.
- Do not introduce Electron, web wrappers, or third-party UI frameworks.
- Do not remove camera overlay, audio capture, source picking, live preview, or video review features.
- Do not rewrite the app from scratch.
- Do not rewrite Git history automatically as part of normal implementation. History cleanup needs a separate explicit decision because it affects collaborators and existing clones.

## Approach

Use a product-quality lightweight pass across packaging, runtime, and source organization.

Packaging-only work would improve release size and presentation but would not improve CPU or memory usage. Runtime-only work would help recording performance but would not make the project easier to open source. A combined pass gives the best outcome because RecordMe's binary is already small, while the user-visible product quality depends on performance and contributor trust.

## Packaging And Repository Hygiene

Release builds should be reproducible and measured.

Add a script or release step that reports:

- Built `.app` size.
- Compressed DMG size.
- Main executable size.
- Asset catalog size.
- Optional debug symbol size outside the app bundle.

Release configuration should avoid test and profiling instrumentation unless intentionally enabled for diagnostic builds. Debug symbols may still be produced, but they should not inflate the distributed app.

The repository should ignore local and generated files:

- Xcode derived data and build folders.
- `.DS_Store`.
- Local assistant/worktree folders such as `.claude/` unless intentionally documented.
- Generated DMGs and temporary release folders.

Committed assets should be audited. The current icon assets appear duplicated between `AppIcon.appiconset` and standalone icon image sets. If the standalone icon sets are not referenced by code or project settings, remove them from the source tree and keep the canonical app icon only.

Git history is the primary reason the local repository is large. If clone size matters before open sourcing, handle history cleanup as a separate task with an explicit plan, backup branch, and force-push/repository migration instructions.

## Runtime Performance

Preview and recording should have separate performance goals.

Recording must preserve output quality and frame continuity. Preview only needs to feel responsive. The app should avoid doing preview image work at full recording frame rate when the preview does not need it.

Target behavior:

- Do not create preview images when preview is inactive.
- Throttle UI preview updates independently from recording frame processing.
- Keep camera capture stopped unless camera overlay is enabled or visible.
- Release `SCStream`, `AVCaptureSession`, `AVAssetWriter`, and related buffers promptly on stop, errors, and view teardown.
- Prefer direct pixel-buffer composition paths over repeated `CGImage` conversions where practical.
- Keep source thumbnails cached only for the current source picker session and discard them when no longer needed.

The initial implementation should preserve behavior first, then optimize the hottest paths with measurement. The likely hot paths are live preview generation, camera overlay compositing, and source thumbnail capture.

## Source Structure

Keep the app small, but split files where current files carry multiple responsibilities.

`ContentView.swift` should become a thin composition root that owns high-level state and wires together focused views. Candidate extracted units:

- `PermissionView`
- `SourcePickerView`
- `DisplayPickerView`
- `WindowPickerView`
- `PreviewPane`
- `RecordingControlsView`
- `AudioControlsView`
- `CameraControlsView`

`RecordingManager.swift` should keep the public recording lifecycle API, while lower-level processing can move into focused types only where it clarifies behavior:

- Stream setup and lifecycle.
- Writer setup and finishing.
- Frame processing.
- Camera overlay compositing.
- Preview image generation.

The goal is not to create many tiny files. The goal is for each file to have one clear reason to change.

## User Experience

The app should remain simple and native.

Default settings should favor low overhead while still producing useful recordings:

- Display recording selected by default when available.
- System audio enabled by default only if currently supported and stable.
- Microphone and camera off by default.
- Preview visible and responsive, but internally throttled.
- Clear error messages for permissions and recording failures.

Any new measurement or diagnostics should stay out of the main user flow unless explicitly opened by a developer or maintainer.

## Testing And Verification

Add lightweight verification that protects the no-feature-cut requirement:

- Unit tests for filename generation.
- Unit tests for source filtering.
- Tests for small state-transition helpers if they are extracted from UI code.
- A release-size script that can run locally and in CI.
- Manual verification checklist for screen recording, window recording, camera overlay, mic audio, system audio, and saved MP4 playback.

Full automated UI recording tests may not be practical because macOS screen recording permissions are environment-sensitive. The project should document which tests are automated and which checks are manual before release.

## Open Source Readiness

Before publishing broadly, the repository should include:

- Updated README with clear feature list, requirements, screenshots or GIFs, install instructions, and build instructions.
- License file.
- Contributing guide with local setup, testing, release-size check, and coding expectations.
- Issue templates for bugs and feature requests.
- Security/privacy note explaining that recording is local and which macOS permissions are requested.
- Release documentation that distinguishes unsigned community builds from signed/notarized builds.

## Risks

Performance optimization can accidentally change recording output. Mitigate this by keeping recording frame processing separate from preview throttling and by testing output files after each change.

Splitting large SwiftUI files can create churn without improving maintainability. Mitigate this by extracting stable UI regions first and avoiding abstraction around one-off layout code.

Git history cleanup can disrupt existing clones and open pull requests. Treat it as a separate operation with user approval.

## Acceptance Criteria

- Release build still succeeds.
- Distributed app and DMG sizes are measured and documented.
- Release build no longer includes unnecessary test/profiling instrumentation.
- No existing features are removed.
- Preview and camera work are avoided when not needed.
- `ContentView.swift` and `RecordingManager.swift` are smaller or clearer through focused extraction.
- Repo ignores common local/generated files.
- Open source documentation covers install, build, contribution, privacy, and release basics.
- Manual verification confirms display recording, window recording, camera overlay, microphone audio, system audio, MP4 saving, and playback review.

## Implementation Sequence

1. Add measurement and release-size reporting.
2. Clean ignore rules and generated/local files from the public surface.
3. Fix Release configuration hygiene.
4. Audit and remove unused duplicate assets.
5. Refactor UI into focused views while preserving behavior.
6. Refactor recording internals only where it directly improves performance or clarity.
7. Add focused tests and manual release checklist.
8. Update open source documentation.
9. Decide separately whether to rewrite or migrate Git history before public launch.
