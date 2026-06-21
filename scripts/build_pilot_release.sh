#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RELEASE_DIR="$ROOT_DIR/releases"
APP_PATH="$ROOT_DIR/dist/Dataiku Chirp.app"
STAMP="$(date +%Y%m%d-%H%M%S)"
ZIP_PATH="$RELEASE_DIR/DataikuChirp-macOS-all-in-one-$STAMP.zip"
SHA_PATH="$ZIP_PATH.sha256"

mkdir -p "$RELEASE_DIR"

echo "Building Dataiku Chirp with bundled local runtime..."
DATAIKU_CHIRP_BUNDLE_LOCAL_RUNTIME=1 ./scripts/build_app.sh

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found after build: $APP_PATH"
  exit 1
fi

echo "Built app size:"
/usr/bin/du -sh "$APP_PATH"

if [[ "${DATAIKU_CHIRP_NOTARIZE:-0}" == "1" ]]; then
  echo "Notarizing pilot release..."
  ./scripts/notarize_release.sh "$APP_PATH"
  exit 0
fi

echo "Creating all-in-one pilot zip..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"
/usr/bin/ditto -c -k --norsrc --keepParent "$APP_PATH" "$ZIP_PATH"
/usr/bin/shasum -a 256 "$ZIP_PATH" > "$SHA_PATH"

echo "All-in-one pilot zip: $ZIP_PATH"
echo "Checksum: $SHA_PATH"
echo "Set DATAIKU_CHIRP_NOTARIZE=1 and notarization credentials to create a notarized release."
