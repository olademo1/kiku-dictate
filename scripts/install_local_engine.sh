#!/usr/bin/env bash
set -euo pipefail

MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"
MODEL_DIR="$HOME/Library/Application Support/KikuDictate/Models"
MODEL_PATH="$MODEL_DIR/ggml-large-v3-turbo.bin"
INSTALL_OK=1

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew was not found. Install whisper-cpp manually, then set the engine path in Kiku Dictate."
  INSTALL_OK=0
elif ! command -v whisper-cli >/dev/null 2>&1; then
  echo "Installing whisper-cpp with Homebrew..."
  if ! HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}" brew install whisper-cpp; then
    echo "WARNING: Homebrew could not install whisper-cpp."
    echo "You can still use Kiku Dictate after installing whisper-cli through MDM or another trusted channel."
    INSTALL_OK=0
  fi
fi

mkdir -p "$MODEL_DIR"

if [[ -f "$MODEL_PATH" ]]; then
  echo "Model already exists: $MODEL_PATH"
else
  echo "Downloading model..."
  if ! curl -L --fail "$MODEL_URL" -o "$MODEL_PATH"; then
    rm -f "$MODEL_PATH"
    echo "WARNING: model download failed."
    echo "Download this file through a trusted channel and place it at: $MODEL_PATH"
    INSTALL_OK=0
  fi
fi

echo "Engine: $(command -v whisper-cli || true)"
echo "Model: $MODEL_PATH"

if [[ "$INSTALL_OK" -ne 1 ]]; then
  exit 1
fi
