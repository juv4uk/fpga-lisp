#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="/tmp/selector-path-$$.vvp"
trap 'rm -f "$out"' EXIT
iverilog -g2012 -s tb_selector_path -o "$out" \
  "$here/selector_path_engine.sv" \
  "$here/tb_selector_path.sv"
vvp "$out"
