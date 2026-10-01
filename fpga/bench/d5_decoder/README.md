# D5 decoder benchmark — fpga-lisp#45

This directory measures implementation cost for the current upstream D5
research shape. It has **no language-semantic authority**.

## Inputs

Generator-owned selectors:

```text
10100 CAAAR   10101 CAADR
10110 CADAR   10111 CADDR
11000 CDAAR   11001 CDADR
11010 CDDAR   11011 CDDDR
```

Research candidate only:

```text
00101 TRANSFORMER
```

The remaining 23 words fail closed in the hybrid model.

## Compared decoders

- `d5_selector_only_decoder`: the eight proven selector descendants only.
- `d5_hybrid_decoder`: selector prefix law plus the single `00101` candidate.
- `d5_flat_decoder`: flat case-table control implementing the same nine occupied
  words as the hybrid decoder.

The flat and hybrid implementations must be behaviorally identical on all 32
width-5 inputs.

## Evidence levels

`tb_d5_decoder.sv` gives RTL-SIM evidence via Icarus Verilog.

`bench_yosys.py` gives generic Yosys synthesis-cell accounting. It is not
vendor place-and-route, timing, board measurement, or semantic evidence.

## Run

```sh
bash fpga/bench/d5_decoder/run.sh
```

The script requires `iverilog`, `yosys`, and Python 3; all are already listed
in the repository Guix manifest.

## Rule

Hardware may exploit an upstream semantic regularity after it is proven. A
smaller gate count cannot make an unratified D5 identity true.
