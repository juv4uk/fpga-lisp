#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="/tmp/dense-pack-address-$$.vvp"
trap 'rm -f "$out"' EXIT

iverilog -g2012 -s tb_address_map -o "$out" \
  "$here/address_map.sv" \
  "$here/tb_address_map.sv"
vvp "$out"

python3 "$here/bench_yosys.py"
