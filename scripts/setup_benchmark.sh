#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH="$ROOT/.bench"
LLAMA_CPP="$BENCH/llama.cpp"
VENV="$BENCH/venv"

mkdir -p "$BENCH"

if command -v apt-get >/dev/null 2>&1; then
  SUDO=""
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    SUDO="sudo"
  fi
  $SUDO apt-get update
  $SUDO apt-get install -y build-essential cmake git curl ca-certificates
else
  echo "error: this setup script currently targets Ubuntu/Debian (including WSL2)." >&2
  echo "Install git, curl, cmake, a C/C++ toolchain, Python 3.11+, and llama.cpp manually." >&2
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "error: uv installation completed but uv is not on PATH" >&2
  exit 1
fi

uv python install 3.11
if [[ ! -x "$VENV/bin/python" ]]; then
  uv venv "$VENV" --python 3.11
fi
uv pip install --python "$VENV/bin/python" --upgrade \
  "git+https://github.com/Africa-Deep-Tech-Foundation/adtc-profiler.git"

if [[ ! -d "$LLAMA_CPP/.git" ]]; then
  git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$LLAMA_CPP"
else
  git -C "$LLAMA_CPP" pull --ff-only
fi

cmake -S "$LLAMA_CPP" -B "$LLAMA_CPP/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_NATIVE=ON \
  -DLLAMA_CURL=OFF
cmake --build "$LLAMA_CPP/build" --config Release -j --target llama-bench llama-cli

cat > "$BENCH/env.sh" <<EOF
export ADTC_REPO="$ROOT"
export ADTC_BENCH="$BENCH"
export PATH="$VENV/bin:$LLAMA_CPP/build/bin:\$PATH"
EOF

printf '\nSetup complete.\n\nRun:\n  source .bench/env.sh\n  adtc-profiler --help\n  llama-bench --help | head\n\n'
