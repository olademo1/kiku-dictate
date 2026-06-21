#!/usr/bin/env bash
set -euo pipefail

MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"
MODEL_DIR="$HOME/Library/Application Support/DataikuChirp/Models"
MODEL_PATH="$MODEL_DIR/ggml-large-v3-turbo.bin"
LEGACY_MODEL_PATH="$HOME/Library/Application Support/KikuDictate/Models/ggml-large-v3-turbo.bin"
INSTALL_OK=1

detect_active_ipv4() {
  local iface
  iface="$(route get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
  if [[ -n "$iface" ]]; then
    ipconfig getifaddr "$iface" 2>/dev/null || true
  fi
}

download_with_network_fallback() {
  local url="$1"
  local output="$2"
  local active_ipv4

  if curl -L --fail "$url" -o "$output"; then
    return 0
  fi

  active_ipv4="$(detect_active_ipv4)"
  if [[ -n "$active_ipv4" ]]; then
    echo "Retrying download bound to active IPv4 address: $active_ipv4"
    curl --interface "$active_ipv4" -L --fail "$url" -o "$output"
    return $?
  fi

  return 1
}

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew was not found. Install whisper-cpp manually, then set the engine path in Dataiku Chirp."
  INSTALL_OK=0
elif ! command -v whisper-cli >/dev/null 2>&1; then
  echo "Installing whisper-cpp with Homebrew..."
  if ! HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}" brew install whisper-cpp; then
    echo "WARNING: Homebrew could not install whisper-cpp."
    echo "You can still use Dataiku Chirp after installing whisper-cli through MDM or another trusted channel."
    INSTALL_OK=0
  fi
fi

mkdir -p "$MODEL_DIR"

if [[ -f "$MODEL_PATH" ]]; then
  echo "Model already exists: $MODEL_PATH"
elif [[ -f "$LEGACY_MODEL_PATH" ]]; then
  MODEL_PATH="$LEGACY_MODEL_PATH"
  echo "Existing model found: $MODEL_PATH"
  echo "Dataiku Chirp will reuse this local model; no download needed."
else
  echo "Downloading model..."
  if ! download_with_network_fallback "$MODEL_URL" "$MODEL_PATH"; then
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
