# Dataiku Chirp macOS Distribution

This repo is ready to clone on another Mac for a small pilot rollout. GitHub contains the Swift app source, assets, docs, and build scripts. It intentionally does not contain Apple signing credentials, notarization credentials, built app bundles, `whisper-cli`, or the 1.62 GB Whisper model.

For a 7-10 person People team pilot, it is reasonable to sign and notarize with a personal Apple Developer ID if everyone understands this is a prototype. For a company-wide release, rebuild and sign from a Dataiku-owned Apple Developer team so Gatekeeper, ownership, revocation, and future IT management belong to Dataiku.

## Work Mac Setup

```bash
git clone https://github.com/olademo1/kiku-dictate.git
cd kiku-dictate
```

Install Xcode or Xcode Command Line Tools if the machine does not already have them:

```bash
xcode-select --install
```

Install the local runtime:

```bash
./scripts/install_local_engine.sh
```

The runtime helper installs `whisper-cpp` with Homebrew when possible and downloads the default model to:

```text
~/Library/Application Support/DataikuChirp/Models/ggml-large-v3-turbo.bin
```

For a managed company rollout, distribute `whisper-cli` and the model through MDM or an internal package instead of asking every user to download them.

## Build A Self-Contained People Team Pilot

For the first 7-10 person pilot, build an all-in-one app so coworkers do not need to install Homebrew, find `whisper-cli`, or choose a model path.

First install the runtime once on the build Mac:

```bash
./scripts/install_local_engine.sh
```

Then create the bundled release:

```bash
./scripts/build_pilot_release.sh
```

This copies the local `whisper-cli`, required `whisper.cpp` dynamic libraries, and `ggml-large-v3-turbo.bin` into the app bundle:

```text
Dataiku Chirp.app/Contents/Resources/Runtime/bin/whisper-cli
Dataiku Chirp.app/Contents/Resources/Runtime/lib/*.dylib
Dataiku Chirp.app/Contents/Resources/Models/ggml-large-v3-turbo.bin
```

The resulting app bundle is large, roughly model-sized plus app/runtime overhead. For a cleaner tester experience, package the notarized app into a DMG so pilot users download one disk image, drag Dataiku Chirp into Applications, pick their team, and grant microphone/accessibility permissions.

The bundled app uses the architecture of the Mac that built it. A build made on an Apple Silicon Mac with Homebrew in `/opt/homebrew` is typically `arm64`. Confirm the pilot users are on Apple Silicon Macs before sharing one build broadly; Intel Macs need a separate compatible build or a universal runtime.

To notarize the all-in-one build, provide notarization credentials and run:

```bash
DATAIKU_CHIRP_NOTARIZE=1 ./scripts/build_pilot_release.sh
```

## Build And Install Locally

Build with global usage tracking embedded if you are using the Google Apps Script dashboard:

```bash
DATAIKU_CHIRP_USAGE_ENDPOINT="https://script.google.com/macros/s/..." \
DATAIKU_CHIRP_USAGE_TEAM_KEY="shared-secret" \
./scripts/build_app.sh
```

Or build without global usage reporting:

```bash
./scripts/build_app.sh
```

Install and verify the local build:

```bash
./scripts/install_app.sh
./scripts/verify_security.sh
```

## Notarize A Pilot Release

The build script automatically prefers the first available `Developer ID Application` signing identity. If none is available, it may use an Apple Development identity or ad-hoc signing, which is fine for local testing but not for a clean download experience. The notarization script stops early unless the app is signed with Developer ID.

After building with a Developer ID identity available in Keychain, notarize with App Store Connect API key credentials:

```bash
APPLE_NOTARY_KEY_PATH="/path/AuthKey_ABC123DEFG.p8" \
APPLE_NOTARY_KEY_ID="ABC123DEFG" \
APPLE_NOTARY_ISSUER_ID="00000000-0000-0000-0000-000000000000" \
./scripts/notarize_release.sh
```

Or notarize with an Apple ID and app-specific password:

```bash
APPLE_ID="you@example.com" \
APPLE_TEAM_ID="TEAMID1234" \
APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
./scripts/notarize_release.sh
```

The notarization script:

1. Verifies the app signature.
2. Uploads the app zip to Apple notarization.
3. Staples the notarization ticket to the `.app`.
4. Runs a Gatekeeper assessment.
5. Creates a final zip in `releases/`.

To create the drag-to-Applications DMG from a signed/notarized app:

```bash
APPLE_NOTARY_PROFILE=dataiku-chirp-notary DATAIKU_CHIRP_NOTARIZE_DMG=1 \
  ./scripts/package_dmg.sh "dist/Dataiku Chirp.app" "releases/DataikuChirp-macOS.dmg"
```

The DMG script adds the Applications shortcut, arranges the Finder window, signs the disk image, submits it for notarization, staples the ticket, validates it with Gatekeeper, and writes a `.sha256` file.

## Package A Local Release Without Notarization

```bash
./scripts/package_release.sh
```

This creates a zip and checksum from the installed app. Use it only for local/manual testing unless the app has already been notarized.

## Enterprise Notes

- Confirm `BUNDLE_ID` in `scripts/build_app.sh` before production distribution.
- Use a stable signing identity so macOS microphone/accessibility grants remain attached across updates.
- Expect permissions to reset if the pilot is signed by one Apple Developer team and the production app is later signed by a Dataiku Developer ID.
- Keep the model artifact outside git; validate its checksum in the deployment pipeline.
- For broad rollout, prefer a signed `.pkg` via MDM or a notarized `.dmg` with a verified first-run model download.
