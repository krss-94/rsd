\# The RSD Memory-Dependence Predictor Project — Full Breakdown (Explain Like I'm 5)



This document explains everything that happened in this project, from the ground up, in plain language. It covers the big research question, all the tools involved, every experiment run, every result found, every bug hit along the way, and — importantly — everything that is \*\*not yet done\*\*.



\---



\## Part 1: What is this project actually about?



\### The big question in one sentence

\*\*When you make a small piece of computer-chip hardware "smarter" by giving it more memory, does the actual cost on the chip go up smoothly, or does it jump around in weird, unpredictable ways?\*\*



\### Why does this matter?

Modern CPUs (the brain of your computer) don't run instructions one at a time in order — they run many instructions \*out of order\*, executing whichever ones are ready first, to go faster. This is called "out-of-order execution."



One tricky problem with out-of-order execution: sometimes a `load` (read from memory) and a `store` (write to memory) happen close together, and the CPU has to guess whether the load needs to wait for the store to finish first (because they might touch the same memory address) or whether it's safe to run the load early (because they touch different addresses).



Guessing wrong is expensive — the CPU has to throw away work and redo it. So CPUs have a little helper circuit called a \*\*memory-dependence predictor\*\* that tries to guess correctly, based on what happened before. Like a weather forecaster who remembers "last time it was cloudy at 3pm, it rained by 4pm" — the predictor remembers past patterns to guess about the future.



\### The specific question we're studying

Predictors like this store information in a table. You can make that table "smarter" in different ways:

\- Give each entry more memory (a bigger counter, so it remembers more confidently)

\- Give each entry a "tag" (a fingerprint) so it can tell "is this really information about the instruction I'm looking at, or did I mix it up with a different instruction that happens to land in the same slot?"

\- Give the whole table a sense of "recent history" so it can tell different situations apart even for the exact same instruction



Each of these makes the predictor \*better\* at guessing correctly. But each of them also costs more hardware (more transistors, more chip area). The question is: \*\*does that cost scale smoothly with how many bits you add, or does it jump in surprising, non-obvious ways?\*\*



This matters a lot for real chip designers, because if you assume "cost = bits × some constant," you might make bad decisions. If the real relationship has sudden jumps and flat plateaus, that changes what the "smart" choice is.



\---



\## Part 2: The tools involved (and why each one exists)



\- \*\*RSD\*\*: An open-source CPU design, written by researchers, that implements a real out-of-order RISC-V processor. Think of it as a free, working blueprint for a real CPU core, including the exact memory-dependence predictor we're studying. It's written in a hardware description language (SystemVerilog), not a normal programming language — it describes circuits, not software.



\- \*\*SystemVerilog\*\*: The language RSD is written in. It looks a bit like C, but instead of describing steps for a computer to run, it describes actual physical circuits — wires, registers, logic gates.



\- \*\*Verilator\*\*: A tool that takes SystemVerilog code and turns it into a \*simulation\* you can run on a normal computer, without needing real chip hardware. This lets you test "does the CPU actually work correctly" cheaply and quickly (in seconds/minutes), before spending 20-30 minutes on the expensive step below.



\- \*\*Vivado\*\*: A tool made by AMD/Xilinx that takes SystemVerilog code and turns it into an actual bitstream — a file that can be loaded onto a real FPGA chip (a special kind of chip that can be reconfigured to become almost any circuit). This is the "real" step: it tells you exactly how many physical hardware resources (LUTs, flip-flops, Block RAM) your design will actually use once built for real. This step is slow (20-30+ minutes each time) and picky about exact syntax.



\- \*\*FPGA (Field-Programmable Gate Array)\*\*: A chip made of thousands of tiny reconfigurable building blocks. Vivado's job is to figure out how to arrange those building blocks to implement your design. The specific chip we're targeting is a \*\*Zynq-7000\*\* (part number `xc7z020clg484-1`), found on a board called the ZedBoard.



\- \*\*LUT (Look-Up Table)\*\*: The basic building block of "logic" on an FPGA — a tiny piece of hardware that can be configured to compute almost any small logic function (like AND, OR, XOR, or more complex things).



\- \*\*Distributed RAM (LUTRAM)\*\*: When you need a \*small\* amount of memory, Vivado can repurpose some LUTs to act as tiny memory cells instead of logic. Cheap for small amounts of storage.



