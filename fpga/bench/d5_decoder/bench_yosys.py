#!/usr/bin/env python3
"""Yosys generic-cell accounting for fpga-lisp#45 D5 decoder candidates.

This is implementation-cost evidence only.  It never promotes a semantic
candidate and deliberately reports raw generic cell counts rather than making
a language recommendation.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
RTL = HERE / "d5_decoder.sv"

TOPS = (
    "d5_selector_only_decoder",
    "d5_hybrid_decoder",
    "d5_flat_decoder",
)


def synth(top: str) -> dict[str, object]:
    script = (
        f"read_verilog -sv {RTL}; "
        f"hierarchy -check -top {top}; "
        "proc; opt; memory; memory_map; opt; techmap; opt; stat"
    )
    proc = subprocess.run(
        ["yosys", "-Q", "-p", script],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    output = proc.stdout

    matches = re.findall(r"Number of cells:\s+(\d+)", output)
    if not matches:
        raise RuntimeError(f"could not parse Yosys cell count for {top}")
    total = int(matches[-1])

    cell_rows: dict[str, int] = {}
    in_cells = False
    for line in output.splitlines():
        if "Number of cells:" in line:
            in_cells = True
            continue
        if in_cells:
            match = re.match(r"\s+(\S+)\s+(\d+)\s*$", line)
            if match:
                cell_rows[match.group(1)] = int(match.group(2))
            elif line.strip() == "":
                if cell_rows:
                    break

    return {
        "top": top,
        "generic_cells": total,
        "cell_types": cell_rows,
    }


def main() -> None:
    rows = {top: synth(top) for top in TOPS}

    selector = int(rows["d5_selector_only_decoder"]["generic_cells"])
    hybrid = int(rows["d5_hybrid_decoder"]["generic_cells"])
    flat = int(rows["d5_flat_decoder"]["generic_cells"])

    report = {
        "kind": "d5-decoder-yosys-generic-cost",
        "semantic_authority": False,
        "selector_only": rows["d5_selector_only_decoder"],
        "hybrid": rows["d5_hybrid_decoder"],
        "flat": rows["d5_flat_decoder"],
        "transformer_candidate_delta_cells": hybrid - selector,
        "hybrid_minus_flat_cells": hybrid - flat,
    }

    print(json.dumps(report, sort_keys=True))
    print(
        "D5 Yosys generic cells: "
        f"selector-only={selector} hybrid={hybrid} flat={flat}"
    )
    print(f"00101 candidate delta: {hybrid - selector:+d} generic cells")
    print(f"hybrid vs flat delta: {hybrid - flat:+d} generic cells")
    print("NON-CONCLUSION: synthesis cost does not assign D5 semantics")


if __name__ == "__main__":
    main()
