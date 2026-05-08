# Lightweight Open Source Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make RecordMe lighter to download, lighter to run, and easier to open source without cutting any current recording features.

**Architecture:** Start with repeatable measurement and release hygiene, then reduce repository/assets weight, then make targeted UI and recording-pipeline extractions. Runtime changes separate preview work from recording work so output quality stays stable while UI preview cost drops.

**Tech Stack:** Swift 5, SwiftUI, ScreenCaptureKit, AVFoundation, CoreImage, Swift Testing, Xcode project file-system-synchronized groups, shell scripts.

---

## File Structure

- Create `scripts/measure-release-size.sh`: reproducible local release-size report for `.app`, executable, assets, dSYM, and DMG.
- Create `docs/release-size-baseline.md`: committed baseline and instructions for maintainers.
- Modify `.gitignore`: ignore local, generated, assistant, and release artifacts.
- Delete `recordme/Assets.xcassets/icon_16x16.imageset`, `icon_32x32.imageset`, `icon_128x128.imageset`, `icon_256x256.imageset`, and `icon_512x512.imageset` after verifying code does not reference them.
- Create `recordme.xcodeproj/xcshareddata/xcschemes/recordme.xcscheme`: shared Release/Test scheme with code coverage disabled by default.
- Modify `recordme.xcodeproj/project.pbxproj`: make Release favor small artifacts and remove development assets from Release.
- Create `recordme/RecordingControlState.swift`: testable button-label/icon/help-text state.
- Create `recordmeTests/RecordingControlStateTests.swift`: tests for microphone, system audio, camera, and record button state.
- Create `recordme/PermissionView.swift`: screen recording permission UI.
- Create `recordme/PreviewPane.swift`: preview display and camera overlay UI.
- Create `recordme/RecordingControlsView.swift`: source, audio, camera, and record controls.
- Modify `recordme/ContentView.swift`: keep high-level state/lifecycle, source picker, loading, and recording actions; delegate extracted UI.
- Create `recordme/PreviewFrameThrottler.swift`: deterministic preview frame throttling.
- Create `recordmeTests/PreviewFrameThrottlerTests.swift`: tests for preview throttle behavior.
- Modify `recordme/RecordingManager.swift`: pass preview intent into the pipeline, avoid camera image lookup unless needed, and use the throttler.
- Create `recordme/RecordingStreamConfiguration.swift`: shared preview/recording stream configuration factory.
- Create `recordmeTests/RecordingStreamConfigurationTests.swift`: tests for frame interval, dimensions, and audio flags.
- Modify `README.md`: update public-facing feature, requirement, build, privacy, and release information.
- Create `CONTRIBUTING.md`: local setup, test commands, release-size measurement, and contribution expectations.
- Create `SECURITY.md`: privacy and vulnerability reporting notes.
- Create `.github/ISSUE_TEMPLATE/bug_report.md` and `.github/ISSUE_TEMPLATE/feature_request.md`.
- Create `LICENSE`: MIT license, using the repository owner's existing public identity as copyright holder.
- Create `docs/release-checklist.md`: manual verification checklist for all no-feature-cut behaviors.

## Task 1: Add Release Size Measurement

**Files:**
- Create: `scripts/measure-release-size.sh`
- Create: `docs/release-size-baseline.md`

- [ ] **Step 1: Create the measurement script**

Create `scripts/measure-release-size.sh` with this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${ROOT_DIR}/build/MeasureRelease"
PRODUCTS_DIR="${DERIVED_DATA}/Build/Products/Release"
APP_PATH="${PRODUCTS_DIR}/recordme.app"
DSYM_PATH="${PRODUCTS_DIR}/recordme.app.dSYM"
DMG_PATH="${ROOT_DIR}/build/RecordMe-measure.dmg"

cd "$ROOT_DIR"

rm -rf "$DERIVED_DATA" "$DMG_PATH"
mkdir -p "$ROOT_DIR/build"

xcodebuild \
  -project recordme.xcodeproj \
  -scheme recordme \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=- \
  build >/tmp/recordme-measure-build.log

if [[ ! -d "$APP_PATH" ]]; then
  echo "Release app was not created at $APP_PATH" >&2
  exit 1
fi

hdiutil create \
  -volname "RecordMe" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/tmp/recordme-measure-dmg.log

echo "RecordMe release size report"
echo "============================"
printf "App bundle:       %s\n" "$(du -sh "$APP_PATH" | awk '{print $1}')"
printf "Executable:       %s\n" "$(du -sh "$APP_PATH/Contents/MacOS/recordme" | awk '{print $1}')"
if [[ -f "$APP_PATH/Contents/Resources/Assets.car" ]]; then
  printf "Assets.car:        %s\n" "$(du -sh "$APP_PATH/Contents/Resources/Assets.car" | awk '{print $1}')"
fi
if [[ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]]; then
  printf "AppIcon.icns:      %s\n" "$(du -sh "$APP_PATH/Contents/Resources/AppIcon.icns" | awk '{print $1}')"
fi
if [[ -d "$DSYM_PATH" ]]; then
  printf "dSYM:             %s\n" "$(du -sh "$DSYM_PATH" | awk '{print $1}')"
fi
printf "Compressed DMG:   %s\n" "$(du -sh "$DMG_PATH" | awk '{print $1}')"
echo
echo "Artifacts:"
echo "$APP_PATH"
echo "$DMG_PATH"
```

- [ ] **Step 2: Make the script executable**

Run:

```bash
chmod +x scripts/measure-release-size.sh
```

Expected: command exits with status `0`.

- [ ] **Step 3: Run the measurement script**

Run:

```bash
./scripts/measure-release-size.sh
```

Expected: output contains these labels:

```text
RecordMe release size report
App bundle:
Executable:
Assets.car:
AppIcon.icns:
Compressed DMG:
```

- [ ] **Step 4: Document the current baseline**

Create `docs/release-size-baseline.md` with this content, replacing only the measured values if the script reports different numbers on the implementation machine:

```markdown
# Release Size Baseline