\- \*\*Block RAM (BRAM)\*\*: The FPGA also has dedicated, purpose-built memory blocks (much bigger than LUTRAM, but you only have a limited number of them, e.g. 140 on our chip). Good for large amounts of storage, wasteful for tiny amounts (using a whole BRAM block to store a handful of bits is like renting a warehouse to store a paperclip).



\- \*\*Slice, FF (Flip-Flop), Register\*\*: A flip-flop is a single bit of memory (like a tiny light switch that remembers on/off). "Slice" is a bundle of LUTs and FFs that Vivado groups together when reporting usage.



\- \*\*WNS / WHS (Worst Negative Slack / Worst Hold Slack)\*\*: A measure of "how much timing margin does the chip have." If this number is positive, your design meets its speed target (the clock — in our case 50MHz, meaning the chip does something new 50 million times per second). If it goes negative, the design is "too slow" for that target and won't work reliably.



\---



\## Part 3: The wild ride of just getting the tools to work



Before any real research could happen, we had to fight through a \*lot\* of environment setup problems. This is completely normal in real research — tools are picky, and old research code doesn't always play nice with brand-new versions of tools. Here's what happened, in order:



1\. \*\*Two virtual machines.\*\* Since Vivado only runs on Windows or Linux (x86), and the actual physical computer was a Mac, we set up two virtual machines (VMs) — pretend computers running inside the real Mac. One runs Ubuntu Linux (for fast, cheap simulation with Verilator). One runs Windows (for the real, slow, accurate Vivado builds).



