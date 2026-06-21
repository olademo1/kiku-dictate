#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Kiku Dictate.app"
SRC_APP="$ROOT_DIR/dist/$APP_NAME"

if [[ ! -d "$SRC_APP" ]]; then
  echo "ERROR: $SRC_APP not found. Run: $ROOT_DIR/scripts/build_app.sh"
  exit 1
fi

DEST_DIR="/Applications"
if [[ ! -w "$DEST_DIR" ]]; then
  DEST_DIR="$HOME/Applications"
  mkdir -p "$DEST_DIR"
  echo "Note: no write access to /Applications; installing to $DEST_DIR instead."
fi

DEST_APP="$DEST_DIR/$APP_NAME"
STAMP="$(date +%Y%m%d%H%M%S)"
if [[ -d "$DEST_APP" ]]; then
  mv "$DEST_APP" "$DEST_APP.old.$STAMP"
fi

ditto --norsrc "$SRC_APP" "$DEST_APP"
xattr -cr "$DEST_APP" >/dev/null 2>&1 || true
xattr -dr com.apple.quarantine "$DEST_APP" >/dev/null 2>&1 || true

if command -v codesign >/dev/null 2>&1; then
  SIGN_IDENTITY=""
  if command -v security >/dev/null 2>&1; then
    SIGN_IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null | awk -F'\"' '/Developer ID Application:/{print $2; exit}')"
    if [[ -z "$SIGN_IDENTITY" ]]; then
      SIGN_IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null | awk -F'\"' '/Apple Development:/{print $2; exit}')"
    fi
  fi

  if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "Signing installed app with identity: $SIGN_IDENTITY"
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$DEST_APP"
  else
    echo "Signing installed app ad-hoc."
    codesign --force --deep --sign - "$DEST_APP"
  fi

  codesign --verify --deep --strict --verbose=2 "$DEST_APP"
fi

echo "Installed app: $DEST_APP"
open "$DEST_APP" >/dev/null 2>&1 || true
