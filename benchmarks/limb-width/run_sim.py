#!/usr/bin/env python3
"""#39 correctness harness for parameterized exact limb kernels."""

from __future__ import annotations

import argparse
import random
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WIDTHS = (16, 18, 24, 28)


def vectors(width: int, random_count: int):
    mask = (1 << width) - 1
    values = [
        (0, 0, 0),
        (0, 0, 1),
        (mask, 0, 0),
        (mask, 0, 1),
        (mask, mask, 0),
        (mask, mask, 1),
        (1 << (width - 1), 1 << (width - 1), 0),
        (mask - 1, 1, 1),
    ]
    rng = random.Random(39000 + width)
    for _ in range(random_count):
        values.append((rng.randrange(1 << width), rng.randrange(1 << width), rng.randrange(2)))
    for a, b, cin in values:
        total = a + b + cin
        yield a, b, cin, total & mask, total >> width, a * b


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--random", type=int, default=1000)
    args = ap.parse_args()

    with tempfile.TemporaryDirectory(prefix="fpga39-") as td:
        td = Path(td)
        for width in WIDTHS:
            vf = td / f"w{width}.txt"
            rows = list(vectors(width, args.random))
            vf.write_text(
                "".join(
                    f"{a:x} {b:x} {cin:d} {s:x} {carry:d} {prod:x}\n"
                    for a, b, cin, s, carry, prod in rows
                ),
                encoding="ascii",
            )
            out = td / f"w{width}.vvp"
            subprocess.run([
                "iverilog", "-g2012", f"-Ptb_limb_kernel.W={width}",
                "-o", str(out),
                str(HERE / "limb_kernel.sv"),
                str(HERE / "tb_limb_kernel.sv"),
            ], cwd=ROOT, check=True)
            proc = subprocess.run(
                ["vvp", str(out), f"+VECTORS={vf}"],
                cwd=ROOT, check=True, text=True, capture_output=True,
            )
            print(proc.stdout.strip())

    print("PASS: host exact-integer oracle agrees for all widths")


if __name__ == "__main__":
    main()
