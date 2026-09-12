#!/usr/bin/env python3
"""Generate fpga-lisp's Canon-id -> local-primitive execution table.

Bridges two separate namespaces, deliberately kept apart per
docs/canon-symbol-registry-fpga-lisp-part.md and the swarm's Canon
migration plan (2026-09-11):

  - Canon semantic id: my-lisp's authority (lib/surface/semantic-registry.wsm),
    identity of a *language* form (quote/car/cdr/...), independent of
    spelling (en/uk/sa/sym are just names for the same id).
  - local primitive id: fpga-lisp's own authority (fpga/asm/constants.inc's
    PRIM_* values), the *hardware execution* ABI. This is never
    renumbered by a Canon change -- see constants.inc's own header.

fpga/canon/execution-spec.my is the small, hand-maintained bridge
between the two. This script reads it plus the real
semantic-registry.wsm and semantic-registry.wsm-relative constants.inc,
validates them against each other, and emits the generated table.
Fails closed (raises, does not fall back to a guess or an empty table)
if:
  - the registry file is missing,
  - a spec'd Canon id does not exist in the registry,
  - a spec'd Canon id has no 'stable' surface at all in the registry,
  - the registry's "en" surface for a Canon id is present but
    disagrees with the spec's expected-en-spelling sanity field,
  - a spec'd local-primitive-id does not match constants.inc's PRIM_*
    value of the same name,
  - two spec entries claim the same Canon id or the same local
    primitive id.

Usage: python3 tools/gen_primitive_table.py
Prints the generated table as a Python literal to stdout.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEC_PATH = os.path.join(ROOT, "fpga", "canon", "execution-spec.my")
REGISTRY_PATH = os.path.join(ROOT, "..", "my-lisp", "lib", "surface", "semantic-registry.wsm")
CONSTANTS_PATH = os.path.join(ROOT, "fpga", "asm", "constants.inc")

SPEC_LINE_RE = re.compile(
    r"^\s*\((\d{4})\s+(\S+)\s+(\d+)\s+(\S+)\)\s*$"
)
REGISTRY_ENTRY_RE = re.compile(r"^\s*\((\d{4})\s+(.*)\)\)\s*$")
REGISTRY_SURFACE_RE = re.compile(r"\((en|uk|sa|sym)\s+(\S+)\s+(\S+)\)")
CONSTANTS_DEFINE_RE = re.compile(r"^\s*\.define\s+(PRIM_\S+)\s+(\d+)")


def parse_spec(path):
    entries = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            m = SPEC_LINE_RE.match(line)
            if m:
                canon_id, expected_en, local_id, opcode = m.groups()
                entries.append(
                    {
                        "canon_id": canon_id,
                        "expected_en": expected_en,
                        "local_primitive_id": int(local_id),
                        "opcode": opcode,
                    }
                )
    return entries


def parse_registry(path):
    """canon_id -> {surface: (word, admission)}"""
    registry = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            m = REGISTRY_ENTRY_RE.match(line)
            if not m:
                continue
            canon_id, rest = m.groups()
            surfaces = {}
            for sm in REGISTRY_SURFACE_RE.finditer(rest):
                kind, word, admission = sm.groups()
                surfaces[kind] = (word, admission)
            registry[canon_id] = surfaces
    return registry


def parse_constants(path):
    """PRIM_NAME -> int value"""
    prims = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            m = CONSTANTS_DEFINE_RE.match(line)
            if m:
                prims[m.group(1)] = int(m.group(2))
    return prims


def build_table(spec_path=SPEC_PATH, registry_path=REGISTRY_PATH, constants_path=CONSTANTS_PATH):
    spec = parse_spec(spec_path)
    registry = parse_registry(registry_path)
    constants = parse_constants(constants_path)

    seen_canon = set()
    seen_local = set()
    table = {}

    for entry in spec:
        canon_id = entry["canon_id"]
        local_id = entry["local_primitive_id"]
        opcode = entry["opcode"]
        expected_en = entry["expected_en"]

        if canon_id in seen_canon:
            raise ValueError(f"duplicate Canon id {canon_id} in {spec_path}")
        if local_id in seen_local:
            raise ValueError(f"duplicate local primitive id {local_id} in {spec_path}")
        seen_canon.add(canon_id)
        seen_local.add(local_id)

        if canon_id not in registry:
            raise ValueError(
                f"Canon id {canon_id} (spec expects '{expected_en}') does not "
                f"exist in {registry_path}"
            )
        surfaces = registry[canon_id]

        if not any(admission == "stable" for _, admission in surfaces.values()):
            raise ValueError(
                f"Canon id {canon_id} has no 'stable' surface in the registry "
                f"-- refusing to bind hardware execution to an unstable identity"
            )

        en_word, en_admission = surfaces.get("en", (None, "missing"))
        if en_word is not None and en_word != "—" and en_word != expected_en:
            raise ValueError(
                f"Canon id {canon_id}: registry's en surface is "
                f"'{en_word}', spec expected '{expected_en}' -- spec is stale "
                f"or pointing at the wrong id"
            )

        prim_const_name = f"PRIM_{expected_en.upper()}"
        if prim_const_name not in constants:
            raise ValueError(
                f"{constants_path} has no {prim_const_name} .define for spec "
                f"entry {canon_id}/{expected_en}"
            )
        if constants[prim_const_name] != local_id:
            raise ValueError(
                f"spec says Canon {canon_id}/{expected_en} -> local primitive "
                f"id {local_id}, but {constants_path}'s {prim_const_name} is "
                f"{constants[prim_const_name]} -- spec and constants.inc "
                f"disagree"
            )

        table[canon_id] = {
            "surfaces": {k: v[0] for k, v in surfaces.items() if v[0] != "—"},
            "local_primitive_id": local_id,
            "local_primitive_name": prim_const_name,
            "opcode": opcode,
        }

    return table


def main():
    table = build_table()
    print("# Auto-generated by tools/gen_primitive_table.py -- do not edit by hand.")
    print("# Source of truth: fpga/canon/execution-spec.my + my-lisp's")
    print("# lib/surface/semantic-registry.wsm + fpga/asm/constants.inc.")
    print("CANON_PRIMITIVE_TABLE = {")
    for canon_id in sorted(table):
        entry = table[canon_id]
        print(f"    {canon_id!r}: {entry!r},")
    print("}")


if __name__ == "__main__":
    main()
