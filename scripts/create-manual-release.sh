#!/bin/bash

# Manual Release Creation Script
# Use this if GitHub Actions continues to have permission issues

set -e

echo "🚀 Creating manual release for RecordMe..."

# Check if version is provided
if [ -z "$1" ]; then
    echo "Usage: ./scripts/create-manual-release.sh v1.0.5"
    exit 1
fi

VERSION=$1

# Clean and build
echo "📦 Building RecordMe..."
rm -rf build/
xcodebuild -scheme recordme \
  -configuration Release \
  -derivedDataPath ./build \
  -destination 'generic/platform=macOS' \
  build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  DEVELOPMENT_TEAM=""

# Find the app
APP_PATH=$(find ./build -name "recordme.app" -type d | head -1)
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found after build"
    exit 1
fi

echo "✅ App built at: $APP_PATH"

# Create DMG
echo "💿 Creating DMG..."
rm -rf dmg-temp/
mkdir -p dmg-temp
cp -R "$APP_PATH" dmg-temp/RecordMe.app

DMG_NAME="RecordMe-${VERSION}.dmg"
rm -f "$DMG_NAME"
hdiutil create -volname "RecordMe" -srcfolder dmg-temp -ov -format UDZO "$DMG_NAME"

echo "✅ DMG created: $DMG_NAME"

# Create git tag
echo "🏷️ Creating git tag..."
git tag "$VERSION" 2>/dev/null || echo "Tag $VERSION already exists"
git push origin "$VERSION" 2>/dev/null || echo "Tag already pushed"

# Create GitHub release using CLI
echo "📦 Creating GitHub release..."
gh release create "$VERSION" "$DMG_NAME" \
  --title "RecordMe $VERSION" \
  --notes "Manual release build for RecordMe $VERSION

**Download**: $DMG_NAME

**Installation**: 
1. Download the DMG file
2. Open the DMG file  
3. Drag RecordMe.app to your Applications folder
4. Right-click RecordMe in Applications → Open (first time only)
5. Grant screen recording permissions when prompted

**Note**: You may see a security warning on first launch - this is normal for unsigned apps. Right-click → Open to bypass."

echo "🎉 Release created successfully!"
echo "📂 Download at: https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name')/releases"

# Clean up
rm -rf dmg-temp/