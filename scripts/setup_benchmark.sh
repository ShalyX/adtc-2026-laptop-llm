#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH="$ROOT/.bench"
LLAMA_CPP="$BENCH/llama.cpp"
VENV="$BENCH/venv"
BUILD_JOBS="${ADTC_BUILD_JOBS:-2}"

mkdir -p "$BENCH"

if command -v apt-get >/dev/null 2>&1; then
  SUDO=""
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    SUDO="sudo"
  fi

  # Ubuntu/WSL may start unattended-upgrades in the background. Never delete
  # dpkg lock files; wait briefly for the package manager to become available.
  if command -v fuser >/dev/null 2>&1; then
    echo "checking apt/dpkg availability…"
    for _ in $(seq 1 60); do
      if ! $SUDO fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && \
         ! $SUDO fuser /var/lib/dpkg/lock >/dev/null 2>&1; then
        break
      fi
      sleep 2
    done
    if $SUDO fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
       $SUDO fuser /var/lib/dpkg/lock >/dev/null 2>&1; then
      echo "error: apt/dpkg is still busy (often unattended-upgrades)." >&2
      echo "Wait for it to finish, then rerun this script. Do not delete lock files." >&2
      exit 1
    fi
  fi

  # Repair any package configuration left incomplete by an interrupted apt run.
  $SUDO dpkg --configure -a
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

# Keep build parallelism deliberately low. An unrestricted `-j` can make WSL
# launch enough C++ compiler processes to exhaust RAM and get cc1plus OOM-killed.
echo "building llama.cpp with $BUILD_JOBS parallel job(s)…"
cmake --build "$LLAMA_CPP/build" --config Release --parallel "$BUILD_JOBS" \
  --target llama-bench llama-cli

cat > "$BENCH/env.sh" <<EOF
export ADTC_REPO="$ROOT"
export ADTC_BENCH="$BENCH"
export PATH="$VENV/bin:$LLAMA_CPP/build/bin:\$PATH"
EOF

printf '\nSetup complete.\n\nRun:\n  source .bench/env.sh\n  adtc-profiler --help\n  llama-bench --help | head\n\n'
