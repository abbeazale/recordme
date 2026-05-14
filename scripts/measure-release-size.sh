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
