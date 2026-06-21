# Dataiku Chirp

Dataiku Chirp is a local-first macOS voice-to-text prototype for Dataiku-style internal use. It keeps the CrispyDough workflow shape: global hotkey, push-to-talk or toggle recording, floating pill, launch at login, auto-paste, and usage/savings estimates.

The major difference is the security model: there is no OpenAI API key, no prompt field, no transcript history, and no network transcription path. Audio is recorded to a temporary local WAV file, passed to a local `whisper.cpp` binary, then deleted.

## Current Status

- Native SwiftUI macOS app.
- Uses local `whisper-cli` with a local Whisper model file.
- Pilot builds can bundle `whisper-cli`, required runtime libraries, and the model inside the app.
- Default target model: `ggml-large-v3-turbo.bin`.
- Stores only aggregate usage metrics.
- Optional global usage dashboard sends cumulative aggregate counters only.
- Ships as a downloadable `.zip` release artifact for testers.
- Builds without network access or third-party Swift dependencies.

## Download For Testers

Go to the repo's [Releases page](https://github.com/olademo1/kiku-dictate/releases), download the latest `DataikuChirp-macOS-*.zip`, unzip it, then drag `Dataiku Chirp.app` into `/Applications`.

For the People team pilot, use an all-in-one release made by `./scripts/build_pilot_release.sh`. That bundled app includes `whisper-cli`, its required libraries, and `ggml-large-v3-turbo.bin`, so testers do not need to install Homebrew, find a CLI binary, or choose a model path.

On first launch:

1. Open `Dataiku Chirp.app`.
2. Allow microphone access.
3. Enable Accessibility only if you want automatic paste into the active app.
4. Press the configured shortcut or the `Record` button.

If macOS blocks the app because it has not been notarized yet, open it from Finder by right-clicking `Dataiku Chirp.app` and choosing `Open`. This prototype is Developer ID signed locally but not yet notarized for broad external distribution.

## Setup

```bash
cd "/Users/rotimilademo/Documents/New project/KikuDictate"
./scripts/install_local_engine.sh
./scripts/build_app.sh
./scripts/install_app.sh
```

To build the all-in-one pilot app:

```bash
./scripts/install_local_engine.sh
./scripts/build_pilot_release.sh
```

The model file is large and is intentionally not committed to git. The helper installs it to:

```text
~/Library/Application Support/DataikuChirp/Models/ggml-large-v3-turbo.bin
```

## Cost And Model Notes

When the model and `whisper-cli` are running locally, transcription has no per-minute API fee. It is not literally cost-free: users still pay with local CPU/GPU time, battery, storage, IT packaging, support, and security review. For an internal rollout, that usually means the marginal transcription cost is effectively zero after the model is distributed.

The in-app `Spend avoided` number is therefore an estimate of vendor transcription spend avoided, not profit or fully loaded ROI. The default estimate uses the avoided API spend assumption in `UsagePricing.swift`, while `Time saved` estimates typing time avoided from aggregate word counts. Dataiku Chirp stores only those aggregate counters, not transcript text.

The default model is `ggml-large-v3-turbo.bin`, which is about 1.62 GB in the upstream `whisper.cpp` model repository. The full `ggml-large-v3.bin` model is about 3.1 GB and may be more accurate in some cases, but it is slower and heavier. Quantized turbo options are smaller, but the default keeps quality higher for a company-wide writing tool.

Future local models can be selected without a code change through `Advanced Runtime`. See [docs/model-management.md](docs/model-management.md).

OpenAI's Whisper code and model weights are released under the MIT License, and `whisper.cpp` is also MIT licensed. Dataiku legal/security should still review the exact artifacts before distribution:

- OpenAI Whisper: https://github.com/openai/whisper
- whisper.cpp: https://github.com/ggml-org/whisper.cpp
- GGML model files: https://huggingface.co/ggerganov/whisper.cpp/tree/main

## Build

```bash
swift build
./scripts/build_app.sh
```

The packaged app is written to:

```text
dist/Dataiku Chirp.app
```

## Security Defaults

- No raw transcript persistence.
- No transcript history UI.
- No API key or cloud provider settings.
- No prompt or instruction text sent to the model.
- No shell interpolation for transcription commands.
- Temporary audio deleted after transcription or failure.
- Usage metrics are aggregate-only: seconds, word count, estimated time saved, estimated vendor cost avoided.
- Team stats send cumulative aggregate counters only. New installs start with sharing on, but setup requires a team selection before anything can sync.

## Global Usage

The `Usage > Team` popover connects to the configured Google Apps Script web app for pilot-wide totals. New installs default to sharing aggregate counters, require the user to choose a broad team before sync, and still let users turn sharing off. Users do not paste an endpoint URL or key.

The recommended design stores one row per laptop and updates that row with cumulative counters, so 1,000 employees remain roughly 1,000 rows instead of a per-dictation event stream.

Use `integrations/google-apps-script/global_usage.gs` and follow [docs/global-usage-google-apps-script.md](docs/global-usage-google-apps-script.md).

## Shortcut Notes

The default shortcut is `Control Space` because `Option Space` conflicts with ChatGPT/OpenAI on many Macs. In Preferences, users can pick another shortcut. The `1-key` toggle allows bare single-key shortcuts, but it is off by default because a global single-key shortcut can intercept normal typing.

See [docs/security-model.md](docs/security-model.md) and [docs/reviewer-checklist.md](docs/reviewer-checklist.md).

## Verification

```bash
./scripts/verify_security.sh
```

The verifier checks that the app builds and that removed cloud/prompt/history surfaces have not reappeared.

## Notes

Before company distribution, confirm the bundle ID, signing identity, deployment path, name approval, and legal review notes.
