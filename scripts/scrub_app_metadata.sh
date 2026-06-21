#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Usage: $0 /path/to/App.app"
  exit 1
fi

xattr -cr "$APP_PATH" >/dev/null 2>&1 || true
for attr in com.apple.FinderInfo com.apple.fileprovider.fpfs#P com.apple.provenance; do
  xattr -d "$attr" "$APP_PATH" >/dev/null 2>&1 || true
done

find "$APP_PATH" -exec xattr -d com.apple.FinderInfo {} \; >/dev/null 2>&1 || true
find "$APP_PATH" -exec xattr -d com.apple.fileprovider.fpfs#P {} \; >/dev/null 2>&1 || true
find "$APP_PATH" -exec xattr -d com.apple.provenance {} \; >/dev/null 2>&1 || true

for attr in com.apple.FinderInfo com.apple.fileprovider.fpfs#P com.apple.provenance; do
  xattr -d "$attr" "$APP_PATH" >/dev/null 2>&1 || true
done
