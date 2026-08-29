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

