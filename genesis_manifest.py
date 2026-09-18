import argparse
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


def build_arg_parser():
    parser = argparse.ArgumentParser(description="Emit one immutable ŚŪNYA-BHŪMI Genesis manifest")
    parser.add_argument("--output", required=True)
    parser.add_argument("--timestamp", required=True)
    parser.add_argument("--fpga-lisp-commit", required=True)
    parser.add_argument("--build-or-bitstream-ref", default="UNKNOWN")
    parser.add_argument("--fpga-target", default="UNKNOWN")
    parser.add_argument("--toolchain", default="UNKNOWN")
    parser.add_argument("--program-ref", default="UNKNOWN")
    parser.add_argument("--initial-register-state-ref", default="UNKNOWN")
    parser.add_argument("--initial-memory-state-ref", default="UNKNOWN")
    parser.add_argument("--enabled-mechanisms-ref", default="UNKNOWN")
    parser.add_argument("--external-interface", action="append", default=[])
    parser.add_argument("--seed-or-determinism", default="UNKNOWN")
    parser.add_argument("--absent-mechanism", action="append", default=[])
    parser.add_argument("--notes")
    return parser


def main(argv=None):
    args = build_arg_parser().parse_args(argv)
    manifest = build_manifest(
        timestamp=args.timestamp,
        fpga_lisp_commit=args.fpga_lisp_commit,
        build_or_bitstream_ref=args.build_or_bitstream_ref,
        fpga_target=args.fpga_target,
        toolchain=args.toolchain,
        program_ref=args.program_ref,
        initial_register_state_ref=args.initial_register_state_ref,
        initial_memory_state_ref=args.initial_memory_state_ref,
        enabled_mechanisms_ref=args.enabled_mechanisms_ref,
        external_interfaces=args.external_interface,
        seed_or_determinism=args.seed_or_determinism,
        explicitly_absent_mechanisms=args.absent_mechanism,
        notes=args.notes,
    )
    write_manifest(args.output, manifest)
    return manifest


if __name__ == "__main__":
    main()
