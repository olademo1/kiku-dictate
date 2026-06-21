# Model Management

Dataiku Chirp keeps model selection simple:

- `Engine` is the local transcription binary, usually `whisper-cli`.
- `Model` is the local model file path.
- `Name` is the label shown in the dashboard and global usage payload.

Open `Advanced Runtime` to change any of those values. This makes future model upgrades a configuration change as long as the new model works with the selected local engine.

## Default

Fresh installs use:

```text
~/Library/Application Support/DataikuChirp/Models/ggml-large-v3-turbo.bin
```

Renamed installs can reuse the old local model at:

```text
~/Library/Application Support/KikuDictate/Models/ggml-large-v3-turbo.bin
```

## Upgrade Flow

1. Distribute the new model file through MDM, an internal package, or another approved channel.
2. Open `Advanced Runtime`.
3. Update `Model` to the new local file path.
4. Update `Name` to the new display name.
5. Press `Save` for each changed field.
6. Record a short test phrase.

The app does not download or call a transcription API at runtime. The model file and engine binary are local files chosen in Advanced Runtime.
