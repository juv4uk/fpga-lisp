# #39 limb-width hardware benchmark

This directory is mechanism-only evidence for fpga-lisp#39.

The same parameterized limb_kernel is used at widths 16, 18, 24 and 28:
- exact add with explicit carry output;
- exact W x W -> 2W unsigned multiply.

run_sim.py generates boundary plus deterministic random vectors with Python exact
integers, then checks the SystemVerilog kernel under Icarus before any synthesis
claim is allowed.

limb_synth_top.sv supplies matched internal source/sink machinery for real
vendor synthesis. Each width has baseline/add/multiply wrappers so resource
deltas can be interpreted against the same-width baseline rather than comparing
unmatched top-level plumbing.

No limb width is a SENS semantic width. This benchmark chooses hardware
mechanism only.
