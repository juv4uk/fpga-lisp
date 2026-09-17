# ŚŪNYA-BHŪMI FPGA GENESIS

Parent: #10
Research protocol: `juv4uk/ecosystem#12`

> Freeze this file for one experiment/run family. Do not rewrite t0 after observing results. A changed initial condition creates a new Genesis/version.

## Identity

- experiment_id: `TBD`
- run_family: `TBD`
- fpga_lisp_commit: `TBD`
- source_contract_pin: `TBD`
- date_utc: `TBD`

## Hardware / toolchain GIVEN at t0

- board: `TBD`
- FPGA/device: `TBD`
- synthesis tool/version: `TBD`
- simulator/version: `TBD`
- programmer/transport: `TBD`
- clock/reset configuration: `TBD`

## Bitstream / build GIVEN at t0

- build command: `TBD`
- bitstream/artifact ref: `TBD`
- bitstream hash: `TBD`
- synthesis report ref: `TBD`

## Machine state GIVEN at t0

- program image/ref: `TBD`
- program image hash: `TBD`
- PC: `TBD`
- registers: `TBD`
- heap pointer/state: `TBD`
- heap/memory initialization: `TBD`
- symbol table/version: `TBD`
- external input buffers: `TBD`
- deterministic seed, if any: `TBD | NONE`

## Mechanisms present at t0

List only mechanisms actually implemented/enabled.

- `TBD`

## Mechanisms explicitly absent at t0

This section prevents retrospective smuggling of capabilities into the baseline.

- rewards/goals: `ABSENT | TBD`
- curiosity signal: `ABSENT | TBD`
- self-model: `ABSENT | TBD`
- observer Sanskrit categories as runtime modules: `ABSENT | TBD`
- other: `TBD`

## Interfaces GIVEN at t0

For each interface record direction, protocol, and what information can cross it.

- host ↔ FPGA: `TBD`
- UART/USB: `TBD`
- other: `TBD`

## Observation surface

Record what can be observed without changing semantics.

- cycle/timestamp source: `TBD`
- state fields exposed: `TBD`
- raw output format: `TBD`
- raw artifact destination: `TBD`

## Known limits / BLOCKED

- `TBD`

## Genesis checksum

After filling this file, record a content hash here and in the run record.

- sha256: `TBD`

## Epistemic rule

Everything above is `GIVEN` for this run. Results belong elsewhere and must be recorded as `OBSERVED`, `INFERRED`, or `HYPOTHESIZED` rather than added back into Genesis.
