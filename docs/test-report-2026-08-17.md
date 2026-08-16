# fpga-lisp Test Report

**Date:** 2026-08-17  
**HEAD:** `5bcc99c`  
**Method:** Python behavioral model (iverilog/verilator unavailable in sandbox)

## Epistemic State

| Component | PATCHED | MODEL-PASS | COMMITTED | CI-PASS | SYNTH-PASS | HW-PASS |
|-----------|---------|-------------|------------|---------|-------------|---------|
| PC++ fix (control.sv) | ✅ | ✅ | ✅ `5bcc99c` | — | — | — |
| Heap off-by-one (lisp_data_unit.sv) | ✅ | ✅ | ✅ `2d4a455` | — | — | — |
| tb_fetch_pair.sv | ✅ | — | ✅ `8c4a12b` | — | — | — |

**Important:** MODEL-PASS is based on a Python behavioral model that reproduces
the FSM from `control.sv` and the heap logic from `lisp_data_unit.sv`. This is
NOT an RTL simulation. `RTL-SIM-PASS` requires a proper `iverilog` or `verilator`
run, which is still needed.

## Test 1: FETCH_PAIR happy path

**Program:**
```asm
0: LOADI   R1, 10       (fixnum 10)
1: LOADI   R2, 20       (fixnum 20)
2: CONS    R3, R1, R2   (heap[0] = (10 . 20))
3: CAR     R4, R3, R5   (FETCH_PAIR: R4=CAR, R5=CDR)
4: LOADI   R6, 123      (PC skip detector)
5: HALT
```

**Expected:**
- R4 == fixnum 10 (CAR)
- R5 == fixnum 20 (CDR)
- R6 == fixnum 123 (next instruction executed — no PC skip)

**Result: PASS**

```
PC trace: [0, 1, 2, 3, 4, 5]
R4 = 10 (CAR):     PASS
R5 = 20 (CDR):     PASS
R6 = 123 (PC inv): PASS
```

PC trace shows no instruction skipped. The double-PC++ bug is absent:
`ST_WRITE_PAIR_CDR` no longer increments PC; the single increment stays
in `ST_WAIT_LDU`.

## Test 2: Heap capacity — 4096 cells

**Method:** Allocate 4096 cons cells, then attempt 4097th.

**Result: PASS**

```
Allocated 4096 cells: PASS (hp=4096)
4097th allocation → HEAP_FULL: PASS
```

Old code (`hp == 4095`): would have rejected allocation #4096.  
New code (`hp == 4096`): allocation #4096 succeeds, #4097 fails.

The 13-bit `hp` register (0..4096) correctly models:
- 0..4095 = valid heap addresses
- 4096 = HEAP_FULL sentinel

## Test 3: FETCH_PAIR on non-cons → TYPE_ERROR

**Method:** Call FETCH_PAIR on a fixnum register (tag != TAG_CONS).

**Result: PASS**

```
R1 tag = 0 (TAG_FIXNUM), not TAG_CONS
LDU sets error=1 (TYPE_ERROR)
Control sets err_flag=1, err_pc=current PC
FSM → ST_HALT (clean halt)
```

## Performance counters verified

```
perf_cycles = 6
perf_cons = 1
perf_car_cdr = 1
perf_heap_peak = 1
```

All counters match expected values for the test program.

## What is NOT tested

1. **RTL simulation** — no iverilog/verilator in sandbox (MODEL-PASS only, not RTL-SIM-PASS)
2. **Synthesis** — no Yosys/Gowin toolchain
3. **Hardware** — no Tang Primer 25K board
4. **Edge case: rd == rs2** — FETCH_PAIR with identical destinations
   (CAR gets overwritten by CDR). This is an illegal encoding that
   should be rejected by the assembler, but is not yet enforced.
5. **Existing regression tests** — tb_cons.sv, tb_car_cdr.sv, tb_heap.sv
   etc. were not re-run (no simulator available)

## Commit history

| SHA | Description |
|-----|-------------|
| `0fdfb82` | feat: performance counters (6 counters, monitor 0x05–0x0A) |
| `2d4a455` | fix: heap off-by-one — all 4096 cells now usable |
| `8c4a12b` | test: add tb_fetch_pair.sv regression test |
| `5bcc99c` | fix: remove double PC++ in FETCH_PAIR |
