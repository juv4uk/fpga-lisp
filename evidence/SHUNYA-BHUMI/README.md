# ŚŪNYA-BHŪMI evidence surfaces

This directory holds experiment-provenance templates. It is instrumentation,
not Lisp semantic authority.

## Genesis

`GENESIS-TEMPLATE.md` is the human-readable checklist for what existed at t0.

`genesis_manifest.py` emits one machine-readable JSON manifest from explicit
operator-supplied arguments. It deliberately does not inspect Git, infer board
state from filenames, or rewrite an existing manifest.

Example:

```sh
python genesis_manifest.py \
  --output evidence/SHUNYA-BHUMI/runs/E0-run-001/genesis.json \
  --timestamp 2026-09-18T00:01:00Z \
  --fpga-lisp-commit <exact-sha> \
  --build-or-bitstream-ref bitstream:e0.fs \
  --fpga-target GW5A-25A \
  --toolchain "Gowin EDA" \
  --program-ref bootstrap_nullp_demo.bin \
  --enabled-mechanisms-ref isa-contract-v1 \
  --external-interface UART \
  --seed-or-determinism "deterministic reset" \
  --absent-mechanism GC
```

Unknown state stays `UNKNOWN`. Re-running against the same output path fails
rather than silently rewriting t0 history.

## Observations

`OBSERVATION-TEMPLATE.jsonl` documents the append-only raw observation shape.
The monitor-emission implementation is tracked separately in #10 / PR #12.

## Coordination

- Parent metrology task: #10.
- Machine-readable Genesis slice: #14 / PR #15.
- E0 behavioral baseline: #11, blocked until the metrology surfaces required by
  #10 are ready and reviewed.

These artifacts record what was given or observed. They do not establish
learning, intelligence, self-awareness, emergence, or any other behavioral
interpretation.
