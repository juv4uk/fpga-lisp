#!/usr/bin/env python3
"""Generic Yosys cost for fpga-lisp#50 dense-pack address mappers."""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
RTL = HERE / "address_map.sv"

CASES = (
    ("naive-byte", "pack_addr_naive", None),
    ("word-aligned-32-w3", "pack_addr_word_aligned", 3),
    ("word-aligned-32-w5", "pack_addr_word_aligned", 5),
    ("word-aligned-32-w7", "pack_addr_word_aligned", 7),
    ("tight-32-w3", "pack_addr_tight", 3),
    ("tight-32-w5", "pack_addr_tight", 5),
    ("tight-32-w7", "pack_addr_tight", 7),
)


def synth(label: str, top: str, width: int | None) -> dict[str, object]:
    parts = [f"read_verilog -sv {RTL}"]
    if width is not None:
        parts.append(f"chparam -set WIDTH {width} {top}")
    parts.extend(
        [
            f"hierarchy -check -top {top}",
            "proc",
            "opt",
            "techmap",
            "opt",
            "stat",
        ]
    )
    proc = subprocess.run(
        ["yosys", "-Q", "-p", "; ".join(parts)],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    output = proc.stdout
    totals = re.findall(r"Number of cells:\s+(\d+)", output)
    if not totals:
        raise RuntimeError(f"could not parse Yosys cell count for {label}")

    cell_rows: dict[str, int] = {}
    in_cells = False
    for line in output.splitlines():
        if "Number of cells:" in line:
            in_cells = True
            cell_rows = {}
            continue
        if in_cells:
            match = re.match(r"\s+(\S+)\s+(\d+)\s*$", line)
            if match:
                cell_rows[match.group(1)] = int(match.group(2))
            elif line.strip() == "" and cell_rows:
                in_cells = False

    return {
        "case": label,
        "width": width,
        "generic_cells": int(totals[-1]),
        "cell_types": cell_rows,
        "semantic_authority": False,
        "vendor_pnr": False,
    }


def main() -> None:
    rows = [synth(*case) for case in CASES]
    for row in rows:
        print(json.dumps(row, sort_keys=True))
    print("NON-CONCLUSION: generic mapper cost is not BSRAM/P&R or semantic evidence")


if __name__ == "__main__":
    main()