Measured with `./scripts/measure-release-size.sh`.

| Metric | Baseline |
| --- | ---: |
| App bundle | 2.8 MB |
| Executable | 1.4 MB |
| Assets.car | 1.4 MB |
| AppIcon.icns | 44 KB |
| Compressed DMG | 1.9 MB |

## Notes

The distributed app is already small. Future changes should preserve the native SwiftUI/ScreenCaptureKit/AVFoundation stack and should not add third-party runtime dependencies without a concrete size and maintenance reason.

The local repository can be much larger than the app because Git history stores old binary assets. Treat Git history cleanup as a separate release-management decision.

## How To Measure

```bash
./scripts/measure-release-size.sh
```

Commit size changes only when the feature or cleanup explains the difference.
```

- [ ] **Step 5: Verify Task 1**

Run:

```bash
git diff --check -- scripts/measure-release-size.sh docs/release-size-baseline.md
./scripts/measure-release-size.sh
```

Expected: `git diff --check` prints nothing and the measurement script prints a complete size report.

- [ ] **Step 6: Commit Task 1**

```bash
git add scripts/measure-release-size.sh docs/release-size-baseline.md
git commit -m "Add release size measurement"
```

## Task 2: Clean Ignore Rules And Unused Icon Assets

**Files:**
- Modify: `.gitignore`
- Delete: `recordme/Assets.xcassets/icon_16x16.imageset`
- Delete: `recordme/Assets.xcassets/icon_32x32.imageset`
- Delete: `recordme/Assets.xcassets/icon_128x128.imageset`
- Delete: `recordme/Assets.xcassets/icon_256x256.imageset`
- Delete: `recordme/Assets.xcassets/icon_512x512.imageset`

- [ ] **Step 1: Verify standalone icon sets are unreferenced**

Run:

```bash
rg -n 'icon_16x16|icon_32x32|icon_128x128|icon_256x256|icon_512x512' recordme recordme.xcodeproj Config
```

Expected: matches only appear inside `recordme/Assets.xcassets/icon_*.imageset` directories and `recordme/Assets.xcassets/AppIcon.appiconset/Contents.json`. If code or project settings reference a standalone `icon_*.imageset`, stop this task and remove only the unreferenced icon sets.

- [ ] **Step 2: Replace `.gitignore`**

Replace `.gitignore` with:

```gitignore
.DS_Store

# Xcode
DerivedData/
*.xcuserstate
*.xccheckout
*.moved-aside
*.xcscmblueprint
*.hmap
*.ipa
*.dSYM.zip
*.dSYM

# Local build and release artifacts
/build/
/build-sandbox/
/output/
/dmg-temp/
/RecordMe*.dmg
/recordme-*.dmg

# Local agent/editor state
/.claude/
/.vscode/
```

- [ ] **Step 3: Delete local `.DS_Store` files**

Run:

```bash
find . -name .DS_Store -print -delete
```

Expected: command may print deleted `.DS_Store` paths and exits with status `0`.

- [ ] **Step 4: Delete unreferenced standalone icon image sets**

Run:

```bash
rm -rf \
  recordme/Assets.xcassets/icon_16x16.imageset \
  recordme/Assets.xcassets/icon_32x32.imageset \
  recordme/Assets.xcassets/icon_128x128.imageset \
  recordme/Assets.xcassets/icon_256x256.imageset \
  recordme/Assets.xcassets/icon_512x512.imageset
```

Expected: command exits with status `0`. `recordme/Assets.xcassets/AppIcon.appiconset` remains intact.

- [ ] **Step 5: Build after asset cleanup**

Run:

```bash
xcodebuild -project recordme.xcodeproj -scheme recordme -configuration Release -derivedDataPath /tmp/recordme-task2 CODE_SIGNING_ALLOWED=NO build
```

Expected: output ends with `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Measure size after cleanup**

Run:

```bash
./scripts/measure-release-size.sh
```

Expected: size report prints successfully. `Assets.car` should be smaller than or equal to the Task 1 baseline.

- [ ] **Step 7: Commit Task 2**

```bash
git add .gitignore recordme/Assets.xcassets
git commit -m "Clean generated files and unused icon assets"
```

## Task 3: Fix Release Build Hygiene

**Files:**
- Create: `recordme.xcodeproj/xcshareddata/xcschemes/recordme.xcscheme`
- Modify: `recordme.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create the shared Xcode scheme**

Create directory:

```bash
mkdir -p recordme.xcodeproj/xcshareddata/xcschemes
```

Create `recordme.xcodeproj/xcshareddata/xcschemes/recordme.xcscheme` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1610"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES"
      buildArchitectures = "Automatic">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "26DE6A0E2DA7D0290081EED7"
               BuildableName = "recordme.app"
               BlueprintName = "recordme"
               ReferencedContainer = "container:recordme.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      codeCoverageEnabled = "NO">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "26DE6A1F2DA7D02A0081EED7"
               BuildableName = "recordmeTests.xctest"
               BlueprintName = "recordmeTests"
               ReferencedContainer = "container:recordme.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "26DE6A0E2DA7D0290081EED7"
            BuildableName = "recordme.app"
            BlueprintName = "recordme"
            ReferencedContainer = "container:recordme.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "26DE6A0E2DA7D0290081EED7"
            BuildableName = "recordme.app"
            BlueprintName = "recordme"
            ReferencedContainer = "container:recordme.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
```

