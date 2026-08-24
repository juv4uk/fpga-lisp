# Tooling language priority: which host tools should move to Lisp

Analysis written 2026-08-12, after `assembler.my` (a from-scratch
reimplementation of `assembler.py` in `my-lisp` itself) surfaced the
question of whether the repo's other two Python tools (`upload.py`,
`monitor.py`) should follow. Answer: no, and this document records why,
so the question doesn't get re-litigated from scratch by a future agent.

## Inventory

| Tool | Lines | What it does | I/O beyond files |
|---|---|---|---|
| `assembler.py` | 235 | `.asm` text → `.bin` bytes | none |
| `upload.py` | 135 | Uploads a `.bin` over UART, waits for reset | `pyserial` (physical serial port) |
| `monitor.py` | 135 | Post-`HALT` binary debug REPL over UART | `pyserial` (physical serial port) |

## The dividing line

**Migrate to Lisp where the tool transforms Lisp data. Don't, where the
tool operates hardware.**

`assembler.py` reads `.asm` text and produces the exact 32-bit tagged
words this machine's ISA is built from — it is, in a real sense, itself
a Lisp-shaped computation (parse, symbol table, encode), and porting it
to `my-lisp` is the same self-hosting principle the machine's own
`eval`/`lookup`/`letrec` bootstrap already follows: the tool that builds
programs for the Lisp machine, written in Lisp.

`upload.py`/`monitor.py` are not transformations of Lisp data at all —
they are physical UART/serial-port control: baud rates, reset-button
timing windows, byte-level protocol framing over `pyserial`. This is
infrastructure a developer's machine needs to talk to the board, not a
capability of the language being demonstrated.

## Why not migrate upload.py/monitor.py anyway

1. **`my-lisp` deliberately has no process/serial I/O primitives.**
   `assembler.my`'s own header comment notes `my-lisp.exe
   --allow-process=... is NOT needed (no process-run here)` — the
   language is scoped to pure computation plus file read/write, not
   arbitrary host I/O. Adding serial-port primitives to the language
   just to satisfy this repo's tooling would be extending `my-lisp`'s
   surface area for a use case outside its own stated scope, not a
   capability worth having for its own sake.
2. **The plan document already draws this exact line, for a different
   language.** `docs/lisp-machine-plan.md`'s "`my-lisp` ↔ FPGA" section:
   "Rust — інструмент розробника, не runtime" (Rust is a developer tool,
   not the runtime). The same reasoning applies to Python here: a host
   tool that talks to the board over UART is developer infrastructure,
   regardless of which language it happens to be written in. There is
   no principled reason the *choice of implementation language* for
   that infrastructure needs to match the machine's own language.
3. **The alternative (FFI/shell-out from my-lisp to a serial library)
   is strictly worse.** It would add complexity and fragility for zero
   architectural benefit — nothing about the machine, the ISA, or the
   language gets proven or exercised by moving a `pyserial` wrapper into
   Lisp syntax.

## Priority summary

## Comparative evidence

The first apples-to-apples guard benchmark ran 2026-08-25 after a resource
preflight (load 1.24, 2.5 GiB available RAM; GPU visibility unavailable in
this sandbox). Both implementations checked the same live contracts and
returned success; `tests/test_stale_refs_my_parity.py` verifies that parity.
Twenty fresh process invocations measured:

| implementation | wall time | peak RSS |
|---|---:|---:|
| Python `check_stale_refs.py` | 0.89 s | 12,020 KB |
| release my-lisp `check-stale-refs.my` | 14.00 s | 3,328 KB |

This is a real loss for my-lisp on this small cold-start CLI workload (~15.7×
slower), while the self-hosted path uses less peak memory (~3.6× lower). It is
not a reason to add host-specific primitives or to hide the result. If this
tool becomes a frequent path, startup/reader/process-launch overhead is the
next my-lisp optimization target; Python remains the justified bootstrap
default until then.

- **`assembler.py` → `assembler.my`**: real, already in progress
  (`FPGA-ASSEMBLER-DIFF-TEST` in the swarm task registry). The historical
  stack-overflow/0-byte failure is no longer reproduced: on 2026-08-24 the
  release my-lisp binary emitted byte-identical output for `call_demo.asm`
  (5 instructions) and `bootstrap_add_demo.asm` (280 instructions). The
  Python implementation remains the bootstrap/reference path until the
  differential fixture set is expanded; `tests/test_assembler_my_parity.py`
  now makes this migration gate executable. The gate covers all 29 `.asm`
  fixtures currently in this repository, including bootstrap, evaluator,
  monitor, memory, control-path, and symbolic `LOADSYM` programs. This
  establishes assembler parity, including the `.sym` sidecar, not full
  language-contract conformance.
- **`check_stale_refs.py` → `check-stale-refs.my`**: the self-hosted guard now
  reads the machine-readable ISA and language contracts, scans only explicit
  prose version claims, and fails closed on drift. `tests/test_stale_refs_my_parity.py`
  compares its current exit status with the Python bootstrap/reference guard.
  The Python version remains in place until drift-fixture coverage is added;
  this migration does not move serial, filesystem orchestration, or driver I/O
  into the language.
- **`gen_symbol_table.py` → my-lisp (blocked gate)**: the pure transformation
  pilot `gen_symbol_table_v01.my` is oracle-verified, but full migration is not
  a text-free rewrite. The legacy generator extracts 164 entries from 28 ASM
  programs; 137 IDs conflict with the canonical core symbol inventory and 27
  names are program-local. Completing this migration requires a generated
  `.inc`, mass ASM/fixture renumbering, and byte-level assembler parity before
  removing `PROGRAM_SYMBOLS`. The extraction step still needs a ratified text
  API (`read-file-string`/`string-slice`/`*argv*`) or remains a Python
  bootstrap step; no language-contract change is implied by this gate.
- **`upload.py`/`monitor.py` → Lisp**: not planned, not desired. Keep
  them in Python. If a future agent proposes migrating them, point here
  first rather than re-deriving the reasoning.
