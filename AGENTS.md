# AGENTS.md — ecosystem overview for agents working in this repo

This repo (`fpga-lisp`) is one of four in a coordinated ecosystem. If you're
an agent (Codex, Claude Code, or otherwise) picking up work here, read this
first — it saves you from re-deriving context another agent already has.

## Session start — join the swarm

Coordination lives on `swarm-node` (a separate binary from `:9999`), a P2P
mesh — no agent relays for another. `127.0.0.1:9999` (my-lisp's TCP
server) is still the **semantic oracle** (`eval`/`parse`/`diagnose`) and
hasn't moved, but its `hello`/`claim`/`subscribe`/`notify`/task-registry
ops are no longer the coordination path (migrated 2026-08-12, see
my-lisp's `docs/swarm-mesh-v2.md`). Don't poll/claim through `:9999`
for coordination — use it only for semantic queries.

fpga-lisp's own node, once started, is `fpga-lisp-1` on `127.0.0.1:9103`
(port/node-id not auto-discovered — check `ps aux | grep swarm-node` for
whether it's already running before starting a second one). To start it
fresh and join:

```bash
swarm-node --port 9103 --node-id fpga-lisp-1 --project fpga-lisp \
           --data-dir ~/.swarm-node/fpga-lisp-1 --connect 127.0.0.1:9101
```
(`127.0.0.1:9101` is my-lisp's own node — bootstrap through any one
existing member, gossip connects you to the rest.) Then, sent as raw
sexpr lines to your *own* node's port (9103, not 9101):

```
(join (capabilities (verilog isa-design fpga iverilog assembly-testing fpga-lisp)) (roles (voter)))
(sync-tasks (file "/mnt/c/GitHub/fpga-lisp/tasks.my"))
```

`(join ...)` once per session. `sync-tasks` needs an **absolute path**
(same gotcha as the old `:9999` op: relative resolves against the
*node's* cwd, not the caller's). `tasks.my`'s field is `description`, not
`context` — a wrong field name is silently dropped, not an error.
`(next-best-action (node fpga-lisp-1))` to see what's actionable.
`tasks.my` is this repo's plan of record (durable, git-tracked) — edit it
to change what this agent is doing, re-`sync-tasks` after edits. An event
from the swarm is a doorbell, never the fact itself — always verify
against the actual `evidence/`/commit before acting on one.

## The four repositories

- **my-lisp** — the semantic source of truth. Defines the language: parser,
  evaluator, exactness model (rationals, no floats), `lib/core.my` standard
  library. Language contract version **2.0** as of 2026-08-15
  (`language-contract.my`'s own `(major . 2) (minor . 0)` -- don't trust a
  number in this prose file over that one; re-check it directly if it's
  been a while). The 1.0->2.0 break removed `'` as a reader shorthand for
  `quote` (now part of symbols) -- a *syntax*-level change. fpga-lisp has
  no reader (every `.asm` demo builds `(quote x)` cons-forms directly, not
  via `'`-parsing), so this specific break doesn't touch anything on the
  hardware side, but the version number in this file still needed fixing
  per the rule that prose never outranks a machine-readable contract.
  Nothing else in the ecosystem may drift from what that repo says the
  language means.
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
- Only `assembler.py` is a migration-to-Lisp candidate, not
  `upload.py`/`monitor.py`. See `docs/tooling-language-priority.md` for
  the full reasoning before proposing otherwise -- short version: Lisp
  migration makes sense for tools that transform Lisp data (assembling
  text into the machine's own tagged words), not for tools that operate
  physical UART hardware (`my-lisp` deliberately has no serial-I/O
  primitives, and adding them just for this repo's tooling would be
  extending the language's scope for the wrong reason).
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

## Agent Guard (M0 — PROPOSED, 2026-08-22)

План executable-constitution guardrails для агентських сесій:
`/home/agents/ecosystem/plans/AGENT-GUARD-M0.md`

Машинні гачки на C1/C7/C9/C11 (ox-alpha constitution v1.2):
tool wrapper + evidence ledger + claim gate. Статус: план,
реалізація не почата. Агенти, що заходять у репо: прочитайте
план перед write-heavy роботою; зауваження — у plans/ або
власнику напряму.


## NLP / Embeddings tooling (2026-08-22)

Для NLP-задач (ембедінги, семантична класифікація, BGE-M3): системний
python3 НЕ має torch. Використовуй
`/home/agents/GitHub/FlagEmbedding/.venv/bin/python`.
Конфіг і готові індекси: `/home/agents/GitHub/vault-semantic-mcp/`
(корпусні ембедінги вже в `data/sanskrit_embeddings.jsonl` — перевикористовуй).
GPU лише 4GB — батчі ≤4, fp16, не перераховувати зайве.
Повний рецепт: `/home/agents/ecosystem/memory/nlp-tooling-setup.md`.
