# Candidate Bake-off

Do not choose the product/domain before this pass. Gate 1 scoring is model-first: quality, CPU throughput, and RAM efficiency on constrained hardware.

## Initial candidates

| ID | Model | Q4_K_M size | Role |
|---|---|---:|---|
| `qwen3-1.7b-q4km` | Qwen3 1.7B | ~1.28 GB | speed / efficiency floor |
| `smollm3-3b-q4km` | SmolLM3 3B | ~1.92 GB | compact reasoning candidate |
| `qwen3-4b-q4km` | Qwen3 4B | ~2.50 GB | quality ceiling under laptop budget |
| `tiny-aya-earth-3.35b-q4km` | Tiny Aya Earth 3.35B | ~2.14 GB | African-language specialist |

The first three are Apache-2.0. Tiny Aya Earth is CC-BY-NC-4.0; keep that restriction visible in the final decision.

## 1. Set up the benchmark environment

Run on Ubuntu/Debian or WSL2 Ubuntu from the repository root:

```bash
bash scripts/setup_benchmark.sh
source .bench/env.sh
```

This installs an isolated Python 3.11 profiler environment and builds CPU-native `llama.cpp` binaries. `.bench/` is gitignored.

## 2. Performance sweep

Run all four with accuracy disabled first:

```bash
bash scripts/benchmark_candidate.sh qwen3-1.7b-q4km
bash scripts/benchmark_candidate.sh smollm3-3b-q4km
bash scripts/benchmark_candidate.sh qwen3-4b-q4km
bash scripts/benchmark_candidate.sh tiny-aya-earth-3.35b-q4km
```

The runner applies 4-core CPU affinity when Linux exposes at least four cores, matching the audit CPU cap more closely than an unrestricted development run.

Record:

- generation tokens/sec
- time to first token
- peak RSS
- steady-state RSS
- stability / crashes
- thermals reported by the profiler

## 3. Accuracy smoke test

Run ARC-Easy on candidates that survive the performance sweep. If time permits, run it on all four:

```bash
RUN_ACCURACY=1 bash scripts/benchmark_candidate.sh qwen3-1.7b-q4km
RUN_ACCURACY=1 bash scripts/benchmark_candidate.sh smollm3-3b-q4km
RUN_ACCURACY=1 bash scripts/benchmark_candidate.sh qwen3-4b-q4km
RUN_ACCURACY=1 bash scripts/benchmark_candidate.sh tiny-aya-earth-3.35b-q4km
```

Do **not** optimize directly for the 50-question ARC sample. It is only a regression/general-capability signal; final accuracy also includes hidden/domain prompts and qualitative judging.

## Decision gate

A candidate is immediately rejected if it is unstable or approaches the 7 GB RSS ceiling. Among stable candidates, choose from the Pareto frontier rather than maximizing a single local score:

1. response quality / ARC regression signal
2. generation throughput
3. peak RAM
4. African-language quality where relevant
5. license / downstream usability

After choosing the base architecture, run the second-stage quantization bake-off (Q4_K_M vs Q5_K_M and, only if justified, Q6_K) and then decide whether a narrowly targeted LoRA/SFT improves the actual domain without degrading general capability.

## Results location

Local outputs are written under:

```text
.bench/results/<candidate-id>/perf.json
.bench/results/<candidate-id>/full.json
```

These files remain local until reviewed; do not commit machine-specific benchmark claims blindly.
