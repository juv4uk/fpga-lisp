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

- **`assembler.py` → `assembler.my`**: real, already in progress
  (`FPGA-ASSEMBLER-DIFF-TEST` in the swarm task registry). The historical
  stack-overflow/0-byte failure is no longer reproduced: on 2026-08-24 the
  release my-lisp binary emitted byte-identical output for `call_demo.asm`
  (5 instructions) and `bootstrap_add_demo.asm` (280 instructions). The
  Python implementation remains the bootstrap/reference path until the
  differential fixture set is expanded; `tests/test_assembler_my_parity.py`
  now makes this migration gate executable. The gate currently covers twelve
  representative programs (call, arithmetic, pair/list, tail-recursive
  length, equality, lambda, and quote paths).
- **`upload.py`/`monitor.py` → Lisp**: not planned, not desired. Keep
  them in Python. If a future agent proposes migrating them, point here
  first rather than re-deriving the reasoning.
