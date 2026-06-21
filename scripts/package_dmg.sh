#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/Dataiku Chirp.app}"
RELEASE_DIR="$ROOT_DIR/releases"
VOL_NAME="Install Dataiku Chirp"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_DMG="${2:-$RELEASE_DIR/DataikuChirp-macOS-$STAMP.dmg}"
SHA_PATH="$OUTPUT_DMG.sha256"
STAGING_ROOT="$(mktemp -d /tmp/dataiku-chirp-dmg.XXXXXX)"
RW_DMG="$STAGING_ROOT/DataikuChirp-rw.dmg"
MOUNT_POINT=""

cleanup() {
  if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  exit 1
fi

mkdir -p "$RELEASE_DIR"
rm -f "$OUTPUT_DMG" "$SHA_PATH"

APP_SIZE_KB="$(/usr/bin/du -sk "$APP_PATH" | awk '{print $1}')"
DMG_SIZE_MB=$((APP_SIZE_KB / 1024 + 700))

echo "Creating writable disk image..."
hdiutil create \
  -size "${DMG_SIZE_MB}m" \
  -fs HFS+ \
  -volname "$VOL_NAME" \
  "$RW_DMG" \
  -quiet

MOUNT_OUTPUT="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen -nobrowse)"
MOUNT_POINT="$(printf '%s\n' "$MOUNT_OUTPUT" | sed -n 's#^.*\(/Volumes/.*\)$#\1#p' | tail -1)"
if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
  echo "Could not mount writable disk image."
  echo "$MOUNT_OUTPUT"
  exit 1
fi

echo "Copying app and Applications shortcut..."
/usr/bin/ditto "$APP_PATH" "$MOUNT_POINT/Dataiku Chirp.app"
ln -s /Applications "$MOUNT_POINT/Applications"

BACKGROUND_DIR="$MOUNT_POINT/.background"
BACKGROUND_PNG="$BACKGROUND_DIR/background.png"
mkdir -p "$BACKGROUND_DIR"

python3 - <<PY
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

out = Path(r"$BACKGROUND_PNG")
img = Image.new("RGB", (720, 420), "#f7f5ee")
draw = ImageDraw.Draw(img)

def font(size, bold=False):
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf" if bold else "/Library/Fonts/Arial.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()

title_font = font(28, True)
body_font = font(16)

draw.rounded_rectangle((0, 0, 719, 419), radius=0, fill="#f7f5ee")
draw.rectangle((0, 0, 719, 419), fill="#f7f5ee")

for x, y, r, color in [
    (74, 286, 120, "#e4f7ef"),
    (590, 80, 150, "#e9eefc"),
    (420, 354, 170, "#fff5e8"),
]:
    draw.ellipse((x-r, y-r, x+r, y+r), fill=color)

draw.text((62, 46), "Install Dataiku Chirp", fill="#111827", font=title_font)
draw.text((62, 86), "Drag the app into Applications. Then open it from Applications.", fill="#5f6b7a", font=body_font)

arrow = [(314, 204), (430, 204), (430, 170), (508, 236), (430, 302), (430, 268), (314, 268)]
draw.polygon(arrow, fill="#c8d0db")
draw.polygon(arrow, outline="#aeb8c6")

img.save(out)
PY

echo "Arranging Finder window..."
osascript <<OSA
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {120, 120, 840, 540}
    set theViewOptions to icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 116
    set background picture of theViewOptions to file ".background:background.png"
    set position of item "Dataiku Chirp.app" of container window to {180, 245}
    set position of item "Applications" of container window to {575, 245}
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA

sync
hdiutil detach "$MOUNT_POINT" -quiet
MOUNT_POINT=""

echo "Compressing disk image..."
hdiutil convert "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$OUTPUT_DMG" \
  -quiet

SIGN_IDENTITY="${DATAIKU_CHIRP_DMG_SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]] && command -v security >/dev/null 2>&1; then
  SIGN_IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null | awk -F'\"' '/Developer ID Application:/{print $2; exit}')"
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "Signing disk image with identity: $SIGN_IDENTITY"
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$OUTPUT_DMG"
  codesign --verify --verbose=2 "$OUTPUT_DMG"
fi

if [[ "${DATAIKU_CHIRP_NOTARIZE_DMG:-0}" == "1" ]]; then
  NOTARY_ARGS=(submit "$OUTPUT_DMG" --wait)
  if [[ -n "${APPLE_NOTARY_PROFILE:-}" ]]; then
    NOTARY_ARGS+=(--keychain-profile "$APPLE_NOTARY_PROFILE")
  elif [[ -n "${APPLE_NOTARY_KEY_PATH:-}" && -n "${APPLE_NOTARY_KEY_ID:-}" && -n "${APPLE_NOTARY_ISSUER_ID:-}" ]]; then
    NOTARY_ARGS+=(--key "$APPLE_NOTARY_KEY_PATH" --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_ISSUER_ID")
  else
    echo "DATAIKU_CHIRP_NOTARIZE_DMG=1 requires APPLE_NOTARY_PROFILE or App Store Connect API key env vars."
    exit 1
  fi

  echo "Submitting disk image to Apple notarization service..."
  xcrun notarytool "${NOTARY_ARGS[@]}"
  echo "Stapling disk image..."
  xcrun stapler staple "$OUTPUT_DMG"
  xcrun stapler validate "$OUTPUT_DMG"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$OUTPUT_DMG"
fi

/usr/bin/shasum -a 256 "$OUTPUT_DMG" > "$SHA_PATH"

echo "DMG: $OUTPUT_DMG"
echo "Checksum: $SHA_PATH"
