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
- A second operator-gated live test placed the board after CPU and CUDA nodes
  in one CML dependency graph. It passed in 14.61s with order CPU → CUDA → FPGA,
  buffer results `[2,3,4]` then `[3,4,5]`, and FPGA tagged word `7`. At that
  checkpoint the scope was coordinated scheduling only; M36 subsequently
  proved the explicit host-staged buffer-to-register path. Direct device-to-
  device GPU→FPGA transfer remains absent.

## [fpga-lisp] 2026-08-24 — M33 extended boot register inputs

- ISA contract advanced backward-compatibly from 1.0 to 1.1. Legacy program
  images retain their exact two-byte word-count header and program bytes.
- Header bit 15 now selects an extended frame with up to 16 `(register,
  u32-le tagged-word)` initializers before the unchanged program image.
- RTL simulation initializes R0=FIXNUM(3), R1=FIXNUM(4), then executes
  `ADD R2,R0,R1; HALT` and observes R2=FIXNUM(7). This is simulation evidence
  for a host-staged input path, not yet physical-board or CML payload evidence.
- Targeted legacy simulations (`tb_machine`, `tb_jf_truthiness`, `tb_monitor`)
  pass. The full regression was intentionally deferred to CI under the owner
  resource policy rather than consuming the interactive machine locally.

## [fpga-lisp] 2026-08-24 — M34 CML register-input bridge parsing

- `job_transport.py` now validates ISA 1.1 extended frames from CML: reserved
  header bits, 1..16 unique R0..R15 inputs, exact frame length, and unchanged
  legacy framing. Tagged words remain opaque at the bridge boundary.
- Four targeted Python protocol tests pass, including extended-frame
  preservation and duplicate-register rejection. This proves host bridge
  parsing only; no new physical-board payload observation is claimed.

## [fpga-lisp] 2026-08-24 — M35 physical CML ISA 1.1 register-input proof

- On the permanently flashed board at COM4, the Windows `job_transport.py`
  bridge accepted the corrected 21-byte ISA 1.1 frame: R0=FIXNUM(3),
  R1=FIXNUM(4), `ADD R2,R0,R1`, `HALT`.
- After an operator S1/RESET, the bridge returned `CMLR` protocol version 1
  with result word `0x00000007` and error status `0x00000000` (14 seconds,
  2026-08-24). This is one live physical path proving CML payload delivery
  and tagged register initialization; it is not blanket backend conformance.

## [fpga-lisp] 2026-08-24 — M36 host-staged CUDA-to-FPGA input proof

- CML's heterogeneous live graph executed CPU → CUDA → FPGA in 14.17 seconds.
  CUDA produced the host-visible typed buffer `[3,4,5]`; the explicit CML
  adapter staged it into ISA 1.1 register inputs, and the FPGA ran
  `ADD R2,R0,R1; HALT`, returning tagged word `7` with no hardware error.
- This proves one host-staged buffer-to-register path across the three
  backends. Direct device-to-device GPU→FPGA transfer, shared memory, and
  blanket heterogeneous conformance remain unproven by design.

## [fpga-lisp] 2026-08-24 — permanent ISA 1.1 image and cold-boot proof

- Gowin EDA synthesized repo commit `092aa3b` into
  `impl/pnr/project.fs` (6,604,065 bytes, SHA-256
  `4a5ba486c4592c75db9d261641b219d9f2608706abbc8dacc53931099dffdb9b`).
  Place-and-route reports `Fmax = 66.727 MHz` at the 50 MHz constraint,
  setup/hold TNS `0.000`, BSRAM 24/56, 1,692 LUTs and 1,207 registers.
- Gowin Programmer operation 54 (`exFlash Erase,Program,Verify Arora V`) at
  confirmed JTAG location 449 detected SPI flash `0x0B4017`, programmed and
  verified it successfully, and finished in 35.12 seconds.
- The board was then disconnected from USB power for at least five seconds
  and reconnected. A new JTAG scan identified GW5A-25A-family device
  `0x0001281B`; native Windows `monitor.py` uploaded the 280-instruction
  `bootstrap_add_demo.bin` over COM4 and observed
  `R9 = FIXNUM(7) [0x00000007]` with `ERR: no error`.
- Scope: this is live evidence that this exact image boots from persistent
  external flash and executes one `(plus 3 4)` path. It is not blanket ISA,
  language-contract or M17-M34 hardware conformance.

## [fpga-lisp] 2026-08-24 — symbolic LOADSYM assembler bridge

- `assembler.py` now accepts symbolic `LOADSYM Rn NAME` operands and assigns
  deterministic per-program tagged-symbol IDs starting at 900; existing
  numeric operands remain unchanged.
- The CLI writes a `<output>.sym` sidecar when symbols were interned, giving
  monitor/debug tooling the name map without introducing a global symbol ABI.
- Six Python assembler/protocol tests pass. This is a host-tooling bridge,
  not a change to ISA 1.1 or language semantics.

## [fpga-lisp] 2026-08-24 — my-lisp assembler parity gate reopened

- The historical `assembler.my` stack-overflow/0-byte observation is no
  longer reproduced with the current release `my-lisp` binary.
- Seven representative fixtures now produce byte-identical binaries to
  `assembler.py`: call (5 instructions), bootstrap add (280), pair,
  tail-recursive length, equality, lambda, and quote paths.
- `tests/test_assembler_my_parity.py` records this as a repeatable gate.
  Python remains the bootstrap/reference encoder until more fixtures pass;
  `upload.py` and `monitor.py` remain host-side Python infrastructure.
