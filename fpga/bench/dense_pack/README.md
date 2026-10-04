# Dense pack benchmark — fpga-lisp#50

Upstream benchmark: juv4uk/sens#3046  
Vendor evidence format: juv4uk/sens#3074

This directory provides two deliberately separate evidence layers for the GW5A
dense-packing experiment:

1. a software capacity/correctness oracle;
2. benchmark-only RTL for address/bit-offset/word-crossing logic.

Neither layer is vendor place-and-route evidence or language-semantic authority.

## Storage strategies

The benchmark compares three physical mechanisms for exact D3/D5/D7 payloads:

- `naive-byte` — one 8-bit carrier per value;
- `word-aligned-32` — as many whole semantic values as fit in each 32-bit word;
- `tight-32` — one contiguous bitstream across 32-bit physical words.

The software oracle exhaustively round-trips every D3/D5/D7 payload and checks
depth-shaped deterministic streams for 256, 1024 and 4096 values.

## Capacity lower bound

For the requested depths, tight D3/D5/D7 streams divide exactly into 32-bit
physical words:

```text
tight-32 reserved_bits = 0
tight-32 packing_efficiency = 1.0
```

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

This does **not** imply zero pack/unpack logic, one-cycle random access, fewer
BSRAM blocks, or better Fmax.

## RTL address mapper

`address_map.sv` implements registered address mapping for the three strategies.

For a semantic value index `i`:

```text
naive-byte:
  physical address = i
  bit offset       = 0
  crosses word     = no

word-aligned-32:
  slots            = floor(32 / W)
  physical word    = floor(i / slots)
  bit offset       = (i mod slots) * W
  crosses word     = no

tight-32:
  bit position     = i * W
  physical word    = floor(bit position / 32)
  bit offset       = bit position mod 32
  crosses word     = bit offset + W > 32
```

`tb_address_map.sv` checks all 1024 indices for W=3,5,7 against those integer
equations.

`bench_yosys.py` reports generic synthesis cells for:

```text
naive-byte
word-aligned-32 W=3/5/7
tight-32        W=3/5/7
```

These generic Yosys rows measure mapper/control shape only. They are **not**
Gowin LUT/Logic, BSRAM, timing, power, or board evidence.

## Run

```sh
python3 fpga/bench/dense_pack/packing_oracle.py
bash fpga/bench/dense_pack/run.sh
```

The focused workflow runs both layers.

## Vendor handoff

The local GW5A agent should reuse the address mapper around an inferred or
vendor RAM implementation and measure the complete storage mechanism.

Report at minimum:

```text
semantic_width
physical_word_width
packing_strategy
depth_values
logical_bits
physical_bits
reserved_bits
packing_efficiency
BSRAM
pack/unpack Logic/LUT + FF
register->logic->register Fmax/slack
latency_cycles
initiation_interval
RTL/report SHA-256
```

For tight packing, explicitly record the cost of straddling accesses rather
than hiding them in an average.

Feed real vendor rows back to sens#3046/#3074. The SENS validator keeps
`semantic_width` separate from physical word width and rejects inconsistent
packing accounting.

The benchmark never infers a SENS domain from payload length or hardware
geometry.
