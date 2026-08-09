// 50 MHz system clock (matches CLK_FREQ default in uart.sv). Without
// this, the placer/router has no target frequency and does not verify
// timing closure for the design at all -- a growing design (like the
// M-something PC/imem widening) can then silently fail on real
// hardware from setup/hold violations while simulation, which has no
// routing delay, still passes cleanly. See docs/lisp-machine-plan.md.
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
