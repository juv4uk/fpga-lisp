# Ecosystem status

Append-only durable log for cross-repo coordination with `my-lisp` and
`cml`, per the protocol agreed 2026-08-11 (see commit history — this
file records facts after they land, not intentions). Each entry: date,
what happened, commit anchor. Don't edit past entries except to correct
an error; add a new entry instead of restating one.

## 2026-08-11

- **Plan queue position**: fpga-lisp's numbered plan (`docs/lisp-machine-plan.md`
  line ~396) has item 24 "recursion" before item 25 "rational/bignum".
  `letrec`/self-referential-closure recursion (M28/M29) **is** item 24,
  not a separate later item — it is already ahead of rational/bignum in
  the queue, in progress now. Rational/bignum has not started.
- **M28** (`447ee0e`): `letrec` mechanism proven (placeholder-pair +
  `SETCDR` backpatch) via a simplified, non-tail-recursive `length`.
  Confirmed against my-lisp's `lib/core.my` to differ from the canonical
  tail-recursive form — documented as a deliberate simplification, not
  full parity.
- **M29 WIP** (`cec7889`): canonical tail-recursive, mutually-recursive
  `length`/`length-onto` pair, two letrec placeholders sharing one env
  frame. Not yet machine-verified when committed (no local Python/
  iverilog on this machine at the time).
- **CI added** (`9e9ea06`): `.github/workflows/ci.yml` now runs every
  `fpga/sim/tb_*.sv` testbench (including M28/M29) through Icarus
  Verilog on every push/PR, mirroring cml's GitHub Actions setup
  (`6b884a8`, `1ba61dc`). Check the Actions tab on `juv4uk/fpga-lisp`
  for the current pass/fail state of M29 rather than trusting this
  entry's date — CI results are the live source of truth, this file
  isn't.
- **Communication protocol** agreed with cml and my-lisp: durable facts
  go in each repo's own `ecosystem-status.md`/`.my` after landing;
  direct cross-session messages are for synchronous questions not
  answerable from committed files; anchor claims to commit sha/file:line
  instead of restating content; don't block on a reply unless there's a
  real dependency.
- **CORRECTION to the M28 entry above**: installed Python + `iverilog`
  locally this session (disk space, previously the blocker, turned out
  to be resolved — 465GB free) and ran M28 for real for the first time.
  It does NOT pass: halts normally (not a hang, `$finish` at simulated
  time 113021940, well under the 150M watchdog) but `R9` = `TAG:SYMBOL
  VAL:920` (leaked param symbol `'lst`) instead of `TAG:FIXNUM VAL:3`.
  A full 16-register dump at halt shows `R11` (software call stack) is
  non-`NIL` — an unbalanced push/pop, only reachable at real 3-deep
  self-recursion (no earlier milestone exercised that depth). Root
  cause not yet isolated. Treat the earlier "M28: letrec mechanism
  proven" entry as retracted until a real passing run is recorded here
  with a commit sha. M29 is blocked on the same bug.
- **SECOND CORRECTION — root cause found, both M28 and M29 now PASS for
  real**: the "unbalanced R11" symptom was a red herring from reading
  garbage state after an unrelated failure, not an actual push/pop bug
  in `eval_core.inc`. Root cause: `bootstrap_length_demo.asm` (and
  `bootstrap_length_onto_demo.asm`, copied from it) passed the literal
  test list `(a b c)` as a call argument WITHOUT `(quote ...)`. Call
  arguments are always evaluated, so `(a b c)` was evaluated as code —
  applying the symbol `'a` as an operator, whose unbound `lookup` walks
  off into `NIL`, and `CAR` of `NIL` is an LDU type error, which halts
  the machine (cleanly, per M17) but leaves registers holding whatever
  they last held — hence the misleading `R9 = symbol 'lst`. Every
  earlier bootstrap demo (`bootstrap_second_demo.asm`,
  `bootstrap_pair_demo.asm`, `bootstrap_triple_demo.asm`) quotes its
  literal-list test data for exactly this reason; M28/M29 didn't. Fixed
  by wrapping the test list in `(quote (a b c))` in both files. Reran
  both locally with real `iverilog`: **M28 PASSED** (`R9 = TAG:FIXNUM
  VAL:3`, `$finish` at simulated time 115224960) and **M29 PASSED**
  (`R9 = TAG:FIXNUM VAL:3`, `$finish` at simulated time 121180340). The
  `letrec`/`SETCDR` self-recursion mechanism was correct from the start
  in both files — the bug was entirely in how test data was passed, not
  in the mechanism the milestones exist to prove. Fix commit: (pending —
  see the next commit on `master` after this entry lands).

## 2026-08-12

- **M31 (`append`) and M32 (`equal?`) PASSED**, both on first real
  `iverilog` run (`4a4f032`, `4a218fb`). `append` built on M30's
  `reverse`/`reverse-onto` letrec pair, not self-referential, no third
  placeholder needed. `equal?` is self-referential (single letrec
  placeholder, like M28) and is the first bootstrap demo with a
  three-clause top-level `cond` (M28-M31 all had two). Both cross-checked
  against my-lisp's TCP `--protocol=sexpr` oracle before/after writing
  the asm.
