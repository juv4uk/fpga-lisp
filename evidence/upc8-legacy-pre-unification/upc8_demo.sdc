// 50 MHz system clock constraint, same convention as lisp_machine.sdc
// (the Dock board oscillator at E2; keeps the demo timing real on board).
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]