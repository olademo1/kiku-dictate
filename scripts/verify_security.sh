#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift build

fail=0

check_absent() {
  local pattern="$1"
  local label="$2"
  shift 2
  if rg -n "$pattern" "$@" >/tmp/kiku-verify-hit.txt 2>/dev/null; then
    echo "FAIL: $label"
    cat /tmp/kiku-verify-hit.txt
    fail=1
  else
    echo "OK: $label"
  fi
}

check_absent "OpenAIClient|APIKeyStore|KeychainService|HistoryStore|TranscriptRecord" "removed cloud/key/history types" Sources Package.swift
check_absent "audio/transcriptions|api\\.openai\\.com|Bearer|OPENAI_API_KEY" "no OpenAI transcription path" Sources Package.swift
check_absent "prompt" "no transcription prompt surface in local transcriber" Sources/KikuDictateApp/Services/LocalWhisperTranscriber.swift

if rg -n "Process\\(|executableURL|arguments" Sources/KikuDictateApp/Services/LocalWhisperTranscriber.swift >/tmp/kiku-process-hit.txt; then
  echo "OK: local process invocation is explicit"
else
  echo "FAIL: local process invocation not found"
  fail=1
fi

if rg -n "removeItem\\(at: outcome.url\\)|removeItem\\(at: outputText\\)" Sources/KikuDictateApp >/tmp/kiku-delete-hit.txt; then
  echo "OK: temp deletion paths present"
else
  echo "FAIL: temp deletion paths not found"
  fail=1
fi

rm -f /tmp/kiku-verify-hit.txt /tmp/kiku-process-hit.txt /tmp/kiku-delete-hit.txt
exit "$fail"