- **`assembler.my` found non-functional** (differential test against
  `assembler.py`, not committed): the exact same command
  (`my-lisp assembler.my call_demo.asm out.bin`) produced a silent
  0-byte output claiming "Assembled 0 instructions" on one invocation
  and a native stack overflow crash on another, for the same trivial
  8-line input. Every other `.asm` tested (all `bootstrap_*_demo.asm`)
  crashed with stack overflow. Not isolated to a root cause yet —
  plausibly a my-lisp interpreter stack-depth issue from
  `assembler.my`'s own non-tail-recursive helpers, not necessarily a bug
  in the assembler's encoding logic. `assembler.py` remains the sole
  working assembler; `assembler.my` is not currently a valid
  cross-check target (see `AGENTS.md`'s note on this).
- **First real end-to-end `length` PASSED** (reported by cml via mailbox,
  confirmed here): the full `my-lisp -> cml -> fpga-lisp` pipeline ran
  `(length '(a b c))` and got `RESULT_VAL:3` through `tb_cml_e2e.sv`,
  matching the my-lisp TCP oracle exactly. This is the milestone the
  cross-repo coordination was originally set up to prove. It had looked
  like a hang in earlier runs — root cause found and fixed here:
  `tb_cml_e2e.sv`'s watchdog was still `70_000_000` (every other
  testbench in this repo already uses `150_000_000`), and UART load time
  for a ~200+-instruction binary (~69.6M time units to shift in over the
  bit-banged link, before execution even starts) landed right at that
  ceiling. Bumped to `300_000_000` for headroom against larger
  cml-compiled programs. Not a hardware or compiler bug — evidence should
  still be filed per my-lisp's proposal (`evidence/length/cml/<sha>.my`,
  `evidence/length/fpga-lisp/<sha>.my`) once cml re-confirms with the
  fixed watchdog.

- **FPGA-HARDWARE-VERIFY-M17-M32: synthesis/timing re-checked, actual
  board flash still pending.** Owner installed Gowin IDE + Programmer
  (`C:\Gowin\Gowin_V1.9.12.03_x64`). Ran `fpga/synth/build.tcl` via
  `gw_sh.exe` (headless) against the current RTL (everything through
  M32) — synthesis, place-and-route, and bitstream generation all
  completed with no errors. Resource usage: BSRAM 24/56 (43%), matches
  the number the plan doc already derived from real synthesis at M18's
  imem expansion. Timing: `Fmax = 60.801 MHz` against the `50 MHz`
  constraint (`lisp_machine.sdc`), **Total Negative Slack: none** — no
  timing violations. Down from M16's `64.6 MHz` measurement (expected:
  design grew substantially, M17-M32's eval/letrec/bootstrap logic all
  added since), but still well clear of the 50 MHz requirement. Actual
  flash-and-run verification on the physical Tang Primer 25K is still
  outstanding — no board detected on any USB-serial COM port as of this
  entry (only `COM1`, the legacy motherboard port), and the reset-button
  step in `upload.py`/`monitor.py`'s flow needs a human regardless of
  whether the board is connected. Once the board is plugged in, running
  M28-M32's bootstrap demos through `monitor.py` for real is the
  remaining half of this task.

## [fpga-lisp] 2026-08-24 — JTAG blocker closed; first M17-M32-era hardware smoke

- Windows enumerated both FT2232 parent channels; Channel A parent and Channel
  B/COM4 were healthy, while the Channel A VCP child COM3 remained disabled.
- Gowin `--scan-cables` found two `USB Debugger A` locations. Read-only scan at
  location 449 opened JTAG and identified one physical GW5A-25A-family device,
  ID `0x0001281B`.
- `operation_index 2` programmed volatile SRAM to 100% from
  `impl/pnr/project.fs` (SHA-256
  `557bbe28190611e3785475a2755a717d5be6a50c25ff88acb0002da6182dfe3a`),
  reporting User Code `0x00008DFD`, Status `0x70026020`, `Finished`.
- Native Windows `monitor.py` uploaded `bootstrap_add_demo.bin` over COM4 (280
  instructions). Physical result: `R9 = FIXNUM(7) [0x00000007]`; error channel:
  `ERR: no error (halted normally via HALT)`.

This closes the JTAG/UART transport blocker and confirms the `(plus 3 4)` eval
path on real hardware. It does **not** yet claim blanket M17-M32 verification;
the remaining bootstrap demos still require their own physical observations.

## [fpga-lisp] 2026-08-24 — CML binary job bridge M2c

- Added `job_transport.py`, a native-Windows pyserial adapter for CML's
  versioned binary stdin/stdout command transport. It reuses the established
  bootloader/monitor bytes and delayed input-buffer reset workaround; no new
  ISA or language semantics were introduced.
- Protocol unit tests cover valid CML v1 framing plus truncated/version-drift
  rejection. Windows PnP currently reports Converter B and COM4 healthy.
- The operator-gated physical CML Execution Graph test subsequently passed in
  13.37 seconds after a manual RESET: `bootstrap_add_demo.bin` returned R9 raw
  tagged word `0x00000007`, hardware error clear, and CML published
  `GraphValue::LispWord(7)`. Scope remains one live graph program path, not
  blanket FPGA conformance.
- Witness follow-up corrected the contract-3.0 wire vocabulary table with
  `division-by-zero`/`DivisionByZero` and `parse-error`/`Parse`, plus stale
  `core.my` snapshot comments. The canonical 3.0 fixture copy is explicitly a
  reference/gap-accounting corpus, not a claim that the FPGA backend has moved
  beyond its declared contract 2.0 surface.