2\. \*\*Wrong CPU architecture.\*\* The Mac uses Apple Silicon chips (ARM architecture), but Vivado only runs on regular Intel/AMD-style chips (x86). Discovered the Ubuntu VM was running in the wrong "mode" for Vivado — but it turned out Vivado on Windows (using Windows' own compatibility tools) worked fine, so we used Windows for all things Vivado.



3\. \*\*Verilator version mismatch.\*\* RSD's official instructions say to use Verilator version 4.026, but that old version wouldn't build correctly on this modern system (a parsing bug). We used the newer version 5.020 instead, and confirmed it worked identically for our tests — documented as a deliberate, safe substitution.



4\. \*\*Vivado 2026.1 vs. RSD's tested version (2019.2.1).\*\* RSD's setup scripts were written for a Vivado version from 2019 — 7 years older than what we had. This caused three real problems that needed fixing:

&#x20;  - \*\*The exact chip's "board file" name changed.\*\* Vivado organizes chips by internal ID codes; the exact ID string for the ZedBoard changed between old and new Vivado, so we had to find and use the new correct ID.

&#x20;  - \*\*A folder path setting was missing\*\* that tells Vivado where to find some of RSD's own header files, causing "file not found" errors deep in the build.

&#x20;  - \*\*Running multiple build jobs at once crashed Vivado\*\* (silently, no error message) because our virtual machine didn't have enough memory to run several synthesis jobs simultaneously. Fixed by forcing Vivado to do one job at a time (slower, but reliable).



5\. \*\*A sneaky invisible-character bug (BOM).\*\* When editing files using a certain Windows tool (PowerShell) with a certain setting, it silently added 3 invisible bytes at the start of a file (called a "byte order mark"). This is invisible to a human looking at the file, but Vivado's strict parser rejected the file outright. Took some detective work to figure out ("why is this exact file broken when nothing looks different?") before finding and removing those invisible bytes.



6\. \*\*A stale-cache bug that gave a fake "success."\*\* At one point, we edited the actual circuit design, ran the build, and got a result — but the result was \*suspiciously\* identical, down to the exact tiniest detail, to a previous, different design. This was a big red flag: real changes should produce at least \*slightly\* different numbers. Investigation revealed Vivado had silently reused old cached results instead of rebuilding from the new files, because the build folder wasn't fully wiped clean between attempts. Lesson learned: \*\*always fully delete and rebuild from scratch when testing a new variant\*\*, otherwise you might be measuring old data by accident.



\---



\## Part 4: How the predictor actually works (the baseline, "V0")



The predictor lives in a module called `MemoryDependencyPredictor`. Here's the plain-language version of what it does:



\- It has a table with \*\*1024 slots\*\* (like 1024 mailboxes in a row).

\- When the CPU wants to run a `load` instruction, it looks at the load's address in memory (its "PC," or program counter — basically "which line of code is this") and uses part of that address to pick \*\*which mailbox\*\* to check (like using the last 3 digits of a phone number to pick a shelf in a filing cabinet).

\- Each mailbox just holds \*\*1 single bit\*\*: "have I seen a violation (a load/store conflict) happen here before?" If yes (bit = 1), the CPU plays it safe and waits. If no (bit = 0), the CPU guesses it's safe to run early.

\- Whenever a real violation is detected, the predictor updates that mailbox to "yes" (1) so it remembers for next time.



This is about as simple as a predictor can be. It has two weaknesses researchers might want to fix:

1\. \*\*No way to double-check "is this really my mailbox."\*\* Two completely different instructions could accidentally use the same mailbox (this is called "aliasing," like two people sharing one mailbox by coincidence), and the predictor has no way to tell them apart.

2\. \*\*No sense of "context."\*\* The exact same instruction, in different situations, always looks at the exact same mailbox — even if the surrounding circumstances are totally different.



We measured this baseline (V0) carefully:

\- Uses \*\*50 LUTs\*\*, \*\*32 tiny memory blocks called RAMD64E\*\* (a type of distributed RAM), \*\*0 Block RAM tiles\*\*, and \*\*14 flip-flops\*\*, when isolated and measured on its own.

\- The whole CPU (with this predictor inside it) uses \*\*16 Block RAM tiles\*\* total, out of 140 available on the chip.

\- Timing margin (WNS) was \*\*+0.453 nanoseconds\*\* — comfortably meeting the 50MHz speed target.



\---



\## Part 5: Experiment Group A — Making the counter bigger



\*\*Idea:\*\* what if each mailbox holds a bigger number instead of just 1 bit? Instead of "yes/no," it could hold "how \*confident\* am I" (0, 1, 2, or 3, getting more confident as it sees more repeated violations).



We tested 1-bit (the baseline), 2-bit, 3-bit, and 4-bit versions, calling them V0, W2, W3, W4.



\### What we found — a surprise!

You might expect: 2x the bits = roughly 2x the memory used. \*\*That's not what happened.\*\*



Instead:

\- Going from \*\*1 bit to 2 bits caused a sudden, dramatic change\*\*: the predictor completely switched from using cheap "distributed RAM" (leftover LUT space) to using dedicated, purpose-built "Block RAM" tiles instead. This is like discovering that storing 1 sticky note fits in your pocket, but storing 2 sticky notes suddenly requires renting a small locker — a weird jump, not a smooth scale-up.

\- Once it made that jump, going from \*\*2 bits to 3 bits to 4 bits cost literally nothing extra\*\* — flat, completely unchanged hardware usage. This is because the "locker" (Block RAM tile) it rented was already way bigger than needed, so a little more data fit inside for free, with room to spare.



We double-checked this wasn't a fluke: the number of Block RAM tiles used by the \*entire CPU\* went up by exactly 1 (from 16 to 17) — precisely matching what the predictor itself started using. Nothing else in the whole design changed. That's a very clean, trustworthy result.



\*\*Why does this happen?\*\* FPGA design tools have to decide, for every little piece of memory in your design, "should I build this out of cheap LUT scraps, or should I use one of the dedicated memory blocks?" There's a size threshold where the tool's decision flips. Below the threshold, LUT scraps. Above it, dedicated block. Our stock 1-bit design happened to be just below that threshold; 2 bits pushed it just over.



\---



\## Part 6: Experiment Group B — Adding a "fingerprint check" (tags)



\*\*Idea:\*\* instead of (or in addition to) a bigger counter, what if each mailbox also stores a "fingerprint" of which instruction it belongs to? Then when checking a mailbox, the predictor first checks "does this fingerprint match the instruction I'm looking at right now?" If not, it ignores whatever's in that mailbox (treats it as "no information yet") rather than trusting a possibly-wrong answer.



We tested 1-bit, 2-bit, and 3-bit fingerprints (T1, T2, T3), each combined with the original 1-bit counter.



\### What we found

\- \*\*The same size-threshold jump happened again\*\* — as soon as the \*total\* amount of data per mailbox reached 2 bits (whether that's from a wider counter OR from adding a fingerprint), it triggered the same switch to Block RAM. This is a nice confirmation: \*\*it's the total size that matters, not specifically what kind of information you're storing.\*\*

\- \*\*But there's an extra cost specific to fingerprints that the counter-only version didn't have\*\*: actually \*checking\* a fingerprint match requires extra "comparison" circuitry (like a tiny electronic "are these two things equal?" checker). This extra cost also grew, then flattened out, but at a \*different\* point than the memory-block jump — going from a 1-bit to 2-bit fingerprint cost more logic, but going from 2-bit to 3-bit cost nothing extra (a single small logic block, called a LUT6, can already handle comparing 2-3 bits at once without needing more hardware).



This is a genuinely interesting, different-shaped result from Experiment Group A: \*\*same memory-block threshold, but a different, extra "comparison logic" cost layered on top.\*\*



\---



\## Part 7: Experiment Group C — Adding "situational awareness" (context/history)



\*\*Idea:\*\* instead of changing what's stored in each mailbox, what if we change \*\*which mailbox gets checked\*\* based on recent history? Keep a tiny scratchpad that remembers "did a violation just happen very recently" and mix that into the decision of which mailbox to look at — so the exact same instruction might check a \*different\* mailbox depending on recent circumstances. (This is a classic trick used in branch predictors too, called "gshare.")



We tested a 1-bit version of this (C1).



\### What we found

This is the most different result of all three groups: \*\*no size-threshold jump happened at all.\*\* The predictor's mailboxes stayed exactly the same size as the baseline (still just 1 bit each) — we didn't touch them. We only added a tiny separate "recent history" scratchpad (1 extra bit of memory) and a small amount of extra wiring to mix that history into the mailbox-selection logic.



Cost: \*\*exactly +1 flip-flop\*\* (for the history scratchpad — a perfectly clean, predictable cost) and \*\*+7 LUTs\*\* (for the extra wiring). No Block RAM increase at all — the whole CPU still used exactly 16 Block RAM tiles, unchanged from the baseline.



This confirms something important: \*\*the size-threshold jump we saw in Groups A and B is specifically about making each individual mailbox bigger — not about "changing the predictor" in general.\*\* A totally different kind of upgrade (changing \*which\* mailbox gets checked, rather than \*what's in\* the mailbox) can add real intelligence to the predictor without ever triggering that expensive jump.



\### Bugs we hit while building this one

Two real mistakes were caught and fixed here (both were things that Verilator, the fast simulator, didn't catch, but Vivado's stricter real-hardware compiler did catch):

1\. We accidentally named something `context`, which turns out to be a reserved word in the SystemVerilog language (like trying to name your pet "if" or "while" in a normal programming language) — had to rename it.

2\. We tried to combine multiple signals together using a shortcut ("OR all of these together") on a type of list that doesn't support that shortcut in strict hardware-description rules — had to write it a slightly different, more explicit way instead.



\---



\## Part 8: The big-picture conclusion so far



If you only counted "bits added," you'd think all three experiment groups should cost roughly the same, scaling smoothly. \*\*They don't:\*\*



| Approach | Does it trigger the expensive memory-block jump? | Extra cost pattern |

|---|---|---|

| Bigger counter (Group A) | Yes, once, then flat forever after | Cheapest per-bit after the initial jump |

| Add a fingerprint (Group B) | Yes, same threshold as Group A | Same memory jump, PLUS its own separate comparison-logic cost that grows then flattens |

| Add situational history (Group C) | \*\*No, never\*\* | Small, clean, predictable cost (just what you'd naively expect) |



\*\*This is exactly the kind of result worth writing up\*\*: naive "more bits = more cost, smoothly" thinking would completely miss all of this nuance. Real hardware-cost behavior has sudden jumps, flat plateaus, and depends heavily on \*what kind\* of information you're adding, not just how much.



\---



\## Part 9: What is NOT done yet (important — please read this part)



This project explored real, interesting territory tonight, but it is \*\*not a finished study\*\*. Here's exactly what's missing, compared to the original research plan:



1\. \*\*The capacity axis was never tested at all.\*\* The original plan called for testing table sizes of 32, 64, 128, 256 entries (vs. the stock 1024). We never touched this — every single test tonight used the stock 1024-entry table.



2\. \*\*Tag and context widths tested were smaller than originally planned.\*\* The plan called for testing 4-bit and 8-bit tags/context; we only tested up to 3-bit tags and 1-bit context.



3\. \*\*No experiments combining two or more upgrades at once\*\* (e.g., a bigger counter AND a tag AND context, all together) — everything was tested in isolation, one change at a time.



4\. \*\*No real speed-limit (Fmax) re-testing\*\* for any of tonight's new variants. We only checked "does it still hit the fixed 50MHz target," not "what's the actual fastest speed this chip could run at" for each variant (V0's original baseline session did this kind of deeper speed sweep, but we didn't repeat it for the new variants).



5\. \*\*No formal statistical/regression analysis\*\* — the results doc that exists is a clear qualitative summary with real numbers, but not a deep statistical treatment.



6\. \*\*No architectural robustness check\*\* — we haven't confirmed these findings hold up under a different chip, a different clock speed target, or a different starting table size. Right now, all conclusions are specific to this one configuration.



7\. \*\*No actual research paper has been drafted\*\* — only the underlying results and this explanatory document exist so far.



\---



\## Part 10: Where everything lives



\- \*\*Code:\*\* GitHub, `krss-94/rsd`, several branches: `mdp-hardware-cost-study` (counter-width experiments), `axis-b-tag-bits` (fingerprint experiments), `axis-c-context-bits` (history experiments) — all branching from the same starting point, commit `17fc94c`.

\- \*\*Results document:\*\* `mdp\_hardware\_cost\_results.md` (already generated) — a more compact, technical version of everything in this document, meant as a reference table/summary rather than an explainer.

\- \*\*This document:\*\* the plain-language, full-detail walkthrough of everything that happened.



\---



\## Part 11: Everything that happened after the last update (the full finish)



This section covers the rest of the project — the parts that happened after the document above was written. Same plain-language style.



\### The capacity experiment (the piece that was missing before)

Remember the original plan had three "make the mailbox system smarter" experiments: bigger counters (done), fingerprints/tags (done), and situational history (done) — but there was also a fourth thing that got skipped for a long time: \*\*how many mailboxes should there be in the first place?\*\*



The stock predictor has 1024 mailboxes. We tried shrinking it down to 256, then 128, then 64, then 32, and measured the cost each time.



\*\*Result: shrinking the table scales down smoothly and predictably — no weird jumps.\*\* Fewer mailboxes just needs fewer of the little memory-scrap blocks (LUTRAM), roughly proportional to the size. Interestingly, at 128 mailboxes the tool switched to a slightly different flavor of memory-scrap block (a smaller, shallower one that fits the smaller table better) — a sensible, expected adjustment, not a surprise. \*\*Crucially: no size of table, big or small, ever triggered the expensive "rent a locker" (Block RAM) jump.\*\* That confirms the earlier finding: the locker-jump is about how \*wide\* each individual mailbox's contents are, never about how \*many\* mailboxes there are.



\### A real speed limit we hit (and understood)

At the two smallest table sizes (64 and 32 mailboxes), the timing check came back \*slightly\* failing — the chip would have been just a hair too slow to hit its 50-million-times-a-second target. We didn't just accept this — we tracked down exactly why. It turned out the slow spot had nothing to do with the predictor at all — it was in a completely different part of the CPU (the "recovery" circuitry that undoes work when the CPU guesses wrong elsewhere). Shrinking the table just happened to shuffle where things get placed on the chip slightly, which nudged this \*already-borderline\* unrelated circuit over the edge. We even rebuilt these two configurations a second time from scratch to make sure it wasn't a fluke — and got the \*exact same\* failing result both times. That's actually reassuring: it means the tool isn't behaving randomly, and the slowdown is a real, repeatable, but harmless side-effect — nothing to do with our predictor experiment.



\### The tag experiment kept going — and we found a real wall

We kept growing the "fingerprint" size: 4-bit fingerprints, then tried to push all the way to 8-bit fingerprints (matching the original plan). \*\*The 8-bit version flat-out failed to build.\*\* Not a mistake on our part — a genuine limit of this specific chip's design. The program counter (basically "which instruction are we on") in this particular setup is only 19 bits wide, and once the fingerprint got wide enough, the math needed to compute it ran out of address bits to work with. We figured out the maximum fingerprint size that actually fits (7 bits) and used that as the true ceiling instead. This is a completely legitimate finding — sometimes an idea that looks fine on paper hits a real hardware limit, and finding that limit and explaining it clearly is itself a valid, useful result.



Also interesting: the fingerprint-comparison logic's cost pattern wasn't simple. It grew, then flattened out for a bit (like we saw before), but then started growing again at larger sizes — a bumpier, more complex cost curve than the smooth "make the counter bigger" experiment ever showed.



\### The context experiment, at a bigger size

We tested the "situational awareness" trick (Group C from before) again, this time with 4 bits of history instead of just 1. Same result as before, even more clearly confirmed: \*\*still zero jump into the expensive Block RAM locker\*\*, and the cost barely moved at all (from 57 up to just 58 tiny building blocks) even though we quadrupled how much history it remembered. This is the cheapest of all three tricks by a wide margin.



\### Combining two tricks at once — and a genuine surprise

We tried putting the fingerprint trick AND the situational-awareness trick into the predictor \*at the same time\*. This took real, careful work — the two tricks had been built separately and needed to be carefully stitched together without breaking either one (a bit like carefully merging two different people's edits to the same document, making sure both sets of changes survive).



\*\*The surprise: combining them was much cheaper than adding their costs together.\*\* If you just added up "fingerprint alone" and "situational-awareness alone," you'd expect the combined version to cost a lot. Instead, once the fingerprint trick already triggered the expensive-locker jump, adding the situational-awareness trick on top was almost free — because the locker had spare room, and the situational-awareness circuitry could piggyback on space that was already being paid for. \*\*Two upgrades together aren't simply the sum of their individual price tags — they can share costs in ways that are only visible once you actually build and measure the combination\*\*, not just estimate each piece separately.



We also double-checked that this combined version still runs at a similar top speed as everything else, and confirmed (again) that the predictor itself is never the thing slowing the chip down — some other, unrelated part of the CPU is always the actual speed bottleneck.



\### The "make sure nobody can poke holes in this" pass

Near the end, we did something important: we deliberately went back and tried to find weaknesses in our own results, rather than just trusting them.



We found two real problems:



1\. \*\*A miscommunication between the two computers.\*\* Remember there were two virtual computers working together (one for quick simulated testing, one for the real, slow, accurate build)? It turned out the quick-testing computer had a small, easy-to-miss setup mistake that meant, for a big stretch of the project, its "let's double check this still works correctly" step was silently re-checking the \*original, unmodified\* predictor instead of whichever new version we thought we were testing — even though it kept reporting "success." The good news: the slow, accurate, \*real\* measurements (the ones that actually matter — the LUT and Block RAM and speed numbers) were completely unaffected by this, since those always came from directly editing the real files, not from this shortcut. But the "quick sanity check" layer had a real blind spot for a while. We fixed the setup mistake and specifically went back and correctly re-ran the sanity check for the biggest, most different version of each experiment — and every single one still passed cleanly, for real this time.



2\. \*\*We double-checked our "that's probably just random noise" claims.\*\* A couple of times during the project, we saw a small hiccup in results and explained it away as likely just normal randomness in how the tool arranges circuits — but we hadn't actually \*proven\* that at the time. So we went back and rebuilt those exact same configurations a second time, completely independently, to see if the "random" hiccup would even show up again. It did — in the \*exact\* same way, down to the tiniest detail, both times. That told us it wasn't random at all; it was a real, repeatable, predictable side effect (of the kind explained above) — which is actually a \*better\*, more solid answer than "we think it's probably nothing."



Finding your own mistakes and then actually fixing them, rather than hoping nobody notices, is exactly what makes a set of results something other people can trust.



\### Where things stand now

All five threads of experimentation are done, cross-checked, and as solid as this kind of study reasonably gets:

\- Making the counter bigger (Group A, counter version)

\- Making the table smaller or bigger (Group A, capacity version)

\- Adding fingerprints (Group B)

\- Adding situational awareness (Group C)

\- Combining fingerprints and situational awareness together



What's still genuinely missing (repeating from before, since this hasn't changed): a deeper statistical writeup, a check that these findings hold up on a totally different chip or clock speed, and an actual written-up research paper pulling all of this together into a polished document. Those are the next steps.

