# External memory (SDRAM/PSRAM) scoping (FPGA-EXTERNAL-MEMORY-SDRAM)

Status: scoping only, not a design, not implemented. This is
deliberately conservative -- the honest state is "we don't have the
board's memory-chip specifics on this machine yet," and inventing pin
assignments or timing parameters to fill that gap would be worse than
leaving it open. Plan doc's own framing (`docs/lisp-machine-plan.md`,
"Пам'ять поза FPGA"): `FPGA BRAM → cache/young heap → external
SDRAM/PSRAM`, explicitly a "Пізніше" (later) item, not near-term.

## Why this matters at all right now

Current heap: 4096 cons cells (`fpga/rtl/lisp_machine.sv`'s
`HEAP_ADDR_WIDTH`-driven size), consuming BSRAM `16/56` blocks on its
own per the plan doc's own synthesis-derived numbers (`docs/testing.md`'s
M18 imem-expansion entry) -- `24/56` (43%) total including `imem`, per
the real synthesis run recorded in `ecosystem-status.md` (2026-08-13).
4096 cells sounds like a lot until a real program does anything
list-heavy: M31's `append` alone touches multiple cells per call, and
nothing in this repo has yet run a program large enough to hit the
ceiling -- but the ceiling exists and is closer than "56 blocks total"
suggests once `imem`, registers, and control logic are accounted for.

## What's missing before any RTL work

1. **The board's actual external memory chip and its datasheet.**
   `docs/README.md` (this repo) points at the Sipeed wiki
   (`wiki.sipeed.com/hardware/en/tang/Tang-Primer-25K/`) for schematics
   and a cloned `TangPrimer-25K-example` reference repo containing
   working SDRAM peripheral Verilog -- but that clone
   (`docs/TangPrimer-25K-example/`) is gitignored and not present on
   this machine as of this writing. Whoever picks this up needs to
   either re-clone it or pull the schematic/datasheet directly from that
   wiki page. This document does not guess pin names, chip part numbers,
   or timing parameters without that source in hand -- doing so would
   produce RTL nobody could trust without re-deriving it anyway.
2. **Gowin's own memory controller IP**, if the chip is one Gowin's
   toolchain has generator support for (common for Gowin dev boards) --
   check `IDE\ipcore\` in the installed Gowin toolchain
   (`C:\Gowin\Gowin_V1.9.12.03_x64\IDE\ipcore\`, per
   `docs/hardware-setup.md`) before hand-writing a controller from the
   reference example; a vendor-generated core is much more likely to be
   timing-closed correctly on the first try than a hand-port.
3. **A real trigger for needing this at all.** No fixture or milestone
   so far has run out of the current 4096-cell heap -- this is
   forward-looking capacity planning, not a fix for an observed failure.
   Worth confirming that stays true (or doesn't) before investing in the
   controller, rather than assuming.

## Proposed shape (architecture only, not a spec)

Matches the plan doc's own phrasing: BRAM heap stays the "young"
generation (fast, small, everything a typical program touches), external
memory becomes overflow capacity once BRAM's bump allocator would
otherwise fail. This is deliberately similar in spirit to a generational
GC's nursery/old-space split -- worth designing *after*
`FPGA-GC-DESIGN-DOC` lands (a trace-based collector needs to walk both
spaces uniformly; getting GC's root-set/sweep-pass design right first,
then extending it across two heap tiers, is a smaller step than doing
both simultaneously). Not asserting a hard dependency in the task
registry since GC and external memory are separable in principle, but
flagging the sequencing risk here.

## Non-goals for this document

- Any pin assignment, chip part number, or timing constraint -- would be
  fabricated without the actual board schematic in hand.
- A decision on SDRAM vs. PSRAM specifically -- depends entirely on what
  the Tang Primer 25K actually has populated, unverified here.
- An implementation timeline -- this is a "later" item per the plan
  doc's own classification, not queued ahead of items 25-28.