- [ ] **Step 2: Update Release project-level build settings**

In `recordme.xcodeproj/project.pbxproj`, inside `26DE6A332DA7D02A0081EED7 /* Release */`, set or add these build settings:

```text
COPY_PHASE_STRIP = YES;
DEAD_CODE_STRIPPING = YES;
DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
DEPLOYMENT_POSTPROCESSING = YES;
SWIFT_COMPILATION_MODE = wholemodule;
SWIFT_OPTIMIZATION_LEVEL = "-Osize";
```

Keep `ENABLE_NS_ASSERTIONS = NO;` and `MTL_ENABLE_DEBUG_INFO = NO;`.

- [ ] **Step 3: Update Release target build settings**

In `recordme.xcodeproj/project.pbxproj`, inside `26DE6A362DA7D02A0081EED7 /* Release */`, set:

```text
DEVELOPMENT_ASSET_PATHS = "";
ENABLE_PREVIEWS = NO;
```

Do not change the Debug target settings.

- [ ] **Step 4: Verify Release compile command no longer contains coverage instrumentation**

Run:

```bash
xcodebuild -project recordme.xcodeproj -scheme recordme -configuration Release -derivedDataPath /tmp/recordme-task3 CODE_SIGNING_ALLOWED=NO build | tee /tmp/recordme-task3-build.log
```

Expected: output ends with `** BUILD SUCCEEDED **`.

Run:

```bash
rg -- '-profile-generate|-profile-coverage-mapping' /tmp/recordme-task3-build.log
```

Expected: no matches. If this command exits with status `1`, that is the expected no-match result.

- [ ] **Step 5: Run tests**

Run:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: output ends with `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit Task 3**

```bash
git add recordme.xcodeproj
git commit -m "Tighten release build settings"
```

## Task 4: Add Testable Recording Control State

**Files:**
- Create: `recordme/RecordingControlState.swift`
- Create: `recordmeTests/RecordingControlStateTests.swift`
- Modify: `recordme/ContentView.swift`

- [ ] **Step 1: Write failing tests for button state**

Create `recordmeTests/RecordingControlStateTests.swift`:

```swift
import Testing
@testable import recordme

struct RecordingControlStateTests {
    @Test func cameraStateWhenNoCameraExists() {
        let state = CameraControlState.make(hasCamera: false, isAuthorized: false, showCamera: false, isCapturing: false)

        #expect(state.icon == "video.slash")
        #expect(state.title == "No camera")
        #expect(state.help == "No camera available")
        #expect(state.isActive == false)
        #expect(state.isEnabled == false)
    }

    @Test func cameraStateWhenCameraIsCapturing() {
        let state = CameraControlState.make(hasCamera: true, isAuthorized: true, showCamera: true, isCapturing: true)

        #expect(state.icon == "video.fill")
        #expect(state.title == "Camera")
        #expect(state.help == "Hide camera overlay")
        #expect(state.isActive == true)
        #expect(state.isEnabled == true)
    }

    @Test func cameraStateWhenAuthorizationIsNeeded() {
        let state = CameraControlState.make(hasCamera: true, isAuthorized: false, showCamera: true, isCapturing: false)

        #expect(state.icon == "video.badge.exclamationmark")
        #expect(state.title == "Camera access")
        #expect(state.help == "Camera access required")
        #expect(state.isActive == false)
        #expect(state.isEnabled == true)
    }

    @Test func audioStateUsesProminentSystemAudioColor() {
        let state = AudioControlState.make(isActive: true, isProminent: true)

        #expect(state.usesWhiteForeground)
        #expect(state.usesProminentBackground)
    }

