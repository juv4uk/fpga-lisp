# upc8-legacy-pre-unification

Pre-unification UPC-8 standalone demo files, archived 2026-09-06 before
removal from the working tree.

These files implemented UPC-8 as two separate combinational modules
(`upc8_decode.sv`, `upc8_transform.sv`) with a top-level demo board
wrapper (`upc8_demo.sv`) for the Tang Primer 25K (Gowin GW5A-LV25MG121NC1/I0),
plus a standalone synth script (`upc8_demo.tcl`) and testbench (`tb_upc8.sv`).

They were superseded by `fpga/rtl/upc8_unit.sv`, which unifies
decode + transform + predicate in a single module with an rs2-encoded
interface for direct integration into the `lisp_machine` control unit
(via `control.sv` encoded-mode MOV, rs2=4/5/6, ISA 1.2).

## Archived files

| File | Size | Notes |
|------|------|-------|
| `upc8_decode.sv` | 7714 B | Standalone `upc8_decode` module |
| `upc8_transform.sv` | 3777 B | Standalone `upc8_transform` module |
| `upc8_demo.sv` | 6650 B | Top-level demo wrapper (`upc8_demo`) with UART/LEDs |
| `upc8_demo.tcl` | 730 B | Standalone synth script for Gowin EDA |
| `tb_upc8.sv` | 7641 B | Original testbench testing decode/transform against expected.hex |

## Provenance

Collected from `fpga/rtl/` and `fpga/synth/` at commit HEAD (pre-5a3a9ad),
before replacement by the unified `upc8_unit.sv` (owner's upc8_fpga_lisp.tar.gz,
ISA 1.2 encoded MOV integration).
