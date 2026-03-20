#!/bin/bash

# Update the release description with better installation instructions

VERSION="v1.0.5"

gh release edit "$VERSION" --notes "# RecordMe $VERSION

A native macOS screen recording application with camera overlay support.

## Download & Installation

1. **Download** the DMG file below
2. **Open** the DMG and drag RecordMe to Applications
3. **⚠️ Important**: Right-click RecordMe in Applications → **\"Open\"**
4. **Click \"Open\"** in the security dialog (this bypasses the malware warning)
5. **Grant permissions** when prompted (screen recording, camera, microphone)

## Security Warning - Normal Behavior

You'll see: *\"Apple could not verify RecordMe is free of malware\"*

**This is completely normal** for unsigned apps. The app is safe - it's open source and you can review the code.

**Solution**: Right-click → \"Open\" instead of double-clicking.

## Features

- High-quality screen recording (up to 60fps, 1080p)
- Real-time camera overlay
- System audio + microphone recording
- Window/display selection
- MP4 output format
- Modern SwiftUI interface

## Requirements

- macOS 13.0 (Ventura) or later
- Screen recording permission
- Camera/microphone permissions (optional)

## Having Issues?

See the [Installation Guide](https://github.com/abbeazale/recordme/blob/main/INSTALLATION_GUIDE.md) for detailed troubleshooting steps."

echo "✅ Updated release description for $VERSION"