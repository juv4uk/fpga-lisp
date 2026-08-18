#!/usr/bin/env python3
"""Wake-up reconciliation check: does this repo's own prose (AGENTS.md,
README.md) claim a version for isa-contract.my / language-contract.my
that disagrees with the live machine-readable value?

Closes FPGA-STALE-REF-CHECK -- universal swarm rule #2 (2026-08-18):
"Prose never outranks a machine-readable contract." Written after
AGENTS.md was found still claiming language-contract "1.0" while the
live file had moved to 2.0 (commit 6bc53d6) -- this makes that check
repeatable instead of relying on a human/agent noticing by chance on
each wake-up.

Usage: python3 check_stale_refs.py
Exit code 0 if no drift found, 1 if any prose claim disagrees with the
live contract (or a contract file the script expects isn't found --
loudly, not silently skipped).
"""
import re
import sys
from pathlib import Path

# (contract file, live-version regex, prose files to scan, prose-claim regex)
CHECKS = [
    (
        "isa-contract.my",
        re.compile(r"\(version \. \((\d+) (\d+)\)\)"),
        ["AGENTS.md", "README.md"],
        re.compile(r"isa-contract\.my`?,? version (\d+)\.(\d+)"),
    ),
    (
        "../my-lisp/language-contract.my",
        re.compile(r"\(major \. (\d+)\) \(minor \. (\d+)\)"),
        ["AGENTS.md", "README.md"],
        re.compile(r"[Ll]anguage contract version \*?\*?(\d+)\.(\d+)"),
    ),
]


def find_live_version(path, pattern):
    p = Path(path)
    if not p.exists():
        print(f"MISSING: {path} not found -- cannot check drift against it")
        return None
    text = p.read_text(encoding="utf-8")
    m = pattern.search(text)
    if not m:
        print(f"WARNING: {path} exists but version pattern not found -- check the regex, not silently passing")
        return None
    return (int(m.group(1)), int(m.group(2)))


def find_prose_claims(files, pattern):
    claims = []
    for f in files:
        p = Path(f)
        if not p.exists():
            continue
        text = p.read_text(encoding="utf-8")
        for m in pattern.finditer(text):
            claims.append((f, int(m.group(1)), int(m.group(2))))
    return claims


def main():
    drift_found = False
    for contract_path, version_re, prose_files, claim_re in CHECKS:
        live = find_live_version(contract_path, version_re)
        claims = find_prose_claims(prose_files, claim_re)
        if live is None:
            continue
        if not claims:
            print(f"OK: {contract_path} is live at {live[0]}.{live[1]}, no prose claims found to check (nothing to drift)")
            continue
        for f, major, minor in claims:
            if (major, minor) != live:
                print(f"DRIFT: {f} claims {contract_path} is {major}.{minor}, but it is actually {live[0]}.{live[1]}")
                drift_found = True
            else:
                print(f"OK: {f}'s claim about {contract_path} ({major}.{minor}) matches live")

    return 1 if drift_found else 0


if __name__ == "__main__":
    sys.exit(main())
