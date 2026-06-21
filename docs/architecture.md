# Architecture

```text
Dataiku Chirp.app
  SwiftUI settings window
  AppKit floating pill
  Carbon global hotkey monitor
  AVAudioRecorder local WAV capture
  LocalWhisperTranscriber
    -> fixed executable path: whisper-cli
    -> fixed model path: ggml-large-v3-turbo.bin
    -> fixed argument list, no shell
  PasteInjector
    -> clipboard write
    -> Cmd+V event when Accessibility is enabled
  UsageStore
    -> aggregate JSON metrics only
  GlobalUsageClient (optional)
    -> cumulative aggregate counters only
    -> no transcript text or audio
```

## Data Flow

1. User presses the configured hotkey.
2. The app records microphone audio to a temporary 16 kHz mono WAV file.
3. The app invokes `whisper-cli` directly through `Process`.
4. `whisper-cli` writes a temporary text output file.
5. The app trims the result, counts words, and pastes/copies it.
6. The app deletes temporary audio and temporary transcript files.
7. The app stores only usage counters.
8. If team stats sharing is enabled, the app periodically posts cumulative aggregate counters for this install.

## Trust Boundary

The app trusts:

- macOS microphone and accessibility permissions.
- The local `whisper-cli` binary chosen in settings.
- The local model file chosen in settings.

The app does not trust or call:

- OpenAI API.
- Browser APIs.
- Remote transcription services.
- Prompt-based correction services.

The optional global usage endpoint is outside the transcription trust boundary. In configured team-usage builds, sharing defaults on but cannot sync until a team is selected, and users can turn it off. It receives cumulative counters only.
