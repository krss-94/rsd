# RSD Memory-Dependence Predictor: Hardware Cost Study

![License](https://img.shields.io/badge/license-Apache%202.0-blue) ![RISC-V](https://img.shields.io/badge/ISA-RISC--V-orange) ![Vivado](https://img.shields.io/badge/toolchain-Vivado%202026.1-green) ![Target](https://img.shields.io/badge/target-Zynq--7000-lightgrey)

**Does FPGA hardware cost scale with a predictor's storage-bit budget, or does what the bits are used for dominate real cost?**

This fork extends [RSD](https://github.com/rsd-devel/rsd) (Mashimo et al., FPT/ICFPT 2019) — an open-source, FPGA-optimized out-of-order RISC-V core — with a controlled, multi-axis synthesis study of memory-dependence predictor (MDP) design, evaluated via real Xilinx Vivado synthesis and implementation on a Zynq-7000 target, not simulation-only area models.

---

## Motivation

Out-of-order processors speculatively reorder loads ahead of earlier stores to improve instruction-level parallelism, at the risk of a memory-order violation when the reordered load and an earlier store touch overlapping addresses. A memory-dependence predictor mitigates this by learning, from past violations, which loads are likely to conflict and should wait rather than issue speculatively.

Common design refinements to an MDP — widening the per-entry confidence counter, adding an identity tag to reduce table aliasing, adding context/history sensitivity to the indexing function — are typically evaluated for *prediction accuracy*, with hardware cost assumed to scale roughly with the number of storage bits added. This project shows, through real synthesis rather than assumption, that this is false: FPGA synthesis tools make **discrete decisions** about which physical primitive implements a piece of memory — LUT-based distributed RAM vs. dedicated Block RAM — based on size and shape, not a smooth cost function. A design that crosses this threshold pays a structural cost unrelated to how many bits were actually added.

## TL;DR

Widening a predictor entry's counter or adding a tag both trigger a **one-time jump** from distributed RAM to Block RAM once total entry width hits 2 bits — after which more width is nearly free. Adding context/history sensitivity **never triggers this jump**, because it perturbs the lookup index instead of widening the stored entry. Combining two refinements is **not additive** — once one has already paid the storage-primitive cost, the second rides along nearly free.

---

## Baseline (V0)

Stock RSD MDP: 1024 entries, 1-bit saturating counter, no tag, no context — direct-mapped, indexed by a PC slice.

| Metric | Value |
|---|---|
| Predictor LUTs | 50 (18 logic + 32 memory) |
| Predictor distributed RAM | 32× RAMD64E |
| Predictor Block RAM | 0 |
| Predictor FF | 14 |
| Full-core LUTs | 24,869 |
| Full-core Block RAM tiles | 16 |
| Setup slack (WNS) | +0.453 ns |

## Axis A — Counter width

| Variant | Predictor LUT | BRAM Tile | Full-core BRAM | WNS (ns) |
|---|---|---|---|---|
| V0 (1b) | 50 | 0 | 16 | +0.453 |
| W2 (2b) | 12 | 1 | 17 | +0.554 |
| W3 (3b) | 13 | 1 | 17 | +0.289 |
| W4 (4b) | 12 | 1 | 17 | +0.613 |

One-time crossover at 1→2 bits (distributed RAM → Block RAM), then completely flat through 4 bits. The 2 Block RAM tiles are attributable to bank count (from the core's rename width), not entry width — a single RAMB18E1's 18Kb capacity vastly exceeds what even the widest entry tested requires.

## Axis A — Table capacity

| Variant | Predictor LUT | Dist-RAM primitive | BRAM Tile | Full-core BRAM |
|---|---|---|---|---|
| 32 | 10 | RAMD32 | 0 | 16 |
| 64 | 11 | RAMD32 | 0 | 16 |
| 128 | 12 | RAMD64E | 0 | 16 |
| 256 | 18 | RAMD64E | 0 | 16 |
| 1024 (V0) | 50 | RAMD64E | 0 | 16 |

Capacity changes never trigger the Block RAM transition at any size — confirming the threshold is governed by per-entry width, not table size. The distributed-RAM primitive switches from RAMD32 (32-deep) to RAMD64E (64-deep) at 128 entries, matching primitive depth to per-bank entry count.

## Axis B — Tag bits

| Variant | Predictor LUT | BRAM Tile | Full-core BRAM | WNS (ns) |
|---|---|---|---|---|
| V0 (0) | 50 | 0 | 16 | +0.453 |
| T1 (1b) | 14 | 1 | 17 | +0.268 |
| T2 (2b) | 18 | 1 | 17 | +0.052 |
| T3 (3b) | 18 | 1 | 17 | +0.474 |
| T4 (4b) | 20 | 1 | 17 | +0.486 |
| T7 (7b, max) | 28 | 1 | 17 | +0.110 |

The same Block RAM transition fires again at T1 (2 total bits/entry), confirming the threshold is total-width-driven, not counter-specific. Unlike the counter axis, tag-comparison logic imposes a distinct, non-monotonic marginal cost: growth, then a local plateau (T2→T3, plausibly a single LUT6 already covering the comparison), then renewed growth through T7.

**8-bit tag is architecturally impossible** on this platform: `PC_Path` is fixed at 19 bits for this SoC's memory map, and the tag-extraction bit-range arithmetic overflows past 7 bits at this table capacity. A real hardware constraint discovered during the study, not a design choice.

## Axis C — Context/history bits

| Variant | Predictor LUT | Dist-RAM | BRAM Tile | Full-core BRAM | WNS (ns) |
|---|---|---|---|---|---|
| V0 (0) | 50 | 32 | 0 | 16 | +0.453 |
| C1 (1b) | 57 | 32 | 0 | 16 | +0.518 |
| C4 (4b) | 58 | 32 | 0 | 16 | +0.903 |

A gshare-style history register, updated each cycle from the predictor's own violation signal, is XORed into the table index; the entry itself is never widened. **Never crosses into Block RAM at any width tested**, and cost stays nearly flat (57→58 LUT for a fourfold increase in history width) — the cheapest of the three mechanisms.

## Combined — Tag + Context

| Configuration | Predictor LUT | BRAM Tile | Full-core BRAM | WNS (ns) |
|---|---|---|---|---|
| Tag only (T1) | 14 | 1 | 17 | +0.268 |
| Context only (C1) | 57 | 0 | 16 | +0.518 |
| **Combined** | **18** | 1 | 17 | +0.852 |

If costs summed independently, the combined design would approach 14 + 57 = 71 LUT. Measured cost is 18 — only 4 above tag alone. Once the tag has already forced the Block RAM transition, the distributed-RAM LUTs context would otherwise need are already freed, and its marginal cost drops to near-zero. Re-routing at a tightened 19ns (52.6MHz) clock confirms the predictor stays off the critical path even here — the one failing path is in the core's floating-point bypass network, unrelated to the predictor and matching the baseline's own critical path.

---

## Methodology

- **Platform:** RSD at commit `17fc94c`, Xilinx Zynq-7000 (`xc7z020clg484-1`, ZedBoard), Vivado 2026.1, Verilator 5.020 for functional pre-verification.
- **Isolation:** every axis branches independently from the common baseline; combined-axis experiments merge two single-axis changesets. No axis is layered on top of another's variant.
- **Clean rebuilds only:** every synthesis result follows a full clean rebuild — an early pilot run showed Vivado's IP-packaging cache can silently reuse a stale netlist across source edits, producing a false-identical result.
- **Three Vivado 2026.1 compatibility fixes** (unrelated to the RTL under study, fully documented) were required versus RSD's tested Vivado 2019.2.1: an updated board-part identifier, an explicit `include_dirs` property on the packaged IP fileset, and serialized synthesis jobs to avoid a build-host memory-pressure crash.

## Rigor

Every anomalous or surprising result was independently re-verified, not taken on faith:

- **Two Vivado-vs-Verilator RTL gaps** were found and fixed: a reserved SystemVerilog keyword (`context`) used as an identifier, and a reduction-OR applied to an unpacked array — both silently accepted by Verilator, both rejected by Vivado. Verilator passing does not guarantee Vivado correctness.
- **A version-control misconfiguration** caused some functional-verification runs to silently re-test the baseline design instead of the intended variant. Found, fixed, and every affected axis's extremal variant re-verified against confirmed-correct source. All synthesis/timing results were unaffected (obtained via direct RTL edits, not the compromised git operation).
- **Two small negative-slack timing results**, initially attributed to placement noise, were independently reproduced bit-for-bit from a second full clean rebuild each, and their failing paths traced to an unrelated core subsystem (recovery/rollback control logic) — confirmed real and deterministic, not predictor-caused.

Full data, discussion, and a plain-language walkthrough: [`docs/results.md`](docs/results.md) · [`docs/explainer.md`](docs/explainer.md)

## Repo structure

| Branch (default: `mdp-hardware-cost-study`) | Contents |
|---|---|
| `mdp-hardware-cost-study` | Counter-width sweep (1/2/3/4-bit saturating counter) |
| `axis-a-capacity` | Table-capacity sweep (32/64/128/256/1024 entries) |
| `axis-b-tag-bits` | Tag-bit sweep (0 through 7 bits, max supported) |
| `axis-c-context-bits` | Gshare-style context/history indexing sweep |
| `axis-combined` | Tag + context combined |

Milestones are tagged: `v0-baseline`, `axis-a-counter-final`, `axis-a-capacity-final`, `axis-b-tag-final`, `axis-c-context-final`, `axis-combined-final`.

All RTL changes are isolated to `Processor/Src/MicroArchConf.sv`, `Processor/Src/Scheduler/SchedulerTypes.sv`, and `Processor/Src/Scheduler/MemoryDependencyPredictor.sv`. RSD's original Apache 2.0 license and copyright headers are unchanged.

---

## Original RSD README follows below



# RSD RISC-V Out-of-Order Superscalar Processor 

RSD is a 32-bit RISC-V out-of-order superscalar processor core.
RSD is very fast due to aggressive OoO features, while it is very compact and can be synthesized for small FPGAs. 
The key features of RSD are as follows:

* ISA
    * Support RV32IMF
    * Support Zephyr applications
* Microarchitecture
    * 2-fetch front-end and 6-issue back-end pipelines
    * Up to 64 instructions are in-flight.
        * These parameters can be configurable.
    * A high-speed speculative instruction scheduler with a replay mechanism
    * Speculative OoO load/store execution and dynamic memory disambiguation
    * Non-blocking L1 data cache
    * Support AXI4 bus
* Implementation
    * Written in SystemVerilog
    * Can be simulated with Modelsim/QuestaSim, Verilator, and Vivado
    * Can be synthesized with Synplify, Vivado and Design Compiler 
        * Design Compiler support is experimental
    * Can run on a Xilinx Zynq board  
        * Avnet Zedboard  
    * FPGA optimized RAM structures
 
![rsd](Docs/Images/rsd.png)


## Getting started 

### Simulation on Verilator/Modelsim/QuestaSim/Vitis

1.  Install the following software for running simulation.    
    * GNU Make, Python3, and GCC (x86-64) 6 or later
    * GCC (RISC-V) 7 or later
    * Verilator or Modelsim/QuestaSim or Xilinx Vitis 2019.2

    Tested environment:

    * GNU Make 4.0 
    * Python 3.4.2
    * GCC 6.5.0 (x86-64)
    * GCC 8.1.0 (RISC-V)
    * Verilator 4.026 2020-01-11 rev v4.026-2-g0c6c83e
    * QuestaSim 2019.4.2
    * Vitis 2019.2

2. Refer to scripts in Processor/Tools/SetEnv.sh and set environment variables.
    * RSD_ROOT must be set for running simulation.
    * RSD_VERILATOR_BIN, RSD_QUESTASIM_PATH or RSD_VIVADO_BIN must be set.
        * See [this page](https://github.com/rsd-devel/rsd/wiki/en-devel-environment-variables).

3. Go to Processor/Src and make as follows.
    * For Modelsim/QuestaSim
        ```
        make            # compile
        make run        # run simulation
        make kanata     # run simulation & outputs a konata log file
        ```
    * For Verilator, add ```-f Makefile.verilator.mk``` like ```make -f Makefile.verilator.mk run```
    * For Vivado, add ```-f Makefile.vivado.mk``` like ```make -f Makefile.vivado.mk run```
        
4. If the simulation ran successfully, you find "kanata.log" in Processor/Src. 
    * Note that, the above sub-command is "kanata", not "konata".

5. You can see the execution pipeline of your simulation above with Konata.
    * Konata is a pipeline visualizer and can be downloaded from [here](https://github.com/shioyadan/Konata/releases) 
	* An example is shown below.
    * ![konata](Docs/Images/konata.gif)

### Run on a Xilinx Zynq board

* See [this RSD wiki page](https://github.com/rsd-devel/rsd/wiki/en-fpga-zynq-synth-for-linux).

## Documents

* See [RSD Wiki](https://github.com/rsd-devel/rsd/wiki).

## License

Copyright 2019-2023 Ryota Shioya (shioya@ci.i.u-tokyo.ac.jp) and RSD contributors, 
see also CREDITS.md. This implementation is released under the Apache License,
Version 2.0, see LICENSE for details. This implementation integrates third-party 
packages in accordance with the licenses presented in THIRD-PARTY-LICENSES.md.

## References

Susumu Mashimo et al., "An Open Source FPGA-Optimized Out-of-Order RISC-V Soft 
Processor", IEEE International Conference on Field-Programmable Technology (FPT), 2019. A pre-print version is [here](https://www.rsg.ci.i.u-tokyo.ac.jp/members/shioya/pdfs/Mashimo-FPT'19.pdf).

