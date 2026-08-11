# Evidence protocol

See `my-lisp`'s [`evidence/README.md`](../../my-lisp/evidence/README.md) (commit
`f96936d`) for the full schema — this is fpga-lisp's copy of the same
convention, not a fork of it. One evidence file per (requirement,
implementation, commit) triple at `evidence/<requirement-id>/fpga-lisp/<short-sha>.my`,
keyed by the `G1`-`G8`/`S1`-`S3` requirement IDs from my-lisp's
`docs/language-core-axioms.md`. Data only — read via `(read-file ...)`,
never `(load ...)`.

This replaces hand-copying "PASSED" into `docs/lisp-machine-plan.md`'s
prose or a cross-session message asserting a result. Those docs still
narrate the *how* and *why*; this directory is the checkable *fact*.
