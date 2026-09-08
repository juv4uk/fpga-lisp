# Step C: Sūtra-processor (sandhi rule engine) — Complete

**Date**: 2026-09-06
**Commit**: 26d3be3 (pushed)
**Branch**: master

## Summary

Implemented the **Sūtra-processor** — a sequential sandhi rule engine (ISA 1.3) as an encoded-mode extension of MOV (rs2=7).

### RTL Added/Modified

| File | Status | Description |
|------|--------|-------------|
| `fpga/rtl/sandhi_engine.sv` | NEW | Sequential FSM: IDLE→LOAD_RULE→APPLY→CHECK_NEXT→OUTPUT. 3 rules (SAVARNA-DĪRGHA, GUNA, YAṇ i/v embryo). ~3-4 cyc/rule, max 10 cyc. Gate: cls=10 ∧ free=0 ∧ nasal=0. |
| `fpga/rtl/control.sv` | MOD | MOV rs2=7 → ST_WAIT_SANDHI blocking state. PC held, sandhi_start pulsed, result written on done. |
| `fpga/rtl/upc8_unit.sv` | — | Unchanged (verified). |

### Assembler (both Python & my-lisp)

| File | Change |
|------|--------|
| `assembler.py` | Added `SANDHI` mnemonic (MOV rs2=7) — byte-identical output to assembler.my |
| `assembler.my` | Same addition — parity verified |

### Contract

| File | Version | Change |
|------|---------|--------|
| `isa-contract.my` | 1.3 | Added `upc8-sandhi` entry: I/O packing, result modes (00/01/10), rule list. |

### Tests — All PASS

| Test | Type | Cases | Status |
|------|------|-------|--------|
| `tb_sandhi.sv` | Unit (engine direct) | 16 golden (4 savarṇa, 4 guṇa, 4 yaṇ, 4 passthrough) | ✅ |
| `tb_sandhi_machine.sv` | End-to-end (machine via UART) | 4 programs (i+a→y+a, a+i→e, ā+a→ā, k+a passthrough) | ✅ |

### Golden Cases (verbatim)

| # | prev | curr | rule | mode | out0 | out1 |
|---|------|------|------|------|------|------|
| 1 | 0x80 (a) | 0x88 (i) | GUNA | 01 | 0xA8 (e) | 0 |
| 2 | 0x80 | 0x89 (ī) | GUNA | 01 | 0xA8 | 0 |
| 3 | 0x80 | 0x90 (u) | GUNA | 01 | 0xB0 (o) | 0 |
| 4 | 0x80 | 0x91 (ū) | GUNA | 01 | 0xB0 | 0 |
| 5 | 0x80 | 0x81 (ā) | SAVARNA | 01 | 0x81 | 0 |
| 6 | 0x81 | 0x80 | SAVARNA | 01 | 0x81 | 0 |
| 7 | 0x88 (i) | 0x89 (ī) | SAVARNA | 01 | 0x89 | 0 |
| 8 | 0x88 | 0x88 | SAVARNA | 01 | 0x89 | 0 |
| 9 | 0x90 (u) | 0x91 (ū) | SAVARNA | 01 | 0x91 | 0 |
|10 | 0x90 | 0x90 | SAVARNA | 01 | 0x91 | 0 |
|11 | 0x88 (i) | 0x80 (a) | YAṆ | 10 | 0x0A (y) | 0x80 |
|12 | 0x88 | 0x90 (u) | YAṆ | 10 | 0x0A | 0x90 |
|13 | 0x90 (u) | 0x80 | YAṆ | 10 | 0x0B (v) | 0x80 |
|14 | 0x90 | 0x88 (i) | YAṆ | 10 | 0x0B | 0x88 |
|15 | 0x88 | 0x81 (ā) | YAṆ | 10 | 0x0A | 0x81 |
|16 | 0x23 (k) | 0x80 (a) | NONE | 00 | 0x23 | 0x80 |

### Verified Encoding Authority

- Class-10 vowel code formula: `code = 0x80 | (row<<3) | (nasal<<1) | len`
  - Source: `evidence/upc8-demo/owner-reference-2026-09-06/README.md:79`
  - Bits: `[7:6]=cls(10)`, `[5:3]=row`, `[2]=free`, `[1]=nasal`, `[0]=len`
- Semivowels (canonical): y=0x0A, v=0x0B, r=0x0C, l=0x0D
- **Critical fix**: `upc8-class-table.json` (0x00–0x29) is an **SLP1 symbol index**, NOT the real UPC-8 encoding.

### Design Document

`runs/2026-09-06-sandhi-design/DESIGN.md` — complete with encoding table, rule logic, golden cases, owner Q&A (5 decisions), integration plan.

### Next (Windows/Gowin)

1. **Synthesis** (`gw_sh`): run PNR → LUT delta vs ISA 1.2 baseline (+206 LUT for upc8_unit).
2. **Hardware smoke**: program `sandhi_demo.bin` → Tang Primer 25K via `upload.py`.
3. **Evidence**: capture register readback, update `evidence/upc8-hardware-2026-09-06/`.

### Files Not to Touch

- `fpga/rtl/upc8_unit.sv` — verified in hardware
- M28–M32 registers
- ISA 1.1 legacy paths

---
*Honesty-over-beauty: unit & machine tests pass in iverilog; synthesis & hardware smoke pending on Windows toolchain.*