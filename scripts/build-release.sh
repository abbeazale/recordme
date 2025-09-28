#!/bin/bash

# RecordMe Release Build Script
# This script builds and packages RecordMe for distribution

set -e

echo "🚀 Building RecordMe for release..."

# Clean previous builds
rm -rf build/
rm -f RecordMe*.dmg

# Build the app
echo "📦 Building app..."
xcodebuild -scheme recordme -configuration Release -derivedDataPath ./build clean build

# Find the built app
APP_PATH=$(find ./build -name "recordme.app" -type d | head -1)

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found after build"
    exit 1
fi

echo "✅ App built successfully: $APP_PATH"

# Create DMG
echo "💿 Creating DMG..."
mkdir -p dmg-temp
cp -R "$APP_PATH" dmg-temp/RecordMe.app

# Create a nice DMG with background and proper layout
mkdir -p dmg-temp/.background
# You can add a background image here if you want

# Create the DMG
DMG_NAME="RecordMe-$(date +%Y%m%d).dmg"
hdiutil create -volname "RecordMe" -srcfolder dmg-temp -ov -format UDZO "$DMG_NAME"

# Clean up
rm -rf dmg-temp/

echo "✅ DMG created: $DMG_NAME"
echo "📂 You can now distribute this DMG file"

# Open the folder containing the DMG
open .