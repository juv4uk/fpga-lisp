# Dense pack capacity oracle — fpga-lisp#50

Upstream benchmark: juv4uk/sens#3046  
Vendor evidence format: juv4uk/sens#3074

This directory is the **software capacity/correctness oracle** for the GW5A dense
packing experiment. It is not synthesis, place-and-route, timing, BSRAM, or
language-semantic evidence.

It compares three physical storage mechanisms for exact D3/D5/D7 payloads:

- `naive-byte` — one 8-bit carrier per value;
- `word-aligned-32` — as many whole semantic values as fit in each 32-bit word;
- `tight-32` — one contiguous bitstream across 32-bit physical words.

The oracle exhaustively round-trips every D3/D5/D7 payload and then checks
depth-shaped deterministic streams for 256, 1024 and 4096 values.

## Useful lower bound

For the requested depths, tight D3/D5/D7 streams divide exactly into 32-bit
physical words, so the capacity-only lower bound is:

```text
tight-32 reserved_bits = 0
tight-32 packing_efficiency = 1.0
```

This does **not** imply zero pack/unpack logic, one-cycle access, fewer BSRAM
blocks, or better Fmax. Those are exactly what the vendor FPGA run must measure.

Examples at depth 1024:

```text
D3 naive-byte      37.50%
D3 word-aligned    93.20%
D3 tight          100.00%

D5 naive-byte      62.50%
D5 word-aligned    93.57%
D5 tight          100.00%

D7 naive-byte      87.50%
D7 word-aligned    87.50%
D7 tight          100.00%
```

## Run

```sh
python3 fpga/bench/dense_pack/packing_oracle.py
```

Each row is JSON and records logical/physical/reserved bits and packing
efficiency. `hardware_evidence=false` and `semantic_authority=false` are
deliberate.

## Vendor handoff

The local GW5A agent should implement equivalent naive, word-aligned and tight
RTL mechanisms and compare vendor P&R against these capacity rows. Report at
minimum:

```text
BSRAM
pack/unpack Logic/LUT + FF
register->logic->register Fmax/slack
latency_cycles
initiation_interval
RTL/report SHA-256
```

Keep `semantic_width` distinct from the physical RAM/port word width and feed
real hardware rows back to sens#3046/#3074.

The oracle never infers a SENS domain from payload length.
