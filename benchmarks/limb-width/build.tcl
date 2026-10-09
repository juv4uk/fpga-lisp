set_device -name GW5A-25A GW5A-LV25MG121NC1/I0
set_option -use_cpu_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_mspi_as_gpio 1
set_option -verilog_std sysv2017

if {![info exists ::env(BENCH_TOP)]} {
    error "BENCH_TOP environment variable is required"
}
set top $::env(BENCH_TOP)

add_file "limb_kernel.sv"
add_file "limb_synth_top.sv"
add_file "limb_bench.cst"
add_file "limb_bench.sdc"

set_option -top_module $top
set_option -output_base_name $top
set_option -gen_text_timing_rpt 1
set_option -show_all_warn 1

run all
