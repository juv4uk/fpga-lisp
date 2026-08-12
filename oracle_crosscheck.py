#!/usr/bin/env python3
"""Automate the manual "run this bootstrap demo on real iverilog, then
query my-lisp's TCP oracle for the same expression, diff the two"
pattern that M29-M32 each did by hand, one query at a time (see
docs/lisp-machine-plan.md's M31/M32 entries).

Scope: fixnum/boolean-ish results only (R9 == a plain TAG:VAL word),
where the testbench's own $display already prints "R9 ... = TAG:%d
VAL:%d" or equivalent. CONS-structure results (M30 reverse, M31
append) need a heap-walk decode this script does not attempt --
documented as a known gap, not silently skipped without a trace.

Usage (from a Guix shell with iverilog + connectivity to the my-lisp
oracle):
    python3 oracle_crosscheck.py

Requires: the relevant .vvp files already built (see docs/testing.md's
compile command), and a my-lisp --tcp=<port> --protocol=sexpr server
reachable via --connect. MYLISP_CONNECT env var overrides the default
127.0.0.1:9999.
"""
import os
import re
import subprocess
import sys

MYLISP_BIN = os.environ.get("MYLISP_BIN", "/mnt/c/GitHub/my-lisp/target/debug/my-lisp")
MYLISP_CONNECT = os.environ.get("MYLISP_CONNECT", "127.0.0.1:9999")

# (testbench, my-lisp expression, expected-shape)
# expected-shape: "fixnum" -- compare VAL as an integer against the
# oracle's numeric response; "truthy" -- oracle response non-() means
# TAG must be non-NIL (structural match not attempted, matches this
# repo's own M32 testbench convention).
CASES = [
    ("tb_bootstrap_length", "(length (quote (a b c)))", "fixnum"),
    ("tb_bootstrap_length_onto", "(length (quote (a b c)))", "fixnum"),
    ("tb_bootstrap_equal", "(equal? (quote (p . q)) (quote (p . q)))", "truthy"),
]

R9_RE = re.compile(r"R9.*?TAG:(\d+)\s+VAL:(\d+)")
TAG_NIL = 3


def query_oracle(expr):
    req = f'(request (id 1) (op eval) (source "{expr}"))\n'
    result = subprocess.run(
        [MYLISP_BIN, f"--connect={MYLISP_CONNECT}"],
        input=req, capture_output=True, text=True, timeout=10,
    )
    m = re.search(r"\(value (.*?)\) \(output", result.stdout)
    if not m:
        return None, result.stdout.strip()
    return m.group(1), result.stdout.strip()


def run_testbench(tb):
    vvp_file = f"{tb}.vvp"
    if not os.path.exists(vvp_file):
        return None, f"{vvp_file} not built -- see docs/testing.md's compile command"
    # Some of these (M28's non-tail-recursive length especially) run for
    # well over a minute of real wall-clock time even without VCD
    # dumping -- 60s was measured to be too tight, see
    # ecosystem-status.md-style history of "is this hung or just slow"
    # confusion elsewhere in this repo's own testbenches.
    result = subprocess.run(["vvp", vvp_file], capture_output=True, text=True, timeout=240)
    m = R9_RE.search(result.stdout)
    if not m:
        return None, f"could not find R9 TAG:/VAL: line in vvp output:\n{result.stdout}"
    return (int(m.group(1)), int(m.group(2))), None


def main():
    fail = False
    for tb, expr, shape in CASES:
        print(f"=== {tb}: {expr} ===")
        oracle_value, oracle_raw = query_oracle(expr)
        hw_result, hw_err = run_testbench(tb)

        if oracle_value is None:
            print(f"  ORACLE FAILED: {oracle_raw}")
            fail = True
            continue
        if hw_result is None:
            print(f"  HARDWARE FAILED: {hw_err}")
            fail = True
            continue

        hw_tag, hw_val = hw_result
        print(f"  oracle: {oracle_value}")
        print(f"  hardware: TAG:{hw_tag} VAL:{hw_val}")

        if shape == "fixnum":
            ok = str(hw_val) == oracle_value.strip()
        elif shape == "truthy":
            oracle_truthy = oracle_value.strip() != "()"
            hw_truthy = hw_tag != TAG_NIL
            ok = oracle_truthy == hw_truthy
        else:
            ok = False

        print("  MATCH" if ok else "  MISMATCH")
        fail = fail or not ok

    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
