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
