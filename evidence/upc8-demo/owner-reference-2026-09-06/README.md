# UPC-8 Demo — Step B (Tang Primer 25K)

## Files

| File | Description |
|------|-------------|
| `upc8_decode.v` | 8-bit UPC field extractor + pratyāhāra predicates (ac-14, aṇ, ik) |
| `upc8_transform.v` | Combinational phonological transform engine (toggle, row±, guṇa, voice/aspirate embryo) |
| `upc8_tb.v` | Icarus Verilog testbench with 55 golden-value tests |
| `top_upc8_demo.v` | Top-level: 50 MHz, debounce, 2 buttons, 5 switches, 8 LEDs |
| `tang_primer_25k.cst` | Physical constraints (pins from Sipeed official examples + community fix #11) |
| `gw_sh.tcl` | Gowin Shell script for automated synthesis + P&R |

## Hardware Requirements

- **Tang Primer 25K Dock** (GW5A-LV25MG121NC1/I0, Version A)
- **8 external LEDs** on PMOD or 40-pin header (pmod_io[0..7])
- **5 switches/jumpers** on PMOD or 40-pin header (pmod_io[8..12])
- **USB-C cable** for power + JTAG programming

## Pinout (from official Sipeed examples)

| Signal | Pin | Note |
|--------|-----|------|
| clk | E2 | 50 MHz crystal |
| btn[0] | H11 | S1, active-high, **PULLDOWN required** |
| btn[1] | H10 | S2, active-high, **PULLDOWN required** |
| sw[0..4] | J5, H5, L9, K9, J8 | DIP switches or jumpers |
| led_ext[0..7] | G5, F5, G7, G8, H7, H8, L5, K5 | External LEDs |
| led_onb | L6 | Onboard LED (heartbeat) |

**CRITICAL:** Buttons H10/H11 require `PULL_MODE=DOWN` in CST. Default Gowin pull is UP, which makes buttons always read HIGH (community fix #11, confirmed by electronics.stackexchange).

## Build Flow

### Step 1: iverilog simulation (Ubuntu/WSL)

```bash
sudo apt install iverilog
iverilog -g2012 -o upc8_tb.vvp upc8_decode.v upc8_transform.v upc8_tb.v
vvp upc8_tb.vvp
```

Expected: `*** ALL TESTS PASSED ***`

### Step 2: Gowin synthesis + P&R (Windows)

Open PowerShell or CMD in project folder:

```powershell
# Adjust path to your Gowin installation
& "C:\Gowin\Gowin_V1.9.9Beta-4\IDE\bin\gw_sh.exe" gw_sh.tcl
```

Or if gw_sh is in PATH:
```powershell
gw_sh.exe gw_sh.tcl
```

Reports generated in `impl/pnr/`:
- `upc8_demo.rpt.txt` — LUT, FF, BSRAM, DSP usage
- `upc8_demo.tim.rpt` — Fmax, setup/hold slack
- `upc8_demo.fs` — bitstream for programming

### Step 3: Program FPGA (Windows)

```powershell
& "C:\Gowin\Gowin_V1.9.9Beta-4\IDE\bin\programmer_cli.exe"     --device GW5A-LV25MG121NC1/I0     --fs upc8_demo.fs     --operation p
```

Or use Gowin Programmer GUI.

## Operation

1. **Set base code** with switches:
   - sw[4:2] = row (0=a, 1=i, 2=u, 3=ṛ, 4=ḷ, 5=e, 6=o, 7=reserved)
   - sw[1] = length (0=short, 1=long)
   - sw[0] = nasal (0=plain, 1=nasalized)
   - Base code = `0x80 | (row<<3) | (nasal<<1) | length`

2. **LED indicators** (led_ext[7:0]):
   - [0] `is_class10` — green (code in class 10)
   - [1] `ac_14` — green (one of 14 vowels)
   - [2] `an_pred` — yellow (in aṇ)
   - [3] `ik_pred` — yellow (in ik)
   - [4] `nasal` — red (nasal bit set)
   - [5] `length` — red (length bit set)
   - [6] `is_reserved_row` — red (row 7)
   - [7] `transform_error` — red (last op invalid)

3. **Buttons**:
   - **btn[0] (H11)** short press: cycle transform op (NOP → TOGGLE_LENGTH → TOGGLE_NASAL → NEXT_ROW → PREV_ROW → GUNA → ...)
   - **btn[1] (H10)** short press: reset code to switch settings

4. **Onboard LED** (L6): heartbeat (~1 Hz) — shows clock is alive.

## Known Issues / Notes

- `upc8_transform.v` OP_VOICE/OP_ASPIRATE: class 00 codes do NOT use bit 2 as a free-bit flag (unlike class 10). The `free_bit` check is omitted for class 00 transforms.
- NEXT_ROW/PREV_ROW wrap: uses 8-bit concatenation `{code_in[7:6], new_row[2:0], code_in[2:0]}` to avoid 11-bit vector overflow.
- Device Version must be **A** (not B). Check your chip marking.

## Epistemic Status

- Decode predicates validated against `upc8_class10_check.py` (Python golden values).
- Transform ops validated against behavioral Python model (55 tests, all passed).
- Synthesis/P&R reports will provide ground-truth LUT count and Fmax (not estimated).
