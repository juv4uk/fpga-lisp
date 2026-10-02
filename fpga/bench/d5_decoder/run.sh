#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="/tmp/d5-decoder-$$.vvp"
trap 'rm -f "$out"' EXIT

iverilog -g2012 -s tb_d5_decoder -o "$out" \
  "$here/d5_decoder.sv" \
  "$here/tb_d5_decoder.sv"
vvp "$out"

python3 "$here/bench_yosys.py"
