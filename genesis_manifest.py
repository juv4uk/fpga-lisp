import json
from pathlib import Path


SCHEMA = "shunya-bhumi-genesis-v0"


def _unknown(value):
    return "UNKNOWN" if value is None else value


def build_manifest(
    *,
    timestamp,
    fpga_lisp_commit,
    build_or_bitstream_ref,
    fpga_target,
    toolchain,
    program_ref,
    initial_register_state_ref,
    initial_memory_state_ref,
    enabled_mechanisms_ref,
    external_interfaces,
    seed_or_determinism,
    explicitly_absent_mechanisms,
    notes,
):
    return {
        "schema": SCHEMA,
        "timestamp": timestamp,
        "fpga_lisp_commit": _unknown(fpga_lisp_commit),
        "build_or_bitstream_ref": _unknown(build_or_bitstream_ref),
        "fpga_target": _unknown(fpga_target),
        "toolchain": _unknown(toolchain),
        "program_ref": _unknown(program_ref),
        "initial_register_state_ref": _unknown(initial_register_state_ref),
        "initial_memory_state_ref": _unknown(initial_memory_state_ref),
        "enabled_mechanisms_ref": _unknown(enabled_mechanisms_ref),
        "external_interfaces": list(external_interfaces),
        "seed_or_determinism": _unknown(seed_or_determinism),
        "explicitly_absent_mechanisms": list(explicitly_absent_mechanisms),
        "notes": notes,
    }


def write_manifest(path, manifest):
    path = Path(path)
    with path.open("x", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
