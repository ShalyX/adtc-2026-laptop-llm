#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_DIR="$HERE/model"
MODEL_FILE="$MODEL_DIR/Qwen3-1.7B-Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/ggml-org/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf?download=true"

mkdir -p "$MODEL_DIR"

if [[ -f "$MODEL_FILE" ]]; then
  echo "model already present at $MODEL_FILE — skipping download"
  exit 0
fi

echo "downloading Qwen3-1.7B Q4_K_M → $MODEL_FILE (~1.28 GB)…"

if command -v curl >/dev/null 2>&1; then
  curl -L --fail --retry 4 --retry-delay 3 --continue-at - \
    -o "$MODEL_FILE.partial" "$MODEL_URL"
elif command -v wget >/dev/null 2>&1; then
  wget --show-progress -c -O "$MODEL_FILE.partial" "$MODEL_URL"
else
  echo "error: neither curl nor wget found" >&2
  exit 1
fi

mv "$MODEL_FILE.partial" "$MODEL_FILE"
echo "done: $MODEL_FILE"