    @Test func recordingButtonStateRequiresSourceWhenIdle() {
        let idleWithoutSource = RecordingButtonState.make(isRecording: false, hasSelectedSource: false)
        let idleWithSource = RecordingButtonState.make(isRecording: false, hasSelectedSource: true)
        let recordingWithoutSource = RecordingButtonState.make(isRecording: true, hasSelectedSource: false)

        #expect(idleWithoutSource.isEnabled == false)
        #expect(idleWithoutSource.title == "Start Recording")
        #expect(idleWithSource.isEnabled == true)
        #expect(recordingWithoutSource.isEnabled == true)
        #expect(recordingWithoutSource.title == "Stop Recording")
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: build fails because `CameraControlState`, `AudioControlState`, and `RecordingButtonState` are not defined.

- [ ] **Step 3: Add control state types**

Create `recordme/RecordingControlState.swift`:

```swift
import Foundation

struct CameraControlState: Equatable {
    let icon: String
    let title: String
    let help: String
    let isActive: Bool
    let isEnabled: Bool

    static func make(hasCamera: Bool, isAuthorized: Bool, showCamera: Bool, isCapturing: Bool) -> CameraControlState {
        guard hasCamera else {
            return CameraControlState(
                icon: "video.slash",
                title: "No camera",
                help: "No camera available",
                isActive: false,
                isEnabled: false
            )
        }

        if showCamera && isCapturing {
            return CameraControlState(
                icon: "video.fill",
                title: "Camera",
                help: "Hide camera overlay",
                isActive: true,
                isEnabled: true
            )
        }

        if showCamera && !isAuthorized {
            return CameraControlState(
                icon: "video.badge.exclamationmark",
                title: "Camera access",
                help: "Camera access required",
                isActive: false,
                isEnabled: true
            )
        }

        return CameraControlState(
            icon: "video.slash",
            title: "No camera",
            help: showCamera ? "Hide camera overlay" : "Show camera overlay",
            isActive: false,
            isEnabled: true
        )
    }
}

struct AudioControlState: Equatable {
    let usesWhiteForeground: Bool
    let usesProminentBackground: Bool

    static func make(isActive: Bool, isProminent: Bool) -> AudioControlState {
        AudioControlState(
            usesWhiteForeground: isProminent && isActive,
            usesProminentBackground: isProminent && isActive
        )
    }
}

struct RecordingButtonState: Equatable {
    let title: String
    let icon: String?
    let isEnabled: Bool
    let isRecording: Bool

    static func make(isRecording: Bool, hasSelectedSource: Bool) -> RecordingButtonState {
        RecordingButtonState(
            title: isRecording ? "Stop Recording" : "Start Recording",
            icon: isRecording ? nil : "record.circle",
            isEnabled: isRecording || hasSelectedSource,
            isRecording: isRecording
        )
    }
}
```

- [ ] **Step 4: Use control state in `ContentView.swift`**

Replace `getAudioButtonColor`, `getAudioButtonBackground`, `getCameraIcon`, `getCameraText`, and `getCameraHelpText` usage with local state values.

Inside `audioToggleButton`, before `Button(action: action)`, add:

```swift
let state = AudioControlState.make(isActive: isActive, isProminent: isProminent)
```

Use:

```swift
.foregroundColor(state.usesWhiteForeground ? .white : .primary)
```

and:

```swift
.fill(state.usesProminentBackground ? Color.blue : Color(.controlBackgroundColor))
```

Inside `cameraToggleButton`, before `Button(action: action)`, add:

```swift
let state = CameraControlState.make(
    hasCamera: cameraManager.hasCamera,
    isAuthorized: cameraManager.isAuthorized,
    showCamera: showCamera,
    isCapturing: cameraManager.isCapturing
)
```

Use:

```swift
.foregroundColor(state.isActive ? .white : .primary)
.fill(state.isActive ? Color.purple : Color(.controlBackgroundColor))
.disabled(!state.isEnabled)
.help(state.help)
```

In `bottomControlBar`, replace the camera button arguments with:

```swift
let cameraState = CameraControlState.make(
    hasCamera: cameraManager.hasCamera,
    isAuthorized: cameraManager.isAuthorized,
    showCamera: showCamera,
    isCapturing: cameraManager.isCapturing
)

cameraToggleButton(
    isActive: cameraState.isActive,
    icon: cameraState.icon,
    title: cameraState.title,
    action: {
        showCamera.toggle()
        if showCamera && cameraManager.isAuthorized {
            cameraManager.startCapture()
        } else {
            cameraManager.stopCapture()
        }
    }
)
```

Delete the five helper methods after their usages are replaced.

- [ ] **Step 5: Run tests**

Run:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: output ends with `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit Task 4**

```bash
git add recordme/RecordingControlState.swift recordmeTests/RecordingControlStateTests.swift recordme/ContentView.swift
git commit -m "Extract recording control state"
```

## Task 5: Extract Permission View

**Files:**
- Create: `recordme/PermissionView.swift`
- Modify: `recordme/ContentView.swift`

- [ ] **Step 1: Create `PermissionView.swift`**

Create `recordme/PermissionView.swift`:

```swift
import SwiftUI

struct PermissionView: View {
    @ObservedObject var permissionManager: ScreenRecordingPermissionManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "display.trianglebadge.exclamationmark")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundColor(.orange)

                VStack(spacing: 8) {
                    Text("Screen Recording Permission Required")
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)

                    VStack(spacing: 8) {
                        Text("RecordMe needs permission to record your screen to capture displays and windows.")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)

                        if permissionManager.authorizationStatus == .denied {
                            Text("Permission was previously denied. Click 'Grant Permission' to try again, or use 'Open System Preferences' to enable manually.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 400)
                                .padding(.top, 4)
                        }
                    }
                }
            }

            VStack(spacing: 12) {
                if permissionManager.authorizationStatus == .checking {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking permissions...")
                            .font(.system(.callout, design: .rounded))
                    }
                    .padding(.vertical, 8)
                } else {
                    Button {
                        Task {
                            await permissionManager.requestPermission()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 14, weight: .medium))
                            Text("Grant Permission")
                                .font(.system(.callout, design: .rounded, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.blue)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        permissionManager.checkAuthorizationStatus()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                            Text("Refresh Status")
                                .font(.system(.callout, design: .rounded, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color(.separatorColor), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Check if permissions are already granted")

                    if permissionManager.authorizationStatus == .denied {
                        Button {
                            permissionManager.openSystemPreferences()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "gear")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Open System Preferences")
                                    .font(.system(.callout, design: .rounded, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Open Privacy & Security settings to manually enable screen recording")
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}
```

- [ ] **Step 2: Replace permission usage in `ContentView.swift`**

Replace:

```swift
permissionView
```

with:

```swift
PermissionView(permissionManager: permissionManager)
```

Delete the entire private `permissionView` property from `ContentView.swift`.

- [ ] **Step 3: Build and test**

Run:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: output ends with `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit Task 5**

```bash
git add recordme/PermissionView.swift recordme/ContentView.swift
git commit -m "Extract screen recording permission view"
```

## Task 6: Extract Preview And Recording Controls

**Files:**
- Create: `recordme/PreviewPane.swift`
- Create: `recordme/RecordingControlsView.swift`
- Modify: `recordme/ContentView.swift`

- [ ] **Step 1: Create `PreviewPane.swift`**

Create `recordme/PreviewPane.swift`:

```swift
import SwiftUI

struct PreviewPane: View {
    let previewImage: CGImage?
    let showCamera: Bool
    let isCameraCapturing: Bool
    let cameraImage: CGImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.controlBackgroundColor)
                    .opacity(0.5)

                if let previewImage {
                    ZStack(alignment: .bottomTrailing) {
                        Image(previewImage, scale: 1.0, label: Text("Preview"))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: geometry.size.width - 40)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                        if showCamera && isCameraCapturing, let cameraImage {
                            Image(cameraImage, scale: 1.0, label: Text("Camera"))
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 160, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                                .padding(16)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "display")
                            .font(.system(size: 64, weight: .thin))
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            Text("Select a source to see preview")
                                .font(.system(.title2, design: .rounded, weight: .medium))
                                .foregroundColor(.primary)

                            Text("Choose from a display or window")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
```

- [ ] **Step 2: Create `RecordingControlsView.swift`**

Create `recordme/RecordingControlsView.swift`:

```swift
import SwiftUI

struct RecordingControlsView: View {
    let selectedSourceType: RecordingSourceType
    let hasSelectedSource: Bool
    let isRecording: Bool
    let captureMicrophone: Bool
    let captureSystemAudio: Bool
    let cameraState: CameraControlState
    let selectDisplay: () -> Void
    let selectWindow: () -> Void
    let toggleMicrophone: () -> Void
    let toggleSystemAudio: () -> Void
    let toggleCamera: () -> Void
    let toggleRecording: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            sourceToggleButton(
                isSelected: selectedSourceType == .display,
                icon: "display",
                title: "Display",
                action: selectDisplay
            )

            sourceToggleButton(
                isSelected: selectedSourceType == .window,
                icon: "macwindow",
                title: "Window",
                action: selectWindow
            )

            Spacer()

            audioToggleButton(
                isActive: captureMicrophone,
                icon: captureMicrophone ? "mic" : "mic.slash",
                title: captureMicrophone ? "Mic" : "No Mic",
                action: toggleMicrophone
            )

            audioToggleButton(
                isActive: captureSystemAudio,
                icon: captureSystemAudio ? "speaker.wave.2" : "speaker.slash",
                title: captureSystemAudio ? "System Audio" : "No Audio",
                isProminent: captureSystemAudio,
                action: toggleSystemAudio
            )

            cameraToggleButton(
                icon: cameraState.icon,
                title: cameraState.title,
                state: cameraState,
                action: toggleCamera
            )

            Spacer()

            recordingButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial)
    }

    private var recordingButton: some View {
        let state = RecordingButtonState.make(isRecording: isRecording, hasSelectedSource: hasSelectedSource)

        return Button(action: toggleRecording) {
            HStack(spacing: 8) {
                if state.isRecording {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                } else if let icon = state.icon {
                    Image(systemName: icon)
                }

                Text(state.title)
            }
            .font(.system(.callout, design: .rounded, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(state.isRecording ? Color.red : (hasSelectedSource ? Color.red : Color.gray))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!state.isEnabled)
        .help(state.isRecording ? "Stop recording" : "Start recording")
    }

    private func sourceToggleButton(isSelected: Bool, icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(.callout, design: .rounded, weight: .medium))
            }
            .foregroundColor(isSelected ? .black : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.white : Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .help("Select \(title.lowercased())")
    }

    private func audioToggleButton(isActive: Bool, icon: String, title: String, isProminent: Bool = false, action: @escaping () -> Void) -> some View {
        let state = AudioControlState.make(isActive: isActive, isProminent: isProminent)

        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(.callout, design: .rounded, weight: .medium))
            }
            .foregroundColor(state.usesWhiteForeground ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(state.usesProminentBackground ? Color.blue : Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .help(title)
    }

    private func cameraToggleButton(icon: String, title: String, state: CameraControlState, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(.callout, design: .rounded, weight: .medium))
            }
            .foregroundColor(state.isActive ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(state.isActive ? Color.purple : Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!state.isEnabled)
        .help(state.help)
    }
}
```

- [ ] **Step 3: Replace preview and control usage in `ContentView.swift`**

Replace `previewArea` usage with:

```swift
PreviewPane(
    previewImage: recorder.previewImage,
    showCamera: showCamera,
    isCameraCapturing: cameraManager.isCapturing,
    cameraImage: cameraManager.cameraImage
)
```

Replace `bottomControlBar` usage with:

```swift
RecordingControlsView(
    selectedSourceType: selectedSourceType,
    hasSelectedSource: selectedFilter != nil,
    isRecording: recorder.isRecording,
    captureMicrophone: recorder.captureMicrophone,
    captureSystemAudio: captureSystemAudio,
    cameraState: CameraControlState.make(
        hasCamera: cameraManager.hasCamera,
        isAuthorized: cameraManager.isAuthorized,
        showCamera: showCamera,
        isCapturing: cameraManager.isCapturing
    ),
    selectDisplay: {
        selectedSourceType = .display
        showSourcePicker = true
    },
    selectWindow: {
        selectedSourceType = .window
        showSourcePicker = true
    },
    toggleMicrophone: {
        recorder.captureMicrophone.toggle()
    },
    toggleSystemAudio: {
        captureSystemAudio.toggle()
    },
    toggleCamera: {
        showCamera.toggle()
        if showCamera && cameraManager.isAuthorized {
            cameraManager.startCapture()
        } else {
            cameraManager.stopCapture()
        }
    },
    toggleRecording: recorder.isRecording ? stopRecording : startRecording
)
```

Delete `previewArea`, `bottomControlBar`, `sourceToggleButton`, `audioToggleButton`, `cameraToggleButton`, and `recordingButton` from `ContentView.swift`.

- [ ] **Step 4: Run tests**

Run:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: output ends with `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit Task 6**

```bash
git add recordme/PreviewPane.swift recordme/RecordingControlsView.swift recordme/ContentView.swift
git commit -m "Extract preview and recording controls"
```

## Task 7: Throttle Preview Work Independently From Recording

**Files:**
- Create: `recordme/PreviewFrameThrottler.swift`
- Create: `recordmeTests/PreviewFrameThrottlerTests.swift`
- Modify: `recordme/RecordingManager.swift`

- [ ] **Step 1: Write failing throttler tests**

Create `recordmeTests/PreviewFrameThrottlerTests.swift`:

```swift
import Testing
@testable import recordme

struct PreviewFrameThrottlerTests {
    @Test func disabledPreviewNeverEmitsFrames() {
        var throttler = PreviewFrameThrottler(interval: 4)

        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: false))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: false))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: false))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: false))
    }

    @Test func enabledPreviewEmitsEveryInterval() {
        var throttler = PreviewFrameThrottler(interval: 4)

        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(throttler.shouldEmitFrame(isPreviewEnabled: true))
    }

    @Test func resetStartsIntervalAgain() {
        var throttler = PreviewFrameThrottler(interval: 2)

        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(throttler.shouldEmitFrame(isPreviewEnabled: true))
        throttler.reset()
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(throttler.shouldEmitFrame(isPreviewEnabled: true))
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: build fails because `PreviewFrameThrottler` is not defined.

- [ ] **Step 3: Add the throttler**

Create `recordme/PreviewFrameThrottler.swift`:

```swift
struct PreviewFrameThrottler {
    private let interval: UInt
    private var frameCount: UInt = 0

    init(interval: UInt) {
        self.interval = max(interval, 1)
    }

    mutating func shouldEmitFrame(isPreviewEnabled: Bool) -> Bool {
        guard isPreviewEnabled else { return false }

        frameCount &+= 1
        return frameCount.isMultiple(of: interval)
    }

    mutating func reset() {
        frameCount = 0
    }
}
```

- [ ] **Step 4: Modify `RecordingPipeline` to use preview intent**

In `RecordingManager.swift`, change `ProcessingResult` to:

```swift
struct ProcessingResult {
    let previewImage: CGImage?
    let runtimeErrorMessage: String?
}
```

Replace:

```swift
private var previewFrameCounter: UInt = 0
```

with:

```swift
private var previewThrottler = PreviewFrameThrottler(interval: 4)
```

Replace `resetPreviewCounter()` with:

```swift
func resetPreviewCounter() {
    previewThrottler.reset()
}
```

In `reset()`, replace:

```swift
previewFrameCounter = 0
```

with:

```swift
previewThrottler.reset()
```

Change `processSampleBuffer` signature to:

```swift
func processSampleBuffer(
    _ sampleBuffer: CMSampleBuffer,
    type: SCStreamOutputType,
    cameraImage: CGImage?,
    isPreviewEnabled: Bool
) -> ProcessingResult {
```

Replace the preview section:

```swift
if type == .screen {
    previewFrameCounter &+= 1

    if previewFrameCounter.isMultiple(of: 4),
       let cgImage = sampleBuffer.makePreviewImage(using: ciContext) {
        if let cameraImage {
            previewImage = createCompositeImage(screenImage: cgImage, cameraImage: cameraImage) ?? cgImage
        } else {
            previewImage = cgImage
        }
    }
}
```

with:

```swift
if type == .screen,
   previewThrottler.shouldEmitFrame(isPreviewEnabled: isPreviewEnabled),
   let cgImage = sampleBuffer.makePreviewImage(using: ciContext) {
    if let cameraImage {
        previewImage = createCompositeImage(screenImage: cgImage, cameraImage: cameraImage) ?? cgImage
    } else {
        previewImage = cgImage
    }
}
```

- [ ] **Step 5: Avoid camera lookup when it is not useful**

In `RecordingManager.stream(_:didOutputSampleBuffer:of:)`, replace:

```swift
let cameraImage = cameraManager?.currentCameraImage()
let result = pipeline.processSampleBuffer(
    sbuf,
    type: type,
    cameraImage: cameraImage
)
```

with:

```swift
let needsCameraImage = type == .screen && (isRecording || isPreviewActive)
let cameraImage = needsCameraImage ? cameraManager?.currentCameraImage() : nil
let result = pipeline.processSampleBuffer(
    sbuf,
    type: type,
    cameraImage: cameraImage,
    isPreviewEnabled: isPreviewActive || isRecording
)
```

- [ ] **Step 6: Run tests**

Run:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: output ends with `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit Task 7**

```bash
git add recordme/PreviewFrameThrottler.swift recordmeTests/PreviewFrameThrottlerTests.swift recordme/RecordingManager.swift
git commit -m "Throttle preview frame work"
```

## Task 8: Extract Stream Configuration

**Files:**
- Create: `recordme/RecordingStreamConfiguration.swift`
- Create: `recordmeTests/RecordingStreamConfigurationTests.swift`
- Modify: `recordme/RecordingManager.swift`

- [ ] **Step 1: Write failing stream configuration tests**

Create `recordmeTests/RecordingStreamConfigurationTests.swift`:

```swift
import CoreMedia
import ScreenCaptureKit
import Testing
@testable import recordme

struct RecordingStreamConfigurationTests {
    @Test func previewConfigurationUsesLowerFrameRateAndNoAudio() {
        let config = RecordingStreamConfiguration.preview()

        #expect(config.width == 1_920)
        #expect(config.height == 1_080)
        #expect(config.minimumFrameInterval == CMTime(value: 1, timescale: 30))
        #expect(config.capturesAudio == false)
    }

    @Test func recordingConfigurationUsesSixtyFpsAndAudioFlags() {
        let config = RecordingStreamConfiguration.recording(captureSystemAudio: true, captureMicrophone: true)

        #expect(config.width == 1_920)
        #expect(config.height == 1_080)
        #expect(config.minimumFrameInterval == CMTime(value: 1, timescale: 60))
        #expect(config.capturesAudio == true)
        #expect(config.captureMicrophone == true)
    }

    @Test func recordingConfigurationDisablesAudioWhenBothSourcesAreOff() {
        let config = RecordingStreamConfiguration.recording(captureSystemAudio: false, captureMicrophone: false)

        #expect(config.capturesAudio == false)
        #expect(config.captureMicrophone == false)
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: build fails because `RecordingStreamConfiguration` is not defined.

- [ ] **Step 3: Add stream configuration factory**

Create `recordme/RecordingStreamConfiguration.swift`:

```swift
import CoreMedia
import ScreenCaptureKit

enum RecordingStreamConfiguration {
    static func preview() -> SCStreamConfiguration {
        let config = base()
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.capturesAudio = false
        return config
    }

    static func recording(captureSystemAudio: Bool, captureMicrophone: Bool) -> SCStreamConfiguration {
        let config = base()
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.capturesAudio = captureSystemAudio || captureMicrophone
        config.captureMicrophone = captureMicrophone
        return config
    }

    private static func base() -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = 1_920
        config.height = 1_080
        config.pixelFormat = kCVPixelFormatType_32BGRA
        return config
    }
}
```

- [ ] **Step 4: Use stream configuration factory**

In `RecordingManager.startPreview(filter:)`, replace the manual `SCStreamConfiguration` block with:

```swift
let config = RecordingStreamConfiguration.preview()
```

In `RecordingManager.start(filter:saveURL:)`, replace the manual `SCStreamConfiguration` block with:

```swift
let config = RecordingStreamConfiguration.recording(
    captureSystemAudio: captureSystemAudio,
    captureMicrophone: captureMicrophone
)
```

- [ ] **Step 5: Run tests**

Run:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: output ends with `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit Task 8**

```bash
git add recordme/RecordingStreamConfiguration.swift recordmeTests/RecordingStreamConfigurationTests.swift recordme/RecordingManager.swift
git commit -m "Extract recording stream configuration"
```

## Task 9: Add Open Source Documentation

**Files:**
- Modify: `README.md`
- Create: `CONTRIBUTING.md`
- Create: `SECURITY.md`
- Create: `.github/ISSUE_TEMPLATE/bug_report.md`
- Create: `.github/ISSUE_TEMPLATE/feature_request.md`
- Create: `LICENSE`
- Create: `docs/release-checklist.md`

- [ ] **Step 1: Update README public surface**

Rewrite `README.md` to keep the existing product description and include these sections in this order:

```markdown
# RecordMe

RecordMe is a lightweight native macOS screen recorder built with SwiftUI, ScreenCaptureKit, AVFoundation, and CoreImage.

It records displays or windows, supports system audio and microphone audio, and can place a live camera overlay on top of the recording.

## Features

- Display recording
- Window recording
- Live screen preview
- Optional camera overlay
- Optional microphone audio
- Optional system audio
- MP4 output with H.264 video and AAC audio
- Native macOS permission flow
- Saved recordings in Downloads
- Basic recorded video review and trim view

## Requirements

- macOS 15.1 or later
- Xcode 16.1 or later for source builds

## Install

Download the latest DMG from GitHub Releases, open it, and drag RecordMe to Applications.

Unsigned community builds may require right-clicking RecordMe and choosing Open on first launch.

## Build From Source

```bash
git clone https://github.com/abbeazale/recordme.git
cd recordme
open recordme.xcodeproj
```

Build and run the `recordme` scheme from Xcode.

Command-line build:

```bash
xcodebuild -project recordme.xcodeproj -scheme recordme -configuration Debug build
```

## Test

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

## Measure Release Size

```bash
./scripts/measure-release-size.sh
```

The baseline is documented in `docs/release-size-baseline.md`.

## Privacy

RecordMe records locally on your Mac. The app requests macOS permissions for screen recording, camera, microphone, and Downloads access only for the features you use. RecordMe does not include analytics, telemetry, accounts, or network upload code.

## Distribution

Development and community builds may be unsigned. Production-quality public builds should be signed with a Developer ID certificate and notarized for the best Gatekeeper experience.

## Contributing

See `CONTRIBUTING.md`.

## License

MIT. See `LICENSE`.
```

- [ ] **Step 2: Add contributing guide**

Create `CONTRIBUTING.md`:

```markdown
# Contributing

Thanks for improving RecordMe.

## Local Setup

Requirements:

- macOS 15.1 or later
- Xcode 16.1 or later

Open the project:

```bash
open recordme.xcodeproj
```

## Build

```bash
xcodebuild -project recordme.xcodeproj -scheme recordme -configuration Debug build
```

## Test

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

## Release Size Check

```bash
./scripts/measure-release-size.sh
```

Include the size impact in pull requests that touch assets, release settings, recording internals, or dependencies.

## Coding Expectations

- Keep the app native and dependency-light.
- Prefer focused Swift files with one clear responsibility.
- Preserve display recording, window recording, camera overlay, microphone audio, system audio, MP4 saving, and preview behavior.
- Add Swift Testing coverage for pure logic.
- Document manual verification when macOS permissions make automation impractical.
```

- [ ] **Step 3: Add security and privacy file**

Create `SECURITY.md`:

```markdown
# Security

RecordMe is a local-first macOS screen recording app.

## Permissions

RecordMe may request:

- Screen Recording, to capture displays and windows.
- Camera, to show a camera overlay.
- Microphone, to record microphone audio.
- Downloads folder access, to save recordings.

The app should not upload recordings or collect analytics.

## Reporting Issues

Please report security or privacy issues through a private maintainer channel before opening a public issue when disclosure could put users at risk.
```

- [ ] **Step 4: Add issue templates**

Create `.github/ISSUE_TEMPLATE/bug_report.md`:

```markdown
---
name: Bug report
about: Report a RecordMe problem
title: "[Bug]: "
labels: bug
assignees: ""
---

## Summary

Describe the problem.

## Steps To Reproduce

1. Open RecordMe.
2. Select a display or window.
3. Start recording.
4. Stop recording.

## Expected Behavior

Describe what should happen.

## Actual Behavior

Describe what happened.

## Environment

- macOS version:
- Mac model:
- RecordMe version or commit:

## Recording Options

- Display or window:
- Camera overlay enabled:
- Microphone enabled:
- System audio enabled:
```

Create `.github/ISSUE_TEMPLATE/feature_request.md`:

```markdown
---
name: Feature request
about: Suggest an improvement for RecordMe
title: "[Feature]: "
labels: enhancement
assignees: ""
---

## Problem

Describe the workflow this would improve.

## Proposed Solution

Describe the feature.

## Lightweight Impact

Explain whether this affects app size, CPU, memory, dependencies, or product complexity.
```

- [ ] **Step 5: Add MIT license**

Create `LICENSE`:

```text
MIT License

Copyright (c) 2026 Abbe Azale

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 6: Add manual release checklist**

Create `docs/release-checklist.md`:

```markdown
# Release Checklist

## Automated

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
./scripts/measure-release-size.sh
```

## Manual Recording Verification

- Grant screen recording permission.
- Select a display and confirm live preview appears.
- Record a display with system audio enabled.
- Stop recording and confirm an MP4 appears in Downloads.
- Play the saved MP4 and confirm screen video is present.
- Select a window and confirm live preview appears.
- Record a window and confirm the saved MP4 contains only the selected window.
- Enable microphone and confirm microphone audio is present in the saved MP4.
- Enable camera overlay and confirm the saved MP4 includes the overlay.
- Disable camera overlay and confirm camera capture stops.
- Deny or revoke a permission and confirm RecordMe shows a clear recovery path.

## Release Notes

Include:

- App size from `./scripts/measure-release-size.sh`.
- macOS requirement.
- Signing and notarization status.
- Manual verification date.
```

- [ ] **Step 7: Verify docs**

Run:

```bash
rg -n '<placeholder-marker-regex>' README.md CONTRIBUTING.md SECURITY.md docs .github LICENSE
git diff --check -- README.md CONTRIBUTING.md SECURITY.md docs .github LICENSE
```

Expected: `rg` exits with status `1` because there are no matches, and `git diff --check` prints nothing.

- [ ] **Step 8: Commit Task 9**

```bash
git add README.md CONTRIBUTING.md SECURITY.md LICENSE docs .github
git commit -m "Add open source project documentation"
```

## Task 10: Final Verification And Size Report

**Files:**
- Modify: `docs/release-size-baseline.md`

- [ ] **Step 1: Run the full automated test suite**

Run:

```bash
xcodebuild test -project recordme.xcodeproj -scheme recordme -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: output ends with `** TEST SUCCEEDED **`.

- [ ] **Step 2: Run Release build**

Run:

```bash
xcodebuild -project recordme.xcodeproj -scheme recordme -configuration Release -derivedDataPath /tmp/recordme-final CODE_SIGNING_ALLOWED=NO build
```

Expected: output ends with `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run size measurement**

Run:

```bash
./scripts/measure-release-size.sh | tee /tmp/recordme-final-size.txt
```

Expected: output contains `RecordMe release size report` and `Compressed DMG:`.

- [ ] **Step 4: Update baseline if measured values changed**

If `/tmp/recordme-final-size.txt` differs from `docs/release-size-baseline.md`, update the table values to the final measured values. Keep the explanatory notes unchanged.

- [ ] **Step 5: Verify no generated artifacts are staged**

Run:

```bash
git status --short
```

Expected: changed files are source, docs, scripts, project settings, asset deletions, and git metadata files only. `build/`, `.claude/`, `.DS_Store`, and `RecordMe*.dmg` do not appear.

- [ ] **Step 6: Commit final baseline changes if needed**

If `docs/release-size-baseline.md` changed in Step 4:

```bash
git add docs/release-size-baseline.md
git commit -m "Update release size baseline"
```

If the file did not change, skip this commit.

- [ ] **Step 7: Summarize manual checks for the user**

Report which automated commands passed and list the manual checks from `docs/release-checklist.md` that still need to be performed on a Mac with screen recording, camera, microphone, and system audio permissions.

## Self-Review

Spec coverage:

- Measurement and release-size reporting: Task 1 and Task 10.
- Ignore rules and generated/local file cleanup: Task 2.
- Release configuration hygiene: Task 3.
- Duplicate asset audit/removal: Task 2.
- UI modularization: Task 4, Task 5, and Task 6.
- Runtime preview/camera work reduction: Task 7.
- Recording configuration clarity: Task 8.
- Tests: Task 4, Task 7, Task 8, and Task 10.
- Open source documentation: Task 9.
- Git history cleanup decision: documented as separate work in Task 1 docs and excluded from implementation.

No feature cuts:

- Display and window recording remain in `ContentView.swift` source picker and `RecordingManager`.
- Camera overlay remains in `PreviewPane` and `RecordingManager`.
- Microphone and system audio remain in `RecordingControlsView` and `RecordingManager`.
- MP4 output remains in `RecordingPipeline`.
- Permissions remain in `PermissionView` and `ScreenRecordingPermissionManager`.
- Playback/trim UI remains untouched in `VideoPlayer.swift`.
