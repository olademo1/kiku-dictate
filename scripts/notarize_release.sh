#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/Dataiku Chirp.app}"
APP_NAME="$(basename "$APP_PATH" .app)"
RELEASE_DIR="$ROOT_DIR/releases"
STAMP="$(date +%Y%m%d-%H%M%S)"
SUBMIT_ZIP="$RELEASE_DIR/$APP_NAME-notary-submit-$STAMP.zip"
FINAL_ZIP="$RELEASE_DIR/DataikuChirp-macOS-notarized-$STAMP.zip"
SHA_PATH="$FINAL_ZIP.sha256"
STAGING_ROOT="$(mktemp -d /tmp/dataiku-chirp-notary.XXXXXX)"
STAGED_APP="$STAGING_ROOT/$APP_NAME.app"

cleanup() {
  rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  echo "Run ./scripts/build_app.sh first, or pass the path to a built .app bundle."
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun was not found. Install Xcode or Xcode Command Line Tools first."
  exit 1
fi

mkdir -p "$RELEASE_DIR"

echo "Staging app outside file-provider folders..."
/usr/bin/ditto --norsrc "$APP_PATH" "$STAGED_APP"
./scripts/scrub_app_metadata.sh "$STAGED_APP"

echo "Verifying code signature..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

SIGN_DETAILS="$(/usr/bin/codesign -dv --verbose=4 "$STAGED_APP" 2>&1 || true)"
if ! grep -q "^Authority=Developer ID Application:" <<<"$SIGN_DETAILS"; then
  echo "The app is not signed with a Developer ID Application certificate."
  echo "Notarization for outside-App-Store distribution requires a Developer ID-signed app."
  echo
  echo "Current signing authorities:"
  grep "^Authority=" <<<"$SIGN_DETAILS" || true
  exit 1
fi

echo "Creating notarization upload zip..."
/usr/bin/ditto -c -k --norsrc --keepParent "$STAGED_APP" "$SUBMIT_ZIP"

NOTARY_ARGS=(submit "$SUBMIT_ZIP" --wait)

if [[ -n "${APPLE_NOTARY_PROFILE:-}" ]]; then
  NOTARY_ARGS+=(--keychain-profile "$APPLE_NOTARY_PROFILE")
elif [[ -n "${APPLE_NOTARY_KEY_PATH:-}" && -n "${APPLE_NOTARY_KEY_ID:-}" && -n "${APPLE_NOTARY_ISSUER_ID:-}" ]]; then
  NOTARY_ARGS+=(--key "$APPLE_NOTARY_KEY_PATH" --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_ISSUER_ID")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  NOTARY_ARGS+=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD")
else
  cat <<'EOF'
Missing notarization credentials.

Use a stored notarytool Keychain profile:
  APPLE_NOTARY_PROFILE=dataiku-chirp-notary

Use App Store Connect API key credentials:
  APPLE_NOTARY_KEY_PATH=/path/AuthKey_ABC123DEFG.p8
  APPLE_NOTARY_KEY_ID=ABC123DEFG
  APPLE_NOTARY_ISSUER_ID=00000000-0000-0000-0000-000000000000

Or use Apple ID credentials with an app-specific password:
  APPLE_ID=you@example.com
  APPLE_TEAM_ID=TEAMID1234
  APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx
EOF
  exit 1
fi

echo "Submitting to Apple notarization service..."
xcrun notarytool "${NOTARY_ARGS[@]}"

echo "Stapling notarization ticket..."
xcrun stapler staple "$STAGED_APP"
xcrun stapler validate "$STAGED_APP"

echo "Checking Gatekeeper assessment..."
/usr/sbin/spctl --assess --type execute --verbose=4 "$STAGED_APP"

echo "Creating final stapled release zip..."
/usr/bin/ditto -c -k --norsrc --keepParent "$STAGED_APP" "$FINAL_ZIP"
/usr/bin/shasum -a 256 "$FINAL_ZIP" > "$SHA_PATH"

echo "Notarized release zip: $FINAL_ZIP"
echo "Checksum: $SHA_PATH"
