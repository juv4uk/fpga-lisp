# fpga-lisp Test Report

**Date:** 2026-08-17 (RTL-SIM-PASS update: 2026-08-18)
**HEAD:** `5bcc99c` (RTL-SIM-PASS as of `9b529f2`)
**Method:** Python behavioral model (iverilog/verilator unavailable in sandbox)
originally; real `iverilog` run added 2026-08-18 once the sandbox
constraint no longer applied.

## Epistemic State

| Component | PATCHED | MODEL-PASS | COMMITTED | RTL-SIM-PASS | SYNTH-PASS | HW-PASS |
|-----------|---------|-------------|------------|---------|-------------|---------|
| PC++ fix (control.sv) | ✅ | ✅ | ✅ `5bcc99c` | ✅ `9b529f2` | — | — |
| Heap off-by-one (lisp_data_unit.sv) | ✅ | ✅ | ✅ `2d4a455` | — | — | — |
| tb_fetch_pair.sv | ✅ | — | ✅ `8c4a12b`, rewritten `9b529f2` | ✅ `9b529f2` | — | — |

**Update, 2026-08-18:** `RTL-SIM-PASS` achieved for FETCH_PAIR (real
`iverilog`, not the Python model) -- but not on the first attempt, and
not for the reason the MODEL-PASS caveat below anticipated. The
original `tb_fetch_pair.sv` (as committed at `8c4a12b`) never actually
*compiled* under iverilog: two real bug classes, both in the
testbench, not the RTL it was meant to exercise.

1. **White-box FSM bypass doesn't work against the real module
   hierarchy.** The testbench tried `dut.boot_done = 1;` and
   `dut.u_ctrl.state = 5'd0;` to skip the UART bootloader and seed FSM
   state directly. `boot_done` is a wire continuously driven by the
   bootloader submodule's own output port -- iverilog rejects a
   procedural assignment to it outright (`Cannot perform procedural
   assignment ... because it is also continuously assigned`). `state`
   is enum-typed (`state_t`, declared inside `control.sv`); assigning a
   bare bit literal to it needs an explicit cast, and there is no way
   to name `state_t` hierarchically from a testbench to write that
   cast. Fix: load the test program through the real UART bootloader,
   the same pattern every other testbench in this repo already uses,
   instead of white-box-poking internal FSM state.
2. **Instruction encoding was backwards.** `encode_3r`/`encode_imm`
   built words as `{16'b0, rs2, rs1, rd, op}` (opcode in the low 4
   bits) but `instruction_decoder.sv`'s real layout is opcode in the
   *high* 4 bits (`[31:28]`), `rd`/`rs1`/`rs2` descending, `imm` in
   `[15:0]`. Every encoded instruction in the original testbench was
   silently wrong. `OP_CONS`/`OP_CAR`/`OP_HALT`'s numeric values were
   also wrong (compared against `instruction_decoder.sv`'s actual
   `opcode_t` enum) -- the exact class of bug this file's own original
   header comment warned about for `TAG_*` constants, this time hitting
   `OP_*` instead.

Once both were fixed, the real RTL confirmed correct on the first
subsequent run: `R4=10` (CAR), `R5=20` (CDR), `R6=123` (PC not
skipped) -- matching every number this report's Test 1 (below) already
predicted from the Python model. **The FETCH_PAIR RTL itself was
correct all along; every bug found on 2026-08-18 was in the testbench,
not the hardware being tested.** Full 33-testbench regression suite
also re-run clean afterward (`tb_cons` through `tb_bootstrap_equal`,
M02-M32 plus G8), confirming no other regression from either this fix
or anything committed since `5bcc99c`.

**Original note (2026-08-17, still true about the process, not the
current state):** MODEL-PASS is based on a Python behavioral model that
reproduces the FSM from `control.sv` and the heap logic from
`lisp_data_unit.sv`. This is not the same claim as a real RTL
simulation -- and the gap between the two turned out to be real, not
theoretical: the model apparently didn't (or couldn't) catch either bug
above, since both are specific to how iverilog elaborates real
SystemVerilog module hierarchies and enum types, not to the FSM/heap
*logic* the Python model was reproducing.

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

1. ~~**RTL simulation**~~ — done 2026-08-18, see the epistemic-state
   update above. `RTL-SIM-PASS` for FETCH_PAIR confirmed via real
   `iverilog`.
2. **Synthesis** — real Gowin synthesis has been run since this report
   (`fpga/synth/build.tcl` via `gw_sh.exe`, `ecosystem-status.md`
   2026-08-13 entry: `Fmax=60.801MHz`, zero negative slack, BSRAM
   24/56) but not specifically re-checked against the FETCH_PAIR fix's
   own commit -- worth re-running given RTL changed since that
   synthesis pass.
3. **Hardware** — real board flash is blocked on an unresolved FTDI
   VCP-vs-D2XX JTAG driver conflict, not on anything in this report;
   see `docs/hardware-setup.md`.
4. **Edge case: rd == rs2** — FETCH_PAIR with identical destinations
   (CAR gets overwritten by CDR). This is an illegal encoding that
   should be rejected by the assembler, but is not yet enforced.
5. ~~**Existing regression tests**~~ — done 2026-08-18: full
   33-testbench suite (`tb_cons` through `tb_bootstrap_equal`) re-run
   clean, real `iverilog`, no regressions found.

## Commit history

| SHA | Description |
|-----|-------------|
| `0fdfb82` | feat: performance counters (6 counters, monitor 0x05–0x0A) |
| `2d4a455` | fix: heap off-by-one — all 4096 cells now usable |
| `8c4a12b` | test: add tb_fetch_pair.sv regression test |
| `5bcc99c` | fix: remove double PC++ in FETCH_PAIR |
| `9b529f2` | fix: tb_fetch_pair.sv — real RTL-SIM-PASS, not just MODEL-PASS (2026-08-18) |
