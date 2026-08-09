set_device -name GW5A-25A GW5A-LV25MG121NC1/I0
set_option -use_cpu_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_mspi_as_gpio 1
set_option -verilog_std sysv2017
add_file "fpga/rtl/lisp_word.sv"
add_file "fpga/rtl/heap.sv"
add_file "fpga/rtl/lisp_data_unit.sv"
add_file "fpga/rtl/registers.sv"
add_file "fpga/rtl/instruction_decoder.sv"
add_file "fpga/rtl/control.sv"
add_file "fpga/rtl/uart.sv"
add_file "fpga/rtl/bootloader.sv"
add_file "fpga/rtl/lisp_machine.sv"
add_file "fpga/rtl/lisp_machine.cst"
add_file "fpga/synth/lisp_machine.sdc"
run all
