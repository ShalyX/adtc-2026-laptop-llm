# FieldLite 1.7B — ADTC 2026 Laptop LLM

**Offline agricultural reasoning on commodity laptops.**

FieldLite is a Gate 1 submission for the **Africa Deep Tech Challenge 2026 — Laptop LLM Challenge**. It uses **Qwen3-1.7B Q4_K_M** through `llama.cpp`, selected by an empirical local bake-off for response quality, throughput, and memory use under a four-core CPU constraint.

## Why this model

The goal was not simply to choose the smallest GGUF. We compared multiple Qwen3 sizes and quantizations with the official ADTC profiler.

| Candidate | Generation | Peak RSS | ARC-Easy smoke |
|---|---:|---:|---:|
| Qwen3-0.6B Q4_K_M | 14.61 tok/s | 834 MB | 0.60 |
| Qwen3-0.6B Q6_K | 11.51 tok/s | 763 MB | 0.64 |
| Qwen3-1.7B Q3_K_M | 5.71 tok/s | 1,495 MB | 0.50 |
| **Qwen3-1.7B Q4_K_M** | **7.65 tok/s** | **2,055 MB** | **0.76** |

The ARC-Easy result is a 50-sample development smoke test, not an official competition score. See [`REPORT.md`](REPORT.md) for methodology, run-to-run variation, constraints, and limitations.

## African use case

FieldLite is framed as an **offline field-side assistant for smallholder agriculture and extension work** where connectivity, cloud API cost, or continuous power can be limiting.

The submission is English-only at Gate 1. It does **not** claim agricultural fine-tuning, proprietary training data, or validated professional advice. The engineering contribution is the measured selection and deployment of a compact open model that stays comfortably inside the ADTC laptop memory budget while preserving materially stronger reasoning than the smaller candidates we tested.

## Reproduce

### 1. Download the public GGUF

```bash
bash download_model.sh
```

This downloads:

`model/Qwen3-1.7B-Q4_K_M.gguf`

Model weights are intentionally excluded from Git.

### 2. Install the official profiler

```bash
python3 -m pip install "git+https://github.com/Africa-Deep-Tech-Foundation/adtc-profiler.git"
```

Make sure `llama-bench` from `llama.cpp` is available on `PATH`.

### 3. Profile the submission

```bash
adtc-profiler run \
  --submission . \
  --mode participant \
  --output submission.json
```

Inference is local through `llama.cpp`; no external API is required during inference.

## Submission files

- [`metadata.json`](metadata.json) — domain, model, claims, and exactly two agricultural test prompts.
- [`download_model.sh`](download_model.sh) — idempotent public GGUF downloader.
- [`REPORT.md`](REPORT.md) — problem, design decisions, benchmark evidence, constraints, and limitations.
- [`experiments/`](experiments/) — candidate registry and benchmark notes.
- [`scripts/`](scripts/) — local benchmark setup and candidate runner used during development.

## Selected model

- **Base:** Qwen3-1.7B
- **Quantization:** GGUF Q4_K_M
- **Runtime:** llama.cpp
- **Packaging:** binary bundle
- **Declared language scope:** English
- **Domain:** Agriculture
- **Budget-laptop claim:** Yes
- **African-use-case claim:** Yes

## License and upstream model

This repository retains the template's GPL-3.0 license. The selected Qwen3 model is Apache-2.0 licensed and is downloaded from the public `ggml-org/Qwen3-1.7B-GGUF` repository on Hugging Face.
