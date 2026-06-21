# Kiku Dictate

Kiku Dictate is a local-first macOS voice-to-text prototype for Dataiku-style internal use. It keeps the CrispyDough workflow shape: global hotkey, push-to-talk or toggle recording, floating pill, launch at login, auto-paste, and usage/savings estimates.

The major difference is the security model: there is no OpenAI API key, no prompt field, no transcript history, and no network transcription path. Audio is recorded to a temporary local WAV file, passed to a local `whisper.cpp` binary, then deleted.

## Current Status

- Native SwiftUI macOS app.
- Uses local `whisper-cli` with a local Whisper model file.
- Default target model: `ggml-large-v3-turbo.bin`.
- Stores only aggregate usage metrics.
- Builds without network access or third-party Swift dependencies.

## Setup

```bash
cd "/Users/rotimilademo/Documents/New project/KikuDictate"
./scripts/install_local_engine.sh
./scripts/build_app.sh
./scripts/install_app.sh
```

The model file is large and is intentionally not committed to git. The helper installs it to:

```text
~/Library/Application Support/KikuDictate/Models/ggml-large-v3-turbo.bin
```

## Cost And Model Notes

When the model and `whisper-cli` are running locally, transcription has no per-minute API fee. It is not literally cost-free: users still pay with local CPU/GPU time, battery, storage, IT packaging, support, and security review. For an internal rollout, that usually means the marginal transcription cost is effectively zero after the model is distributed.

The default model is `ggml-large-v3-turbo.bin`, which is about 1.62 GB in the upstream `whisper.cpp` model repository. The full `ggml-large-v3.bin` model is about 3.1 GB and may be more accurate in some cases, but it is slower and heavier. Quantized turbo options are smaller, but the default keeps quality higher for a company-wide writing tool.

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
dist/Kiku Dictate.app
```

## Security Defaults

- No raw transcript persistence.
- No transcript history UI.
- No API key or cloud provider settings.
- No prompt or instruction text sent to the model.
- No shell interpolation for transcription commands.
- Temporary audio deleted after transcription or failure.
- Usage metrics are aggregate-only: seconds, word count, estimated time saved, estimated vendor cost avoided.

See [docs/security-model.md](docs/security-model.md) and [docs/reviewer-checklist.md](docs/reviewer-checklist.md).

## Verification

```bash
./scripts/verify_security.sh
```

The verifier checks that the app builds and that removed cloud/prompt/history surfaces have not reappeared.

## Notes

This is an internal prototype name and not an official Dataiku product name. Before company distribution, update the bundle ID, signing identity, deployment path, and legal review notes.
