#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="/Applications/Kiku Dictate.app"
if [[ ! -d "$APP_PATH" ]]; then
  APP_PATH="$HOME/Applications/Kiku Dictate.app"
fi

RELEASE_DIR="$ROOT_DIR/releases"
STAMP="$(date +%Y%m%d-%H%M%S)"
ZIP_PATH="$RELEASE_DIR/KikuDictate-macOS-$STAMP.zip"
SHA_PATH="$ZIP_PATH.sha256"

mkdir -p "$RELEASE_DIR"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found. Run ./scripts/install_app.sh first."
  exit 1
fi

xattr -cr "$APP_PATH" >/dev/null 2>&1 || true
xattr -dr com.apple.quarantine "$APP_PATH" >/dev/null 2>&1 || true

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"
/usr/bin/ditto -c -k --norsrc --keepParent "$APP_PATH" "$ZIP_PATH"
/usr/bin/shasum -a 256 "$ZIP_PATH" > "$SHA_PATH"

echo "Release zip: $ZIP_PATH"
echo "Checksum: $SHA_PATH"
