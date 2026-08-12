# AGENTS.md — ecosystem overview for agents working in this repo

This repo (`fpga-lisp`) is one of four in a coordinated ecosystem. If you're
an agent (Codex, Claude Code, or otherwise) picking up work here, read this
first — it saves you from re-deriving context another agent already has.

## Session start — join the swarm

Before anything else, connect to the shared coordination medium
(`127.0.0.1:9999`, my-lisp's TCP server, P2P — no agent relays for
another; see my-lisp's `docs/swarm-autonomy.md`/`docs/swarm-coordination.md`
for the full design):

1. `sync-tasks` this repo's `tasks.my` (**absolute path** — the op reads
   the file relative to the *server's* cwd, not the caller's; a relative
   path silently syncs whatever file of that name happens to exist there
   instead, which is not an error you'll be told about).
2. `hello` with capabilities, once per session.
3. `next-best-action` to see what's actionable before assuming you know.

Example (`--connect` client mode, my-lisp v0.15.0+):
```
printf '%s\n' '(request (id 1) (op sync-tasks) (file "/mnt/c/GitHub/fpga-lisp/tasks.my"))' \
  | my-lisp --connect=127.0.0.1:9999
```
`tasks.my` is this repo's plan of record (durable, git-tracked) — edit it
to change what this agent is doing, re-`sync-tasks` after edits and after
any server restart (the in-memory registry wipes on restart). An event
from the swarm (`publish`/`capability-request`) is a doorbell, never the
fact itself — always verify against the actual `evidence/`/commit before
acting on one.

## The four repositories

- **my-lisp** — the semantic source of truth. Defines the language: parser,
  evaluator, exactness model (rationals, no floats), `lib/core.my` standard
  library. Language contract version 1.0 (`language-contract.my`). Nothing
  else in the ecosystem may drift from what that repo says the language
  means.
- **fpga-lisp** (this repo) — hardware implementation of the same language
  on an FPGA. Tracks an ISA contract (`isa-contract.my`, version 1.0)
  against my-lisp's semantics. Milestone-by-milestone bootstrap history and
  the current plan queue position live in `docs/lisp-machine-plan.md` —
  that file is the current, authoritative status; don't infer progress
  from this one, which only describes timeless roles and conventions. CI
  (`.github/workflows/ci.yml`) runs every `fpga/sim/tb_*.sv` testbench
  through real `iverilog` on push/PR, mirroring cml's setup; the exact
  list is kept in sync with `docs/testing.md`.
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
  artifact — assemble first with `python3 assembler.py <name>.asm`; the
  Guix `manifest.scm` environment has no `python` alias, only `python3`).
- Two assemblers exist: `assembler.py` (authoritative today, what CI and
  every testbench actually use) and `assembler.my` (a from-scratch
  reimplementation in the language itself, not wired into CI or any
  testbench). **`assembler.my` is currently non-functional, not just
  unverified**: a differential test against `assembler.py` (2026-08-12,
  see `ecosystem-status.md`) found it produces inconsistent results on
  the exact same trivial input (`call_demo.asm`, 8 lines) across two
  otherwise-identical invocations -- once a silent 0-byte output
  claiming "Assembled 0 instructions" (wrong; the file has real
  instructions), once a native stack overflow crash. Every other tested
  `.asm` file (including every `bootstrap_*_demo.asm`) crashed the same
  way. Root cause not isolated -- plausibly a my-lisp interpreter
  stack-depth issue triggered by `assembler.my`'s own non-tail-recursive
  helpers (`nth`, `contains?`), not necessarily a bug in the assembler's
  own logic. Until root-caused and fixed, treat `assembler.my` as **not
  usable at all**, not as "a second encoder to cross-check against" --
  there is currently nothing working to compare.
- `docs/testing.md` documents the full local test-running command and the
  per-milestone table; keep it in sync with `docs/lisp-machine-plan.md`
  when a milestone lands.
- Running a testbench takes real wall-clock time (VCD dumping of the full
  heap array is the dominant cost, not the logic itself) — don't assume a
  quiet terminal for tens of seconds means a hang; `$display` output is
  fully buffered when stdout is redirected to a file, so nothing appears
  until the process exits or the buffer fills. Check VCD file growth as a
  progress signal before concluding something is stuck.

## Environment: WSL2 + Guix

Work in this repo from inside WSL2, under the Linux user named after this
repo (`fpga-lisp`), not directly from Windows. Enter the declared
environment before running anything:

```
wsl -u fpga-lisp
cd /mnt/c/GitHub/fpga-lisp
guix shell -m manifest.scm
```

`manifest.scm` pins `iverilog`/`yosys`/etc. to known-good versions; don't
rely on whatever happens to be on `$PATH` outside the shell.

## Cross-session coordination protocol (agreed with cml/my-lisp)

1. Durable facts go in `ecosystem-status.md` (this repo) /
   `ecosystem-status.my` (my-lisp) — written after the fact (commit done,
   CI green), not "plan to do X".
2. Direct messages between sessions are for synchronous asks, not
   restating what's already in a status file.
3. Anchor claims to a commit sha or file:line, not a paraphrase from memory.
4. Don't block on confirmation before continuing your own work unless
   there's a real dependency.
