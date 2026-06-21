#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Dataiku Chirp"
APP_BUNDLE="$APP_NAME.app"
EXECUTABLE_NAME="KikuDictate"
BUNDLE_ID="com.dataiku.chirp"
VERSION="0.2.7"
BUILD_NUMBER="$(date +%Y%m%d%H%M%S)"
ENTITLEMENTS_PLIST="$ROOT_DIR/KikuDictate.entitlements"
GLOBAL_USAGE_ENDPOINT="${DATAIKU_CHIRP_USAGE_ENDPOINT:-}"
GLOBAL_USAGE_TEAM_KEY="${DATAIKU_CHIRP_USAGE_TEAM_KEY:-}"

echo "Building release binary..."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$EXECUTABLE_NAME"

if [[ ! -f "$BIN_PATH" ]]; then
  echo "ERROR: built executable not found at: $BIN_PATH"
  exit 1
fi

DIST_DIR="$ROOT_DIR/dist"
OUT_APP="$DIST_DIR/$APP_BUNDLE"
STAGING_ROOT="$(mktemp -d /tmp/kiku-dictate-build.XXXXXX)"
STAGED_APP="$STAGING_ROOT/$APP_BUNDLE"

cleanup() {
  rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

mkdir -p "$DIST_DIR"
if [[ -d "$OUT_APP" ]]; then
  mv "$OUT_APP" "$OUT_APP.old.$BUILD_NUMBER"
fi

CONTENTS="$STAGED_APP/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

ICON_PNG="$ROOT_DIR/assets/app-icon-1024.png"
BRAND_MARK_PNG="$ROOT_DIR/assets/dataiku-bird-speech-header.png"
if [[ -f "$ICON_PNG" ]] && command -v iconutil >/dev/null 2>&1; then
  TMP_DIR="$(mktemp -d)"
  ICONSET="$TMP_DIR/AppIcon.iconset"
  mkdir -p "$ICONSET"

  python3 - <<PY
from pathlib import Path
from PIL import Image

src = Path(r"$ICON_PNG")
out = Path(r"$ICONSET")
img = Image.open(src).convert("RGBA")
resample = getattr(Image, "Resampling", Image).LANCZOS
mapping = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}
for name, size in mapping.items():
    img.resize((size, size), resample=resample).save(out / name, format="PNG")
PY

  iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/AppIcon.icns" >/dev/null
  rm -rf "$TMP_DIR"
fi

if [[ -f "$BRAND_MARK_PNG" ]]; then
  cp "$BRAND_MARK_PNG" "$RESOURCES_DIR/BrandMark.png"
fi

INFO_PLIST="$CONTENTS/Info.plist"
cat > "$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>Dataiku Chirp needs microphone access only while you record dictation.</string>
  <key>NSAccessibilityUsageDescription</key>
  <string>Dataiku Chirp uses Accessibility only to paste transcribed text into the active app.</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>DataikuChirpUsageEndpoint</key>
  <string>$GLOBAL_USAGE_ENDPOINT</string>
  <key>DataikuChirpUsageTeamKey</key>
  <string>$GLOBAL_USAGE_TEAM_KEY</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  SIGN_IDENTITY=""
  CODESIGN_ENTITLEMENTS=()
  if [[ -f "$ENTITLEMENTS_PLIST" ]]; then
    CODESIGN_ENTITLEMENTS=(--entitlements "$ENTITLEMENTS_PLIST")
  fi

  if command -v security >/dev/null 2>&1; then
    SIGN_IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null | awk -F'\"' '/Developer ID Application:/{print $2; exit}')"
    if [[ -z "$SIGN_IDENTITY" ]]; then
      SIGN_IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null | awk -F'\"' '/Apple Development:/{print $2; exit}')"
    fi
  fi

  if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "Signing with identity: $SIGN_IDENTITY"
    xattr -cr "$STAGED_APP" >/dev/null 2>&1 || true
    codesign --force --deep --options runtime "${CODESIGN_ENTITLEMENTS[@]}" --sign "$SIGN_IDENTITY" "$STAGED_APP"
  else
    echo "Signing ad-hoc."
    xattr -cr "$STAGED_APP" >/dev/null 2>&1 || true
    codesign --force --deep "${CODESIGN_ENTITLEMENTS[@]}" --sign - "$STAGED_APP"
  fi

  codesign --verify --deep --strict --verbose=2 "$STAGED_APP"
fi

ditto --norsrc "$STAGED_APP" "$OUT_APP"
xattr -cr "$OUT_APP" >/dev/null 2>&1 || true

echo "Built app: $OUT_APP"
echo "Note: install script re-signs after copying out of file-provider folders."
