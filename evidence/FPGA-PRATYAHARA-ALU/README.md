# FPGA-PRATYAHARA-ALU verification (2026-09-11)

## What this task actually required

`docs/recommendations-fpga-prototypes.md` proposes a standalone
`fpga_alu.v` phonetic coprocessor (Savarṇa/voicing/palatalization/
Pratyāhāra bitmask+ROM testing). The task asked for a complete
Verilog ALU + testbench + Python reference model + assembler
extension — all four already existed in `prototype/fpga_alu/`
(committed 2026-08-24, before this task was picked up). This session
re-verified them with real tools rather than trusting the doc's
"PASS" claims, and fixed one real defect found in the process.

## Real verification (2026-09-11, this session, real iverilog + python3)

```
$ iverilog -g2012 -o fpga_alu_sim.out fpga_alu.v fpga_alu_tb.v && vvp fpga_alu_sim.out
ALL 10 VERILOG HARDWARE ALU TESTS PASSED SUCCESSFULLY

$ python3 -m unittest test_fpga_alu.py
Ran 4 tests in 0.000s
OK
```

## Defect found and fixed

`iverilog` emitted `fpga_alu.v:87: warning: Extra digits given for
sized` — 8 of the 42 `rom_mask` case entries (lines 87-90, 93, 94, 99,
120: `hal`, `val`, `ral`, `Jal`, `yar`, `yay`, `may`) were written as
18 hex digits instead of the correct 16 for a `64'h...` literal. The
extra 2 leading digits were always `00`, so no bit value was actually
lost (Verilog keeps the low 64 bits) — not a correctness bug, but
sloppy and worth fixing since a future edit to one of those constants
could silently truncate real data instead of a redundant zero.
Trimmed to exactly 16 hex digits each; both testbenches re-run clean
afterward with zero compiler warnings.

## What this is NOT

This is standalone `prototype/`-tier verification, same status as
`docs/recommendations-fpga-prototypes.md` itself already states: the
module is not wired into `fpga/rtl/`, not in `fpga/synth/build.tcl`,
not in `.github/workflows/ci.yml`, and has never been through real
place-and-route. The doc's proposed `OP_PHONETIC_ALU` top-level
opcode is not adopted — integrating it into the live ISA would spend
real opcode space and needs the same cross-repo sign-off discipline
(`ISA-RATIONAL`, `SHIVA-UPC8-ARCHITECTURE-DECISION`) already applied
to every other ISA-surface change this session, not a unilateral
fpga-lisp decision. This task closes the "prototype exists and is
verified" claim only.
