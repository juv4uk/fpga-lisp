# ============================================================================
# gw_sh.tcl — Gowin Shell script for UPC-8 Demo
# ============================================================================
# Usage: gw_sh.exe gw_sh.tcl
#        (from Gowin EDA installation directory or with gw_sh in PATH)
#
# This script performs:
#   1. Device selection (GW5A-LV25MG121NC1/I0, Version A)
#   2. File addition (Verilog + CST)
#   3. Synthesis
#   4. Place & Route
#   5. Report generation (LUT, Fmax, timing)
#
# Output files in impl/pnr/:
#   upc8_demo.rpt.txt    — resource report (LUT, FF, BSRAM, DSP)
#   upc8_demo.tim.rpt    — timing report (Fmax, slack)
#   upc8_demo.fs         — bitstream for programming
# ============================================================================

# ------------------------------------------------------------------------
# 1. Device configuration
# ------------------------------------------------------------------------
set_device -name GW5A-LV25MG121NC1/I0 -version A

# ------------------------------------------------------------------------
# 2. Add source files
# ------------------------------------------------------------------------
add_file upc8_decode.v
add_file upc8_transform.v
add_file top_upc8_demo.v
add_file tang_primer_25k.cst

# ------------------------------------------------------------------------
# 3. Project options
# ------------------------------------------------------------------------
set_option -top_module top_upc8_demo
set_option -output_base_name upc8_demo
set_option -gen_text_timing_rpt 1
set_option -gen_pnr_netlist 0
set_option -show_all_warn 1

# ------------------------------------------------------------------------
# 4. Run synthesis
# ------------------------------------------------------------------------
run_syn

# ------------------------------------------------------------------------
# 5. Run place & route
# ------------------------------------------------------------------------
run_pnr

# ------------------------------------------------------------------------
# 6. Report summary (printed to console)
# ------------------------------------------------------------------------
puts "========================================"
puts "UPC-8 Demo Synthesis Complete"
puts "========================================"
puts "Check impl/pnr/ for:"
puts "  - upc8_demo.rpt.txt   (resource usage)"
puts "  - upc8_demo.tim.rpt   (timing / Fmax)"
puts "  - upc8_demo.fs        (bitstream)"
puts "========================================"
