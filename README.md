# RSD Memory-Dependence Predictor: Hardware Cost Study (Fork)

**Does FPGA hardware cost scale with a predictor's storage-bit budget, or does what the bits are used for dominate real cost?**

This fork extends [RSD](https://github.com/rsd-devel/rsd) (Mashimo et al., FPT/ICFPT 2019) — an open-source, FPGA-optimized out-of-order RISC-V core — with a controlled, multi-axis synthesis study of memory-dependence predictor design, on a Xilinx Zynq-7000 target (real Vivado synthesis, not simulation-only area models).

## TL;DR

Widening a predictor entry's counter or adding a tag both trigger a **one-time jump** from cheap distributed RAM to dedicated Block RAM once total entry width hits 2 bits — after which more width is nearly free. Adding context/history sensitivity **never triggers this jump**, because it perturbs the lookup index instead of widening the stored entry. Combining two refinements is **not additive** — once one has already paid the storage-primitive cost, the second rides along nearly free.

## Key results

| Axis | What varied | Finding |
|---|---|---|
| **Counter width** | 1→4 bits | Sharp BRAM crossover at 2 bits, then flat through 4 |
| **Table capacity** | 32→1024 entries | Scales smoothly, never crosses into BRAM |
| **Tag bits** | 0→7 bits (8 is architecturally impossible on this SoC) | Same BRAM crossover as counter, plus a separate, non-monotonic comparator-cost curve |
| **Context/history bits** | 0→4 bits | Never crosses into BRAM at any width — cheapest of all three mechanisms |
| **Combined (tag+context)** | Both together | Non-additive: only +4 LUT over tag alone, far less than context's standalone +7 |

Full data tables, methodology, and a plain-language walkthrough: [`docs/results.md`](docs/results.md) · [`docs/explainer.md`](docs/explainer.md)

## Repo structure

| Branch (default: `mdp-hardware-cost-study`) | Contents |
|---|---|
| `mdp-hardware-cost-study` | Counter-width sweep (1/2/3/4-bit saturating counter) |
| `axis-a-capacity` | Table-capacity sweep (32/64/128/256/1024 entries) |
| `axis-b-tag-bits` | Tag-bit sweep (0 through 7 bits, max supported) |
| `axis-c-context-bits` | Gshare-style context/history indexing sweep |
| `axis-combined` | Tag + context combined |

Each milestone is tagged: `v0-baseline`, `axis-a-counter-final`, `axis-a-capacity-final`, `axis-b-tag-final`, `axis-c-context-final`, `axis-combined-final`.

## What was modified

All RTL changes are isolated to `Processor/Src/MicroArchConf.sv`, `Processor/Src/Scheduler/SchedulerTypes.sv`, and `Processor/Src/Scheduler/MemoryDependencyPredictor.sv`. Three Vivado 2026.1 compatibility fixes were also required (board-part identifier, an `include_dirs` property, serialized synthesis jobs) — unrelated to the research and documented in `docs/results.md`.

RSD's original license (Apache 2.0) and copyright headers are unchanged.

## Rigor

Every anomalous or surprising result in this study was independently re-verified — not taken on faith. Two real methodological gaps were found and closed mid-project (a version-control misconfiguration that compromised some functional-verification runs, and two timing results initially attributed to noise) — both documented transparently in `docs/results.md` rather than swept under the rug.

---

## Original RSD README follows below