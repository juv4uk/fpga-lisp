#!/usr/bin/env python3
"""Parse Gowin #39 matched limb-width synthesis directories into TSV.

Expected directory names:
  limb_baseadd_w16 / limb_add_w16
  limb_basemul_w16 / limb_mul_w16
and similarly for 18/24/28.
"""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path

TOP_RE = re.compile(r"^limb_(baseadd|add|basemul|mul)_w(16|18|24|28)$")
LOGIC_RE = re.compile(r"^  Logic\s+\|\s+(\d+)/")
LUT_RE = re.compile(r"--LUT,ALU,ROM16\s+\|\s+\d+\((\d+) LUT, (\d+) ALU,")
REG_RE = re.compile(r"^  Register\s+\|\s+(\d+)/")
DSP_RE = re.compile(r"^  DSP\s+\|\s+(\d+)/")
DSP_KIND_RE = re.compile(r"^\s+--([A-Z0-9_]+)\s+\|\s+(\d+)")
FMAX_RE = re.compile(r"^\s+1\s+clk\s+50\.000\(MHz\)\s+([0-9.]+)\(MHz\)")
SLACK_RE = re.compile(r"^Slack\s+:\s+([0-9.-]+)")
TOOL_RE = re.compile(r"<Tool Version>:(.+)")
PART_RE = re.compile(r"<Part Number>:(.+)")

FIELDS = (
    "top", "width", "role", "operation",
    "logic", "lut", "alu", "register", "dsp", "dsp_kind",
    "fmax_mhz", "setup_slack_ns", "tool_version", "part",
)


def _fill_resource_stats(row: dict[str, str], rpt: Path) -> None:
    kinds: list[str] = []
    for line in rpt.read_text(encoding="utf-8", errors="replace").splitlines():
        if m := LOGIC_RE.search(line):
            row["logic"] = m.group(1)
        elif m := LUT_RE.search(line):
            row["lut"], row["alu"] = m.groups()
        elif m := REG_RE.search(line):
            row["register"] = m.group(1)
        elif m := DSP_RE.search(line):
            row["dsp"] = m.group(1)
        elif m := DSP_KIND_RE.search(line):
            if m.group(1).startswith(("MULT", "PADD", "ALU")):
                kinds.append(f"{m.group(1)}:{m.group(2)}")
        elif m := TOOL_RE.search(line):
            row["tool_version"] = m.group(1).strip()
        elif m := PART_RE.search(line):
            row["part"] = m.group(1).strip()

    if kinds:
        row["dsp_kind"] = ",".join(kinds)


def _fill_timing_stats(row: dict[str, str], tr: Path) -> None:
    for line in tr.read_text(encoding="utf-8", errors="replace").splitlines():
        if not row["fmax_mhz"] and (m := FMAX_RE.search(line)):
            row["fmax_mhz"] = m.group(1)
        if not row["setup_slack_ns"] and (m := SLACK_RE.search(line)):
            row["setup_slack_ns"] = m.group(1)


def parse_one(top_dir: Path) -> dict[str, str]:
    match = TOP_RE.match(top_dir.name)
    if not match:
        raise ValueError(f"unexpected directory name: {top_dir.name}")
    raw_role, width = match.groups()
    role = "baseline" if raw_role.startswith("base") else "operation"
    operation = "add" if raw_role.endswith("add") else "mul"

    rpt = top_dir / "impl" / "pnr" / f"{top_dir.name}.rpt.txt"
    tr = top_dir / "impl" / "pnr" / f"{top_dir.name}.tr"
    if not rpt.exists() or not tr.exists():
        raise FileNotFoundError(f"missing PnR evidence for {top_dir.name}")

    row = {
        "top": top_dir.name,
        "width": width,
        "role": role,
        "operation": operation,
        "logic": "0",
        "lut": "0",
        "alu": "0",
        "register": "0",
        "dsp": "0",
        "dsp_kind": "-",
        "fmax_mhz": "",
        "setup_slack_ns": "",
        "tool_version": "",
        "part": "",
    }

    _fill_resource_stats(row, rpt)
    _fill_timing_stats(row, tr)
    if not row["fmax_mhz"] or not row["setup_slack_ns"]:
        raise ValueError(f"timing parse failed for {top_dir.name}")
    return row


def deltas(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    by_key = {(r["width"], r["operation"], r["role"]): r for r in rows}
    out = []
    for width in ("16", "18", "24", "28"):
        for op in ("add", "mul"):
            base = by_key[(width, op, "baseline")]
            dut = by_key[(width, op, "operation")]
            out.append({
                "width": width,
                "operation": op,
                "logic_delta": str(int(dut["logic"]) - int(base["logic"])),
                "lut_delta": str(int(dut["lut"]) - int(base["lut"])),
                "alu_delta": str(int(dut["alu"]) - int(base["alu"])),
                "register_delta": str(int(dut["register"]) - int(base["register"])),
                "dsp_delta": str(int(dut["dsp"]) - int(base["dsp"])),
                "dsp_kind": dut["dsp_kind"],
                "fmax_mhz": dut["fmax_mhz"],
                "fmax_baseline_mhz": base["fmax_mhz"],
                "setup_slack_ns": dut["setup_slack_ns"],
            })
    return out


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = list(rows[0])
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("matrix_root", type=Path)
    ap.add_argument("--rows-out", type=Path, required=True)
    ap.add_argument("--deltas-out", type=Path, required=True)
    args = ap.parse_args()

    dirs = sorted(
        path for path in args.matrix_root.iterdir()
        if path.is_dir() and TOP_RE.match(path.name)
    )
    rows = [parse_one(path) for path in dirs]
    if len(rows) != 16:
        raise SystemExit(f"expected 16 completed matched builds, got {len(rows)}")

    write_tsv(args.rows_out, rows)
    write_tsv(args.deltas_out, deltas(rows))
    print(f"PASS: parsed {len(rows)} Gowin builds")
    print(args.rows_out)
    print(args.deltas_out)


if __name__ == "__main__":
    main()
