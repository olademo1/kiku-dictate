# Reviewer Checklist

Use this checklist for a security or platform review.

- Confirm there are no OpenAI/API-key code paths.
- Confirm there is no transcript history persistence.
- Confirm `LocalWhisperTranscriber` does not call a shell.
- Confirm temp audio and temp text files are deleted.
- Confirm usage logs contain only aggregate counters.
- Confirm microphone permission is required before recording.
- Confirm Accessibility is used only for paste and is optional.
- Confirm app runtime does not download models or call network services.
- Confirm the distributed `whisper-cli` and model artifact are approved.
- Confirm model and engine paths are centrally configurable for managed deployment.

