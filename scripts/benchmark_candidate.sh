#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH="$ROOT/.bench"
CANDIDATES="$ROOT/experiments/candidates.tsv"
CANDIDATE_ID="${1:-}"
RUN_ACCURACY="${RUN_ACCURACY:-0}"

if [[ -z "$CANDIDATE_ID" ]]; then
  echo "usage: RUN_ACCURACY=0|1 bash scripts/benchmark_candidate.sh <candidate-id>" >&2
  echo "candidates:" >&2
  tail -n +2 "$CANDIDATES" | cut -f1 >&2
  exit 2
fi

if [[ -f "$BENCH/env.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BENCH/env.sh"
fi

for cmd in curl python adtc-profiler llama-bench; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: '$cmd' not found. Run: bash scripts/setup_benchmark.sh" >&2
    exit 2
  fi
done

LINE="$(awk -F '\t' -v id="$CANDIDATE_ID" 'NR > 1 && $1 == id {print; exit}' "$CANDIDATES")"
if [[ -z "$LINE" ]]; then
  echo "error: unknown candidate '$CANDIDATE_ID'" >&2
  tail -n +2 "$CANDIDATES" | cut -f1 >&2
  exit 2
fi

IFS=$'\t' read -r ID HF_REPO FILENAME PARAMS QUANT LICENSE EXPECTED_GB <<< "$LINE"
MODEL_DIR="$BENCH/models/$ID"
MODEL_PATH="$MODEL_DIR/$FILENAME"
RESULT_DIR="$BENCH/results/$ID"
SUBMISSION_DIR="$BENCH/submissions/$ID"
MODEL_URL="https://huggingface.co/$HF_REPO/resolve/main/$FILENAME?download=true"

mkdir -p "$MODEL_DIR" "$RESULT_DIR"

if [[ ! -f "$MODEL_PATH" ]]; then
  echo "==> downloading $ID ($EXPECTED_GB GB expected)"
  curl -L --fail --retry 4 --retry-delay 3 --continue-at - \
    -o "$MODEL_PATH.partial" "$MODEL_URL"
  mv "$MODEL_PATH.partial" "$MODEL_PATH"
else
  echo "==> model already cached: $MODEL_PATH"
fi

rm -rf "$SUBMISSION_DIR"
mkdir -p "$SUBMISSION_DIR/model"
ln -s "$MODEL_PATH" "$SUBMISSION_DIR/model/model.gguf"

cat > "$SUBMISSION_DIR/metadata.json" <<EOF
{
  "team_id": "local-benchmark",
  "domain": "coding_assistants",
  "language_scope": ["en"],
  "african_alpha_claim": false,
  "budget_laptop_claim": true,
  "submitter": {
    "name": "Local Benchmark",
    "email": "local@benchmark.invalid",
    "github_handle": "ShalyX"
  },
  "cross_disciplinary_pairing": {
    "discipline": "benchmarking",
    "load_bearing": true,
    "description": "Temporary local harness used only for candidate comparison."
  },
  "test_prompts": [
    {"prompt_id": "bench_001", "prompt": "Explain why a Python dictionary lookup is usually O(1) average time."},
    {"prompt_id": "bench_002", "prompt": "Write a Python function that returns the median of a numeric list."}
  ],
  "model": {
    "name": "$ID",
    "runtime": "llama.cpp",
    "quantization": "GGUF $QUANT",
    "parameters_estimate": "$PARAMS",
    "packaging": "binary_bundle"
  },
  "_runtime": {
    "model_path": "model/model.gguf"
  }
}
EOF

RUNNER=()
if command -v taskset >/dev/null 2>&1 && [[ "$(nproc)" -ge 4 ]]; then
  # Approximate the audit's 4-vCPU cap even when developing on a larger machine.
  RUNNER=(taskset -c 0-3)
fi

FAST_OUT="$RESULT_DIR/perf.json"
echo "==> profiler performance run (CPU-only; 4-core affinity when available)"
"${RUNNER[@]}" adtc-profiler run \
  --submission "$SUBMISSION_DIR" \
  --mode participant \
  --output "$FAST_OUT" \
  --skip-accuracy

FULL_OUT=""
if [[ "$RUN_ACCURACY" == "1" ]]; then
  FULL_OUT="$RESULT_DIR/full.json"
  echo "==> profiler full run with ARC-Easy smoke accuracy"
  "${RUNNER[@]}" adtc-profiler run \
    --submission "$SUBMISSION_DIR" \
    --mode participant \
    --output "$FULL_OUT"
fi

python - "$FAST_OUT" "$FULL_OUT" "$ID" "$LICENSE" "$EXPECTED_GB" <<'PY'
import json
import sys
from pathlib import Path

fast_path, full_path, model_id, license_name, expected_gb = sys.argv[1:]
fast = json.loads(Path(fast_path).read_text())
source = fast
if full_path:
    source = json.loads(Path(full_path).read_text())

t = fast["throughput"]
m = fast["memory"]
acc = source.get("accuracy") or []
print("\n=== CANDIDATE RESULT ===")
print(f"model:             {model_id}")
print(f"license:           {license_name}")
print(f"GGUF size (listed): {expected_gb} GB")
print(f"generation:        {t['tokens_per_second_generation']} tok/s")
print(f"TTFT:              {t['first_token_latency_ms']} ms")
print(f"peak RSS:          {m['peak_rss_mb']} MB")
print(f"steady RSS:        {m['steady_state_rss_mb']} MB")
if acc:
    row = acc[0]
    print(f"{row['benchmark']}:          {row['score']} ({row['samples']} samples, {row['metric']})")
else:
    print("accuracy:          skipped")
print(f"result directory:  {Path(fast_path).parent}")
PY
