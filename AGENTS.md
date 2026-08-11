# AGENTS.md — ecosystem overview for agents working in this repo

This repo (`fpga-lisp`) is one of four in a coordinated ecosystem. If you're
an agent (Codex, Claude Code, or otherwise) picking up work here, read this
first — it saves you from re-deriving context another agent already has.

## The four repositories

- **my-lisp** — the semantic source of truth. Defines the language: parser,
  evaluator, exactness model (rationals, no floats), `lib/core.my` standard
  library. Language contract version 1.0 (`language-contract.my`). Nothing
  else in the ecosystem may drift from what that repo says the language
  means.
- **fpga-lisp** (this repo) — hardware implementation of the same language
  on an FPGA. Tracks an ISA contract (`isa-contract.my`, version 1.0)
  against my-lisp's semantics. Plan queue: `docs/lisp-machine-plan.md`'s
  item 24 "recursion" (letrec-in-closures) is currently in progress and
  comes *before* item 25 "rational/bignum" — not a separate later item.
  M28 (`447ee0e`) proves the `letrec` mechanism (placeholder-pair +
  `SETCDR` backpatch) via a simplified non-tail-recursive `length`; M29
  (`cec7889`) bootstraps the canonical tail-recursive, mutually-recursive
  `length`/`length-onto` pair `core.my` actually uses. Both are now
  confirmed by a real `iverilog` run (2026-08-11, `R9 = TAG:FIXNUM
  VAL:3`) — an earlier same-day attempt at this claim was wrong (based on
  hand-tracing only) and briefly retracted after a real run surfaced a
  bug, but the bug turned out to be a missing `(quote ...)` around the
  demo's literal test-list argument (evaluated as code instead of data),
  not the `letrec` mechanism itself. See `docs/lisp-machine-plan.md`'s
  M28/M29 entries for the full postmortem before assuming anything about
  this history from memory. CI
  (`.github/workflows/ci.yml`) runs every `fpga/sim/tb_*.sv` testbench
  through real `iverilog` on push/PR, mirroring cml's setup.
- **cml** — an AOT compiler from my-lisp source to fpga-lisp's ISA. Tracks
  conformance against both other repos (`compatibility.my`). Has CI
  (`.github/workflows/`) running real `iverilog` E2E simulation.
- **my-idea** — an observer/IDE layer, depends on my-lisp via
  cargo-git-dependency/submodule. Building toward a "System Observatory"
  panel.

## Machine-readable status

`ecosystem-status.md` in this repo is an append-only prose log — current
status, refreshed after each cross-session sync, anchored to commit shas.
Read it before assuming anything here is stale or unverified. my-lisp's own
`ecosystem-status.my` (a flat alist, `(read-file "ecosystem-status.my")`) is
the equivalent machine-readable view for the whole ecosystem.

## my-lisp G8 truth semantics

ISA 1.0 makes `JF` branch only on `NIL`, matching my-lisp's G8 axiom.
Fixnum `0` is truthy. [`fpga/sim/tb_jf_truthiness.sv`](fpga/sim/tb_jf_truthiness.sv)
checks both sides of this contract directly through the bootloader and RTL.

## Conventions worth knowing before editing

- `isa-contract.my` is **data, not code** — a flat alist, read via
  `(read-file ...)`, never `(load ...)`-ed as executable source.
- No opcode is added lightly: the 4-bit opcode field has been full (16/16)
  since `LOADSYM`. `CALL`/`RET` and `GETTAG`/`MAKEPRIM`/`GETVAL` extend
  existing opcodes (`JMP`, `MOV`) via unused instruction fields rather than
  consuming new slots — check `docs/lisp-machine-plan.md`'s status section
  and commit history before assuming a new instruction is the only way to
  add a capability.
- Every `.asm` bootstrap demo has a corresponding `fpga/sim/tb_*.sv`
  testbench that `$fread`s its assembled `.bin` (gitignored build
  artifact — assemble first with `python assembler.py <name>.asm`).
- `docs/testing.md` documents the full local test-running command and the
  per-milestone table; keep it in sync with `docs/lisp-machine-plan.md`
  when a milestone lands.
- Running a testbench takes real wall-clock time (VCD dumping of the full
  heap array is the dominant cost, not the logic itself) — don't assume a
  quiet terminal for tens of seconds means a hang; `$display` output is
  fully buffered when stdout is redirected to a file, so nothing appears
  until the process exits or the buffer fills. Check VCD file growth as a
  progress signal before concluding something is stuck.

## Cross-session coordination protocol (agreed with cml/my-lisp)

1. Durable facts go in `ecosystem-status.md` (this repo) /
   `ecosystem-status.my` (my-lisp) — written after the fact (commit done,
   CI green), not "plan to do X".
2. Direct messages between sessions are for synchronous asks, not
   restating what's already in a status file.
3. Anchor claims to a commit sha or file:line, not a paraphrase from memory.
4. Don't block on confirmation before continuing your own work unless
   there's a real dependency.
