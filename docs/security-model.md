# Security Model

Dataiku Chirp is designed to reduce the amount of sensitive data that exists.

## Stored Data

Stored:

- Hotkey settings.
- Launch/floating pill settings.
- Local engine/model file paths.
- Aggregate usage records.
- Optional global usage settings.

Not stored:

- Raw audio.
- Transcript text.
- Prompt text.
- Active window titles.
- Clipboard history.
- API keys.
- Per-dictation event logs.

## Prompt Injection Position

The app does not expose a prompt field and does not send instructions to a language model. The transcription command receives only:

- model path
- audio path
- language code
- output path
- fixed flags

That makes prompt injection a poor fit for this system: spoken content can affect the transcript text, but it cannot alter app behavior, model instructions, network destinations, file paths, or command arguments.

## Command Execution

Transcription uses `Process.executableURL` and an argument array. It does not build a shell string.

## Network

The app has no network transcription path. The install helper downloads the model once, outside app runtime, and can be omitted if IT distributes the model through MDM.

Global usage sharing is optional and off by default. When enabled, it sends cumulative aggregate counters only:

- installation ID
- app version
- model name
- sessions
- total words
- total local transcription minutes
- estimated time saved
- estimated vendor spend avoided

It does not send audio, transcript text, clipboard contents, active app names, or active window titles.

## Residual Risks

- Clipboard content briefly contains the generated transcript so the app can paste.
- Accessibility permission allows the app to synthesize Cmd+V events.
- The selected `whisper-cli` binary and model file must be trusted.
- A pilot Apps Script team key is a shared secret, not full enterprise identity.
- The local machine can still be compromised by unrelated malware.
