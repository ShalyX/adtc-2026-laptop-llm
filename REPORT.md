# Technical Report — FieldLite 1.7B

**Team ID:** ShalyX  
**Domain:** agriculture  
**Model:** Qwen3-1.7B-Q4_K_M  
**Runtime:** llama.cpp / GGUF  

## Problem

FieldLite is an offline agricultural assistant intended for smallholder farmers, field staff, and extension workers who may have access to a commodity laptop but not dependable broadband, cloud API budgets, or continuous power.

The submission focuses on the model layer rather than a cloud-backed application. During evaluation the model runs entirely locally through `llama.cpp`. The two submitted prompts test practical agricultural reasoning: diagnosing ambiguous maize symptoms and reducing post-harvest maize losses under limited infrastructure.

This is an African-use-case submission because intermittent connectivity, expensive cloud inference, and the continued importance of smallholder agriculture make useful local inference materially valuable. The submission does **not** claim that the base model has been agronomically fine-tuned, clinically validated, or trained on a proprietary African agricultural dataset. It is an engineering selection and deployment of an existing open model under the ADTC laptop constraint.

## Design Decisions

### Base model

The locked model is **Qwen3-1.7B**. The selection was empirical rather than parameter-count driven. Candidate GGUFs were run through the official ADTC profiler in participant mode with CPU-only inference and four-core affinity where available.

### Quantization

The final quantization is **Q4_K_M**. It provided the strongest measured quality/efficiency balance among the Qwen3 variants tested.

A 1.7B Q3_K_M build was smaller but was rejected because it was both slower in our run and substantially worse on the profiler's ARC-Easy smoke evaluation. A 0.6B model was much faster and smaller, but its measured ARC-Easy result was materially below the selected 1.7B Q4_K_M model.

### Candidate bake-off

| Candidate | Quant | Generation | TTFT | Peak RSS | ARC-Easy smoke |
|---|---|---:|---:|---:|---:|
| Qwen3-0.6B | Q4_K_M | 14.61 tok/s | 13.76 s | 834 MB | 0.60 |
| Qwen3-0.6B | Q6_K | 11.51 tok/s | 14.57 s | 763 MB | 0.64 |
| Qwen3-1.7B | Q3_K_M | 5.71 tok/s | 31.34 s | 1,495 MB | 0.50 |
| **Qwen3-1.7B** | **Q4_K_M** | **7.65 tok/s** | **28.70 s** | **2,055 MB** | **0.76** |

The ARC-Easy figures above are **50-sample local smoke measurements**, not official competition accuracy scores. They were used only as a controlled signal for candidate selection.

A separate performance-only run of Qwen3-0.6B Q4_K_M measured 19.73 tok/s and 8.12 s TTFT, while an earlier performance-only Qwen3-1.7B Q4_K_M run measured 6.34 tok/s and 21.26 s TTFT. This run-to-run variation is why the report does not present local throughput as an official score.

### Why the 1.7B Q4 model won

The 0.6B family established the speed and memory frontier, but the selected 1.7B Q4_K_M model improved the controlled ARC-Easy smoke result from 0.60 to 0.76 while remaining far below the 8 GB memory ceiling. Q3_K_M on the same 1.7B base was dominated in our measurement: lower quality and lower throughput despite reduced memory use.

The final choice therefore prioritizes response quality while preserving a large memory safety margin for the standard laptop profile.

## Constraints

- **Target profile:** 4 vCPU, 8 GB RAM, integrated graphics / CPU inference.
- **Runtime:** `llama.cpp` only.
- **Weights:** GGUF Q4_K_M, downloaded publicly before evaluation.
- **Inference networking:** none. The model is designed to run 100% offline after download.
- **Development environment:** Ubuntu 22.04 (`jammy`) under WSL2; the local benchmark harness used four-core CPU affinity when available to approximate the audit CPU limit.
- **Memory:** selected model peaked at about 2.06 GB RSS in the reported local profiler run, leaving substantial headroom below the competition ceiling.
- **Thermals:** no thermal claim is made from the abbreviated local result summaries; the official audit remains authoritative.
- **Training/fine-tuning:** none is claimed in this Gate 1 submission.

## Agricultural Use Case

The model is framed as a field-side reasoning assistant rather than an authority. Prompts are designed to encourage uncertainty, observable checks, low-cost steps, and escalation to local agronomic expertise where appropriate.

The intended interaction pattern is:

1. describe a field or post-harvest problem in plain English;
2. receive plausible explanations or a practical plan;
3. distinguish possibilities using observations the user can make locally;
4. avoid dependence on a cloud connection for the inference step.

The submitted prompts deliberately cover two different agricultural tasks—diagnostic reasoning and post-harvest planning—to reduce prompt over-specialization.

## Reproducibility

The repository contains an idempotent `download_model.sh` which downloads the public Qwen3-1.7B Q4_K_M GGUF into the exact path declared in `metadata.json`.

After download, the intended audit path is:

```bash
adtc-profiler run \
  --submission . \
  --mode participant \
  --output submission.json
```

No model weight is committed to Git. Inference is performed locally through `llama.cpp` and does not require external API calls.

## Limitations

- The model is a compact general-purpose base model, not a substitute for a local agronomist.
- No claim is made that every agricultural answer is correct; the hidden organizer prompts and technical audit are the authoritative evaluation.
- No African-language bonus is claimed through `language_scope`; the current submission declares English only.
- The local benchmark environment is not identical to the organizers' standard laptop, so all performance figures in this report are development measurements rather than official scores.
