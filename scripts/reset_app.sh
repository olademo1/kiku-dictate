#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Kiku Dictate"
BUNDLE_ID="com.dataiku.kikudictate"
APP_PATH="/Applications/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  APP_PATH="$HOME/Applications/${APP_NAME}.app"
fi

osascript -e 'tell application "Kiku Dictate" to quit' >/dev/null 2>&1 || true
sleep 0.5

tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
tccutil reset Microphone "$BUNDLE_ID" >/dev/null 2>&1 || true

rm -rf "$HOME/Library/Application Support/KikuDictate" >/dev/null 2>&1 || true
rm -f "$HOME/Library/Preferences/${BUNDLE_ID}.plist" >/dev/null 2>&1 || true

killall Dock >/dev/null 2>&1 || true

if [[ -d "$APP_PATH" ]]; then
  open "$APP_PATH" >/dev/null 2>&1 || true
else
  echo "WARNING: $APP_PATH not found. Install it first with: ./scripts/install_app.sh"
fi

echo "Reset complete."

