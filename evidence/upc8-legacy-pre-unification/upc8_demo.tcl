// upc8_demo synthesis -- Gowin gw_sh (GW5A-25A on Tang Primer 25K Dock).
// Run from the repo root with the Gowin EDA installed under Wine/Windows:
//   "C:\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe" fpga/synth/upc8_demo.tcl
// Use forward slashes for the script path (Git Bash swallows backslashes).
// Outputs land in impl/ (gitignored), same as the lisp_machine flow.
set_device -name GW5A-25A GW5A-LV25MG121NC1/I0
set_option -use_cpu_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_mspi_as_gpio 1
set_option -verilog_std sysv2017
add_file "fpga/rtl/upc8_decode.sv"
add_file "fpga/rtl/upc8_transform.sv"
add_file "fpga/rtl/upc8_demo.sv"
add_file "fpga/rtl/upc8_demo.cst"
add_file "fpga/synth/upc8_demo.sdc"
run all