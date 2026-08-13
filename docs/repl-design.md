# Interactive REPL design proposal (FPGA-REPL-DESIGN)

Status: proposal, not implemented. Plan item 27. From
`docs/lisp-machine-plan.md`'s own "Майбутній REPL" sketch:

```
> (cons 'a 'b)
(a . b)
> (def factorial (lambda (n) ...))
> (factorial 10)
3628800
```

A real REPL means: a person types Lisp *source text*, sees a result, and
whatever they `def`'d is visible to the *next* line they type -- state
persists across turns, on the running machine, not just within one
uploaded program.

## What already exists vs. what's missing

Already real, hardware-verified: `eval`, `def`-shaped self-recursive
`letrec` bindings (M28-M32), a symbol-name printer (`monitor.py --symbols`,
`FPGA-SYMBOL-TABLE-HOST-TOOL`), and a binary post-`HALT` command protocol
(`REG`/`HEAP`/`HP`/`ERR`, `monitor.py`'s `cmd_*` functions).

Missing, and each a real gap, not a formality:

1. **No reader.** Every existing program's AST is hand-encoded as `CONS`
   chains in `.asm` (or, per `FPGA-BOOT-MY-FORMAT`, would eventually come
   from a host-side `core.my`-syntax compiler) -- nothing on this machine,
   or in this repo's host tooling, turns `"(cons 'a 'b)"` typed at a
   prompt into heap data. `read`/`eval (read ...)` are explicitly listed
   `NOT-APPLICABLE` in `fixture_coverage.py`'s classification for exactly
   this reason.
2. **No persistent-session protocol.** The UART bootloader protocol
   (`upload_program` in `upload.py`/`monitor.py`) always means "here is a
   *whole new program*, reset `imem`/heap/registers and run it from
   scratch." There is no "evaluate this one expression against whatever
   environment already exists from the last one" command. `monitor.py`'s
   post-`HALT` commands (`REG`/`HEAP`) only *read* machine state; nothing
   *extends* it.
3. **No env handle to extend.** M28-M32's demos each build their own
   `new_env` from scratch inside one program and never expose it past
   `HALT`. A REPL needs the machine to remember "the current top-level
   environment" as a stable, growing thing across turns, most likely by
   never `HALT`ing between REPL lines at all (staying in a
   dispatch-and-wait loop) rather than the current run-to-completion
   model every milestone so far uses.

## Proposed architecture: host-side reader, hardware-side eval

Given the reader gap, the two realistic shapes are "build a hardware
reader" (a large, separate RTL project on its own) or "read on the host,
send the already-parsed AST." The second is strictly less new work and
matches this repo's existing division of labor (`assembler.py`/`gen_symbol_table.py` are host-side tools; the FPGA never parses text) --
proposed:

```
person types "(def factorial (lambda (n) ...))"
        |
host-side reader (new tool, Python or the eventual boot.my compiler
from FPGA-BOOT-MY-FORMAT -- likely the SAME reader, reused)
        |
AST encoded as a sequence of CONS/LOADSYM/etc. instructions
(same shape every .asm bootstrap demo already hand-writes)
        |
sent over UART as a new bootloader command: "EVAL program_bytes"
(distinct from today's cold "load and run from PC=0" command)
        |
hardware appends the new closures to the SAME persistent env,
evaluates the new top-level expr, returns the result
        |
host-side printer (extends monitor.py's fmt_word +
gen_symbol_table.py's per-session symbol registry, not
gen_symbol_table.py's current per-*program* one) shows it
```

## What changes on the hardware side

- **Bootloader protocol needs a second command shape.** Today: `[length
  (2 bytes)] [instructions...]`, always means "reset and run from PC=0."
  Needs: a way to say "run this new code, but don't reset the heap/env
  registers first" -- likely a 1-byte command-type prefix before the
  existing length-prefixed body, `0x00` = today's cold-load, `0x01` =
  warm-eval-against-current-env. Small, additive change to
  `bootloader.sv`, not a redesign.
- **The machine must not `HALT`-and-stop between REPL turns** the way
  every milestone so far does. Needs a new top-level state: after a warm
  eval completes, return to "waiting for next UART command" instead of
  the terminal `ST_HALT` state M17's error-recovery work put in place.
  Whether this reuses `ST_HALT` (already means "stopped, awaiting a
  monitor command" per M08) or needs a distinct state is an open RTL
  question, not decided here.
- **Env register must survive.** Whichever register/heap-cell currently
  holds the top-level env at the end of a warm-eval needs to be the
  *input* env for the next one -- likely just: don't clear it, and the
  new EVAL command's generated code looks it up from a fixed known
  location (a reserved heap cell or register) instead of building
  `new_env` from `NIL` the way every M-series demo does today.

## Symbol table implication

`gen_symbol_table.py`'s current design is explicitly per-*program*
(`FPGA-SYMBOL-TABLE-HOST-TOOL`'s own finding: ids aren't interned across
separate `.asm` files). A REPL is one continuous session, so its symbol
table is naturally per-*session* instead -- closer to a real Lisp reader's
intern table, assigning a fresh id the first time a name is seen and
reusing it for the rest of that REPL session. This is a different (and
simpler) problem than the cross-program case `gen_symbol_table.py` had to
solve, not an extension of it.

## What this does NOT decide

- Whether the host-side reader is a new small tool or reuses
  `FPGA-BOOT-MY-FORMAT`'s eventual `boot.my` compiler (very plausibly the
  same piece of code, since both need "Lisp syntax -> heap-encoded AST")
  -- flagged as likely shared work, not decided which comes first.
  Non-goal for THIS document to be the design for `boot.my`'s Fortran
  compiler; here for cross-reference only.
- The exact warm-eval bootloader command encoding (1-byte prefix vs.
  reusing an unused bit in the existing length field vs. something else)
  -- an RTL/protocol-design question for whoever implements this, not
  fixed here.
- Whether `imem` growth needs its own bump-pointer the way the heap
  already has one (each warm-eval appends new instructions rather than
  overwriting from PC=0) -- real question, `imem` is currently written
  once per cold-load and read-only during execution; a REPL needs it
  writable incrementally instead.
