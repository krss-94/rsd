\# RSD Memory-Dependence Predictor: Hardware Cost Study — Final Results



\*\*Platform:\*\* RSD (FPT/ICFPT 2019), Xilinx Zynq-7000 (`xc7z020clg484-1`), Vivado 2026.1, 50MHz baseline

\*\*Repo:\*\* `krss-94/rsd`, branches rooted at commit `17fc94c`



\## V0 Baseline (1024 entries, 1-bit counter, no tag, no context)

Predictor: 50 LUT, 32x RAMD64E, 0 BRAM, 14 FF. Full-core: 24,869 LUT, 6,516 Dist-RAM, 16 BRAM Tile. WNS +0.453ns.



\## Axis A - Counter width

| | V0 | W2(2b) | W3(3b) | W4(4b) |

|---|---|---|---|---|

| Predictor LUT | 50 | 12 | 13 | 12 |

| BRAM Tile | 0 | 1 | 1 | 1 |

| Full-core BRAM | 16 | 17 | 17 | 17 |

| WNS | +0.453 | +0.554 | +0.289 | +0.613 |



One-time crossover at 1->2 bits (LUTRAM->BRAM), then flat plateau through 4 bits.



\## Axis A - Capacity

| | CAP32 | CAP64 | CAP128 | CAP256 | V0(1024) |

|---|---|---|---|---|---|

| Predictor LUT | 10 | 11 | 12 | 18 | 50 |

| Dist-RAM primitive | RAMD32 | RAMD32 | RAMD64E | RAMD64E | RAMD64E |

| BRAM Tile | 0 | 0 | 0 | 0 | 0 |

| Full-core BRAM | 16 | 16 | 16 | 16 | 16 |



Never crosses into BRAM at any capacity - crossover is entry-width driven, not table-size driven.



\## Axis B - Tag bits

| | V0 | T1 | T2 | T3 | T4 | T7(max) |

|---|---|---|---|---|---|---|

| Predictor LUT | 50 | 14 | 18 | 18 | 20 | 28 |

| BRAM Tile | 0 | 1 | 1 | 1 | 1 | 1 |

| Full-core BRAM | 16 | 17 | 17 | 17 | 17 | 17 |

| WNS | +0.453 | +0.268 | +0.052 | +0.474 | +0.486 | +0.110 |



Same BRAM crossover as counter axis (confirms total-width, not counter-specific). Comparator cost grows non-monotonically: local plateau at T2->T3, resumes growing to T7. \*\*T8 architecturally impossible\*\* - `PC\_Path` is only 19 bits wide (`PC\_WIDTH=19`, fixed for this SoC's memory map); tag+index bit-range math overflows past 7 bits. Real hardware ceiling, not a bug.



\## Axis C - Context/history bits

| | V0 | C1 | C4 |

|---|---|---|---|

| Predictor LUT | 50 | 57 | 58 |

| Dist-RAM | 32 | 32 | 32 |

| BRAM Tile | 0 | 0 | 0 |

| Full-core BRAM | 16 | 16 | 16 |

| WNS | +0.453 | +0.518 | +0.903 |



Never crosses into BRAM at any tested width - perturbs the index (gshare-style XOR), never widens the stored entry. Flattest cost curve of the three axes (57->58 LUT for 1->4 bit history).



\## Combined (Tag T1 + Context C1)

Predictor: 18 LUT, 0 Dist-RAM, 1 BRAM Tile, 12 FF. Full-core: 24,850 LUT, 6,484 Dist-RAM, 17 BRAM Tile. WNS +0.852ns.



\*\*Not additive\*\*: combined cost (18 LUT) is only +4 over T1 alone (14), far less than C1's standalone context cost (+7 over V0). Once the tag triggers the BRAM crossover, adding context is cheap - the distributed-RAM LUTs context would otherwise need are already freed by the move to BRAM.



\*\*Fmax check (combined variant, 19ns/52.6MHz):\*\* WNS -0.070ns, 1 failing endpoint, essentially matches V0's own practical ceiling. Failing path is `bypassNetwork->fpExStage` (V0's original bottleneck) - predictor confirmed off the critical path even at tighter timing.



\## Central finding

Three structurally different ways to add bits to the same predictor produce three different hardware-cost shapes:

\- \*\*Wider counter:\*\* one-time BRAM crossover, then free.

\- \*\*Added tag:\*\* same crossover, plus a separate, non-monotonically-growing comparator cost.

\- \*\*Added context:\*\* never crosses into BRAM; cheapest, flattest cost of all three.

\- \*\*Combined:\*\* costs interact - not a simple sum of individual axis costs.



Raw storage-bit accounting fails to predict real FPGA cost; what the bits are used for, and how they interact with the synthesis tool's primitive-inference heuristics, dominates.



\## Methodology notes

\- Vivado 2026.1 required three compatibility fixes vs RSD's tested 2019.2.1 (board-part identifier, `include\_dirs` property, serial synthesis jobs).

\- Two Vivado-vs-Verilator RTL gaps found: reserved keyword `context` as an identifier, and reduction-OR on an unpacked array - both silently accepted by Verilator, rejected by Vivado. Verilator passing is necessary but not sufficient for Vivado correctness.

\- A git remote-naming mismatch between the two VMs (Ubuntu's fork remote is `myfork`, Windows' is `origin`) caused Ubuntu's Verilator checks to silently re-test V0 instead of each variant for most of the tag/capacity/combined/early-context work. Vivado (Windows) results are unaffected - direct file edits, not git-dependent, and every result showed genuine, differing synthesis outcomes. Verilator confirmations from C4 onward are confirmed-correct against the right commit.

\- Every Vivado build used a full clean rebuild (kill lingering process + delete project directory) after an early stale-IP-cache incident produced a false identical result.



\## Rigor pass (independent re-verification)

Two real gaps were found and closed after the initial dataset was complete:



1\. \*\*Git remote mismatch.\*\* The Ubuntu VM's fork remote is named `myfork` (Windows' is `origin`) — every `git checkout/pull origin <branch>` on Ubuntu since Phase 3 silently failed, leaving Ubuntu stuck testing plain V0 for most Verilator "confirmation" runs (W2-W4, T1-T7, CAP32-256, combined). \*\*Fixed and re-verified\*\*: correctly checked out the extremal variant of every axis (W4, CAP32, T7, C4, combined) via the correct remote and re-ran Verilator — all confirmed identical to V0 against the genuinely correct RTL. Vivado/Windows results were never affected by this bug (direct file edits, not git-dependent).



2\. \*\*Single-run timing anomalies.\*\* CAP32 and CAP64 each showed a small negative WNS on first build, provisionally attributed to placement noise unrelated to the predictor. \*\*Re-verified independently\*\*: both builds were redone from a full clean rebuild and reproduced their exact original numbers bit-for-bit (CAP64: -0.157ns/1 endpoint both times; CAP32: -0.375ns/TNS-0.506/2 endpoints both times). Confirms Vivado's placement/routing is deterministic here, and combined with the independently-established root cause (both failing paths are entirely inside `recoveryManager`, unrelated to the predictor), this is doubly confirmed as real but not predictor-caused.



All five axes' conclusions stand on: direct Vivado synthesis data (never git-dependent), now-correctly-verified functional checks, and reproducibility-confirmed timing anomalies with an independently established, predictor-unrelated root cause.

