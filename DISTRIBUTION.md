# RecordMe Distribution Guide

This guide explains how to distribute RecordMe to users without requiring them to build from source.

## 🎯 Distribution Options

### 1. **GitHub Releases (Recommended)**
The easiest way for users to download your app:

```bash
# To create a release:
git tag v1.0.0
git push origin v1.0.0
```

This will automatically:
- Build the app via GitHub Actions
- Create a DMG file
- Publish it as a GitHub Release
- Users can download directly from GitHub

**Download URL**: `https://github.com/yourusername/recordme/releases`

### 2. **Manual DMG Creation**
If you want to create releases locally:

```bash
# Run the build script
./scripts/build-release.sh
```

This creates a `RecordMe-YYYYMMDD.dmg` file you can share directly.

### 3. **Homebrew Cask (Advanced)**
For power users who prefer command-line installation:

```bash
# Users would install with:
brew install --cask recordme
```

Requires creating a Homebrew Cask formula (see below).

## 📦 DMG Contents

Your DMG will contain:
- `RecordMe.app` - The main application
- Drag-to-Applications shortcut (optional)
- Background image with instructions (optional)

## 🔐 Code Signing (Important!)

For production distribution, you'll need:

1. **Apple Developer Account** ($99/year)
2. **Developer ID Certificate** for code signing
3. **Notarization** for macOS Gatekeeper

Without code signing, users will see "unidentified developer" warnings.

## 🍺 Homebrew Cask Setup

To add RecordMe to Homebrew:

1. Create a cask formula in `homebrew-cask` repository
2. Example formula:

```ruby
cask "recordme" do
  version "1.0.0"
  sha256 "your-dmg-hash-here"

  url "https://github.com/yourusername/recordme/releases/download/v#{version}/RecordMe.dmg"
  name "RecordMe"
  desc "Screen recording app with camera overlay"
  homepage "https://github.com/yourusername/recordme"

  app "RecordMe.app"
end
```

## 📋 User Installation Instructions

### From GitHub Releases:
1. Go to [Releases page](https://github.com/yourusername/recordme/releases)
2. Download the latest `RecordMe.dmg`
3. Open the DMG and drag RecordMe to Applications
4. Launch from Applications folder

### From Homebrew:
```bash
brew install --cask recordme
```

### Security Notes:
- On first launch, users may need to right-click → "Open" due to Gatekeeper
- Grant screen recording permissions when prompted
- App is sandboxed for security

## 🚀 Recommended Workflow

1. **Development**: Work on `main` branch
2. **Testing**: Create release candidates with `git tag v1.0.0-rc1`
3. **Release**: Create final tags like `git tag v1.0.0`
4. **Distribution**: GitHub Actions automatically creates DMG
5. **Users**: Download from GitHub Releases page

This gives you professional distribution without App Store complexity!