# Dataiku Chirp macOS Distribution

This prototype builds an ad-hoc signed app when no Apple signing identity is available. For distribution across a company, use a managed Developer ID Application certificate and notarize the zip.

## Build And Install Locally

```bash
cd "/Users/rotimilademo/Documents/New project/KikuDictate"
./scripts/build_app.sh
./scripts/install_app.sh
```

## Package A Local Release

```bash
./scripts/package_release.sh
```

## Enterprise Notes

- Confirm `BUNDLE_ID` in `scripts/build_app.sh` before production distribution.
- Use a stable signing identity so macOS microphone/accessibility grants remain attached across updates.
- Distribute `whisper-cli` and the model with MDM when possible.
- Keep the model artifact outside git; validate its checksum in the deployment pipeline.
