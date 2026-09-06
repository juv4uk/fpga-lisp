# UPC-8 fpga-lisp Integration

## Files

| File | Description |
|------|-------------|
| `upc8_unit.sv` | UPC-8 phonetic engine (decode/transform/predicate), combinational |
| `control_patch.txt` | Patch instructions for control.sv integration |
| `isa-contract-patch.my` | ISA 1.2 contract update (encoded modes rs2=4/5/6) |

## Integration Steps

1. **Copy `upc8_unit.sv`** to `fpga-lisp/fpga/rtl/`
2. **Patch `control.sv`** using `control_patch.txt` (3 locations)
3. **Patch `lisp_machine.sv`** using `control_patch.txt` (instantiate upc8_unit)
4. **Update `isa-contract.my`** using `isa-contract-patch.my`
5. **Update `fpga/synth/build.tcl`** — add `upc8_unit.sv`
6. **Synthesize** with `gw_sh fpga/synth/build.tcl`

## ISA 1.2 Encoded Modes

| rs2 | Operation | Input | Output |
|-----|-----------|-------|--------|
| 4 | UPC8_DECODE | R1.value[7:0] = code | R3.value[12:0] = packed fields+predicates |
| 5 | UPC8_TRANSFORM | R1.value[10:8] = op, [7:0] = code | R3.value[9:0] = {error, valid, result} |
| 6 | UPC8_PREDICATE | R1.value[7:0] = code | R3.value[4:0] = {reserved, ik, an, ac, class10} |

## Resource Estimate

- LUT4: ~75 (decode ~20 + transform ~50 + mux ~5)
- FF: 0
- BSRAM: 0
- DSP: 0
- Total fpga-lisp footprint: ~1,438 LUT4 / 23,040 (~6.2%)

## Testing

Run iverilog simulation after patching:
```bash
iverilog -g2012 -I fpga/rtl -o tb_upc8.vvp   fpga/rtl/lisp_word.sv fpga/rtl/upc8_unit.sv   fpga/sim/tb_upc8.sv
vvp tb_upc8.vvp
```
