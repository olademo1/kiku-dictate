# Security Model

Kiku Dictate is designed to reduce the amount of sensitive data that exists.

## Stored Data

Stored:

- Hotkey settings.
- Launch/floating pill settings.
- Local engine/model file paths.
- Aggregate usage records.

Not stored:

- Raw audio.
- Transcript text.
- Prompt text.
- Active window titles.
- Clipboard history.
- API keys.

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

The app itself has no network transcription path. The install helper downloads the model once, outside app runtime, and can be omitted if IT distributes the model through MDM.

## Residual Risks

- Clipboard content briefly contains the generated transcript so the app can paste.
- Accessibility permission allows the app to synthesize Cmd+V events.
- The selected `whisper-cli` binary and model file must be trusted.
- The local machine can still be compromised by unrelated malware.

