# `boot.my` format proposal (FPGA-BOOT-MY-FORMAT)

Status: proposal, not implemented. Written from `docs/lisp-machine-plan.md`'s
own stated intent (see "FPGA має лише primitive layer... Після старту
завантажується `boot.my`" and the "Цільова структура репозиторію" section's
`fpga/boot/boot.mem` + `fpga/boot/boot.my` pair) -- this document couldn't
retrieve the exact original task description from the swarm registry (no
per-task describe op exists yet, only top-ranked `next-best-action` shows
one), so it's grounded in the plan doc's own words, not a guess from
nothing.

## What this closes

Every bootstrap milestone (M19-M32) so far hand-assembles ONE function at a
time into its own `.asm`/`.bin`, uploaded fresh over UART for that specific
test. There is no persistent "standard library" the machine has after
reset -- `null?`, `not`, `second`, `third`, `pair`, `length`, `reverse`,
`append`, `equal?` all exist as separate, disconnected demo programs, not
as one bound-together environment a real program could `def` more things
on top of. `boot.my`/`boot.mem` is the plan's own name for closing that
gap: a single assembled image, loaded automatically after reset, whose
environment already has the `core.my` functions this repo has proven one
at a time.

## Two artifacts, not one

- **`fpga/boot/boot.my`** -- the *source*: an ordered list of `core.my`
  function definitions this repo has actually bootstrapped and verified
  (M19-M32's functions), written in the same letrec/SETCDR-backpatch style
  M28-M32 already use for the self-/mutually-recursive ones. Human-readable,
  git-diffable, the thing a person edits.
- **`fpga/boot/boot.mem`** -- the *assembled binary* `boot.my` compiles to,
  in the same `.bin` word format every other bootstrap demo already uses.
  This is what actually gets loaded onto the machine -- there is no reader
  on hardware (item 27, full REPL, is unstarted), so `boot.my` is never
  parsed by the FPGA itself, only by the host-side assembler, exactly like
  every `.asm` file already works today.

## Why `.my` source, not `.asm` source, for `boot.my` specifically

Every other bootstrap demo's source is hand-written `.asm` (register-level
CONS-chain construction of the AST, per M19-M32's own files) -- not actual
`core.my` Lisp syntax. `boot.my` inverts this: its *source of truth* should
be real `core.my`-syntax Lisp text (the same syntax `docs/reference/`
already mirrors from my-lisp), assembled by a **new** tool that reads real
Lisp syntax and emits the same hand-encoded AST-as-heap-data the existing
`.asm` files build by hand -- i.e., a proper reader/compiler, not another
`.asm` file. This is a real gap: today, going from `(def length (lambda
(values) (length-onto values 0)))` to `bootstrap_length_demo.asm`'s ~200
lines of `CONS`/`LOADSYM` register choreography is a manual, error-prone
translation a human (or an LLM) does by hand each time (see M28/M29's own
postmortem: the bug that caused two retracted "PASSED" claims was exactly
this kind of manual-translation mistake, a missing `quote`). `boot.my`
needing multiple functions bound together, sharing one `letrec` frame,
makes hand-translation this way *harder*, not easier, than any single
M-series demo -- this is the natural forcing function for finally writing
a real `core.my`-syntax-to-fpga-lisp-heap compiler, not another one-off
`.asm`.

## Load-order and letrec-frame implications

M28-M32 already show each new letrec-bound function needs its own
placeholder in the *same* env frame as the earlier ones already backpatched,
sharing that frame lets later functions find earlier ones by plain lookup
(exactly how M31's `append` finds M30's `reverse`/`reverse-onto` without
its own placeholder). `boot.my` generalizes this to N functions instead of
2-3: one shared frame, one placeholder per self-/mutually-recursive
function (not one per function overall -- `append`-shaped non-recursive
ones don't need their own, per M31), built and backpatched in dependency
order (`null?`/`not` first since nothing else here depends on them,
`length-onto`/`length` and `reverse-onto`/`reverse` next, `append` after
`reverse`, `equal?` last since it's the most self-contained).

## Open questions (not decided by this document)

- Whether `boot.mem` is loaded via the *same* UART bootloader protocol
  every other program uses, or needs a dedicated at-reset load path
  (Gowin bitstream-embedded initial `imem` contents, avoiding a UART step
  entirely) -- an RTL/synthesis question, not a format question.
- Exact function list and order for the first `boot.my` -- proposed above
  (null?, not, second, third, pair, length/length-onto, reverse/
  reverse-onto, append, equal?) mirrors M19-M32's actual verified set, but
  worth confirming nothing was silently dropped.
- Whether `boot.my`'s own compiler (the real gap this document identifies)
  is itself a new task, or subsumed into this one -- flagging rather than
  deciding, since it's the larger piece of work here by far.
