# ecosystem/ scaffold (Swarm Contract v0.1, FPGA-SWARM-CONTRACT-01)

Per `repo.my`'s `(imports language-contract compatibility)`: fpga-lisp
doesn't track cross-repo state as versioned epistemic "claims" the way
`shiva-sutras`/`my-lisp-panini` do (see their `ecosystem/imports/*.my`
files, `(claim ID (revision ...) (status ...))` shape) -- fpga-lisp's
imports are contracts, not hypotheses: `isa-contract.my` and
`compatibility.my` are git-tracked, versioned, and either match or
don't (no "supported"/"disputed" gradient). The durable record of
whether an import is currently honored lives in commit history and
`ecosystem-status.md`, not a separate claims file here.

No `imports/*.my` files are populated in this scaffold as of this
writing -- an empty placeholder would be worse than an explanation of
why it's empty, per the same "don't fabricate to fill a template"
principle this repo already applies elsewhere (see
`fixture_coverage.py`'s UNCLASSIFIED category, `docs/hardware-setup.md`'s
"not yet tried" notes).
