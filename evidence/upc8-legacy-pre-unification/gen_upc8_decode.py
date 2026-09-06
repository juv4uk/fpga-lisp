#!/usr/bin/env python3
"""Generate fpga/rtl/upc8_decode.sv and testbench reference ROM from the
shiva-sutras UPC-8 registry oracle (upc8.py). The RTL class table must
never diverge from the registry by hand-editing -- regenerate instead.

Usage:
  python3 gen_upc8_decode.py [path/to/prototype/upc8.py]

  If the oracle path is omitted, shiva-sutras is searched at the standard
  sibling location ../shiva-sutras/prototype/upc8.py.
"""

import json
import sys
import os

_CLASS_BITS = [
    ("vowel", 5),
    ("consonant", 4),
    ("stop", 3),
    ("sibilant", 2),
    ("nasal", 1),
    ("semivowel", 0),
]

_LAYER_ENC = {"canonical": 0, "sanskrit_extended": 1, "ukrainian_new": 2, "reserved": 3}


def find_oracle(argv):
    if len(argv) > 1:
        return argv[1]
    for cand in (
        "/home/agents/GitHub/shiva-sutras/prototype/upc8.py",
        os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "../shiva-sutras/prototype/upc8.py"),
    ):
        if os.path.isfile(cand):
            return cand
    raise SystemExit("oracle upc8.py not found; pass its path as argument")


def build_table(upc8):
    table = []
    for code in range(0x100):
        entry = upc8.table.get(code)
        layer = entry["layer"] if entry else "reserved"
        cls = set(upc8.phonological_class(code, "sanskrit"))
        special = 0
        if "anusvara" in cls:
            special = 1
            cls.discard("anusvara")
        if "visarga" in cls:
            special |= 2
            cls.discard("visarga")
        cls_bits = 0
        for name, bit in _CLASS_BITS:
            if name in cls:
                cls_bits |= 1 << bit
        table.append(
            {
                "code": code,
                "slp1": entry.get("slp1") if entry else None,
                "layer": layer,
                "layer_enc": _LAYER_ENC[layer],
                "cls_bits": cls_bits,
                "special": special,
            }
        )
    return table


def emit_rtl(table):
    lines = []
    lines.append("// GENERATED FILE -- do not hand-edit. Regenerate with:")
    lines.append("//   python3 gen_upc8_decode.py ../shiva-sutras/prototype/upc8.py")
    lines.append("// Decode truth table derived from the shiva-sutras UPC-8 registry")
    lines.append("// oracle (upc8.py, phonological_class profile='sanskrit').")
    lines.append("//")
    lines.append("// cls[5:0]   = {vowel,consonant,stop,sibilant,nasal,semivowel}")
    lines.append("// special[0] = anusvara, special[1] = visarga (extended, no canon_ref)")
    lines.append("// layer      = 0 canonical, 1 sanskrit_extended, 2 ukrainian_new, 3 reserved")
    lines.append("//")
    lines.append("module upc8_decode(")
    lines.append("    input  wire [7:0] code,")
    lines.append("    output reg  [1:0] layer,")
    lines.append("    output reg  [5:0] cls,")
    lines.append("    output reg  [1:0] special,")
    lines.append("    output reg        valid_assign")
    lines.append(");")
    lines.append("    always @* begin")
    lines.append("        case (code)")
    for t in table:
        if t["layer"] == "reserved":
            continue  # handled by default
        args = "; ".join(
            [
                f"layer={t['layer_enc']}",
                f"cls=6'd{t['cls_bits']}",
                f"special=2'd{t['special']}",
                "valid_assign=1'b1",
            ]
        )
        slp1 = t["slp1"].replace("'", "") if t["slp1"] else ""
        lines.append(f"            8'h{t['code']:02X}: begin {args}; end // {slp1}")
    lines.append("            default: begin layer=2'd3; cls=6'd0; special=2'd0;")
    lines.append("                       valid_assign=1'b0; end")
    lines.append("        endcase")
    lines.append("    end")
    lines.append("endmodule")
    return "\n".join(lines) + "\n"


def emit_tb_rom(table):
    """Reference ROM rows: {valid,special,layer,cls} as 12 bits (hex 3 digits)."""
    rom = []
    for t in table:
        word = (t["layer_enc"] & 3) | ((t["special"] & 3) << 2) | ((t["cls_bits"] & 0x3F) << 4)
        if t["layer"] != "reserved":
            word |= 1 << 10
        rom.append(f"{word:03X}")
    return rom


def main():
    sys.path.insert(0, os.path.dirname(find_oracle(sys.argv)))
    import importlib.util

    spec = importlib.util.spec_from_file_location("upc8", find_oracle(sys.argv))
    upc8mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(upc8mod)
    upc8 = upc8mod.UPC8()

    table = build_table(upc8)

    root = os.path.dirname(os.path.abspath(__file__))
    rtl_path = os.path.join(root, "fpga", "rtl", "upc8_decode.sv")
    rom_path = os.path.join(root, "fpga", "sim", "upc8_expected.hex")
    json_path = os.path.join(root, "evidence", "upc8-demo", "upc8-class-table.json")

    with open(rtl_path, "w") as f:
        f.write(emit_rtl(table))
    with open(rom_path, "w") as f:
        f.write("\n".join(emit_tb_rom(table)) + "\n")
    with open(json_path, "w") as f:
        json.dump(
            [
                {
                    "code": f"0x{t['code']:02X}",
                    "slp1": t["slp1"],
                    "layer": t["layer"],
                    "layer_enc": t["layer_enc"],
                    "cls": t["cls_bits"],
                    "special": t["special"],
                }
                for t in table
            ],
            f,
            indent=1,
            sort_keys=True,
        )
    print(f"wrote {rtl_path}\nwrote {rom_path}\nwrote {json_path}")


if __name__ == "__main__":
    main()