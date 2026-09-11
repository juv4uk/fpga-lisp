#!/usr/bin/env python3
"""Run the bounded my-lisp -> CML -> fpga-lisp shared-oracle witness.

This program deliberately stores no Lisp source or expected values.  It reads
the compiler-corpus blob from the pinned my-lisp Git revision, checks its
digest, selects ordinals 2 and 3, and compares a decoded RTL observation with
the upstream expected value.  The output directory is evidence, not a second
fixture authority.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
PIN_PATH = ROOT / "tools" / "shared_oracle_parity.pin"
SELECTED_ORDINALS = (2, 3)
RTL_SOURCES = (
    "fpga/rtl/lisp_word.sv",
    "fpga/rtl/heap.sv",
    "fpga/rtl/lisp_data_unit.sv",
    "fpga/rtl/registers.sv",
    "fpga/rtl/instruction_decoder.sv",
    "fpga/rtl/upc8_unit.sv",
    "fpga/rtl/sandhi_engine.sv",
    "fpga/rtl/control.sv",
    "fpga/rtl/uart.sv",
    "fpga/rtl/bootloader.sv",
    "fpga/rtl/lisp_machine.sv",
    "fpga/sim/tb_cml_e2e.sv",
)


class GateFailure(RuntimeError):
    """A fail-closed provenance, transport, or semantic comparison failure."""


@dataclass(frozen=True)
class Fixture:
    ordinal: int
    expression: str
    expected: str | None
    error: str | None
    raw: str


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if completed.returncode:
        raise GateFailure(
            f"command failed ({completed.returncode}): {' '.join(command)}\n{completed.stdout}"
        )
    return completed


def git_show(repo: Path, revision: str, path: str) -> bytes:
    completed = subprocess.run(
        ["git", "-C", str(repo), "show", f"{revision}:{path}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode:
        raise GateFailure(
            f"cannot read pinned upstream blob {revision}:{path} from {repo}: "
            f"{completed.stderr.decode(errors='replace')}"
        )
    return completed.stdout


def git_head(repo: Path) -> str:
    return run(["git", "-C", str(repo), "rev-parse", "HEAD"]).stdout.strip()


def git_status(repo: Path) -> list[str]:
    return run(["git", "-C", str(repo), "status", "--porcelain"]).stdout.splitlines()


def unescape_sexp_string(value: str) -> str:
    output: list[str] = []
    escaped = False
    escapes = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\"}
    for char in value:
        if escaped:
            output.append(escapes.get(char, char))
            escaped = False
        elif char == "\\":
            escaped = True
        else:
            output.append(char)
    if escaped:
        raise GateFailure("unterminated escape in compiler-corpus record")
    return "".join(output)


def string_field(record: str, field: str) -> str | None:
    marker = f'({field} . "'
    start = record.find(marker)
    if start < 0:
        return None
    index = start + len(marker)
    chars: list[str] = []
    escaped = False
    while index < len(record):
        char = record[index]
        if escaped:
            chars.extend(("\\", char))
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == '"':
            return unescape_sexp_string("".join(chars))
        else:
            chars.append(char)
        index += 1
    raise GateFailure(f"unterminated {field} string in compiler-corpus record")


def extract_compiler_corpus(blob: bytes) -> list[Fixture]:
    fixtures: list[Fixture] = []
    for raw in blob.decode("utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "(compiler-corpus . t)" not in line:
            continue
        expression = string_field(line, "expr")
        expected = string_field(line, "expected")
        error = string_field(line, "error")
        if expression is None or (expected is None and error is None) or (expected is not None and error is not None):
            raise GateFailure(f"malformed compiler-corpus record: {line}")
        fixtures.append(Fixture(len(fixtures) + 1, expression, expected, error, line))
    if len(fixtures) != 17:
        raise GateFailure(f"pinned compiler corpus must contain exactly 17 records, found {len(fixtures)}")
    return fixtures


def read_fpga_truth_representation() -> tuple[int, int]:
    word = (ROOT / "fpga/rtl/lisp_word.sv").read_text(encoding="utf-8")
    symbols = (ROOT / "fpga/asm/symbol-table.inc").read_text(encoding="utf-8")
    tag_match = re.search(r"TAG_SYMBOL\s*=\s*4'd(\d+)", word)
    t_match = re.search(r"^\.define\s+SYM_T\s+(\d+)\b", symbols, re.MULTILINE)
    if not tag_match or not t_match:
        raise GateFailure("cannot derive FPGA canonical t representation from authoritative files")
    return int(tag_match.group(1)), int(t_match.group(1))


def parse_observation(transcript: str) -> tuple[int, int]:
    tag_match = re.search(r"^RESULT_TAG:(\d+)$", transcript, re.MULTILINE)
    value_match = re.search(r"^RESULT_VAL:(\d+)$", transcript, re.MULTILINE)
    if "WATCHDOG TIMEOUT" in transcript:
        raise GateFailure("RTL simulation reached its watchdog")
    if "Machine Halted." not in transcript or not tag_match or not value_match:
        raise GateFailure(f"RTL transcript lacks a complete result observation:\n{transcript}")
    return int(tag_match.group(1)), int(value_match.group(1))


def decode_semantic_value(tag: int, value: int, truth: tuple[int, int]) -> str:
    symbol_tag, symbol_t = truth
    if (tag, value) == (symbol_tag, symbol_t):
        return "t"
    raise GateFailure(
        "unrecognized FPGA result representation "
        f"TAG:{tag} VAL:{value}; decoder is intentionally fail-closed"
    )


def coverage_reason(ordinal: int) -> str:
    reasons = {
        1: "not executed: first predicate slice starts at compiler-corpus ordinal 2",
        4: "not executed: next G2 car/cdr/cons data-shape slice",
        5: "not executed: next G2 car/cdr/cons data-shape slice",
        6: "not executed: next G2 car/cdr/cons data-shape slice",
        7: "not executed: next G8 cond branch slice",
        8: "exact rationals have no ratified FPGA representation contract",
        9: "not executed: closure identity slice",
        10: "not executed: named error-vocabulary slice",
        11: "not executed: tail-recursion slice",
        12: "not executed: dotted lambda-list ABI slice",
        13: "not executed: bare-symbol lambda-list ABI slice",
        14: "not executed: variadic arity-error slice",
        15: "not executed: lexical environment and shadowing slice",
        16: "not executed: immutable canonical-name error slice",
        17: "not executed: user macro-expansion slice",
    }
    return reasons[ordinal]


def target_contract_provenance(cml_dir: Path, target_dir: Path) -> dict[str, str]:
    cargo_toml = (cml_dir / "Cargo.toml").read_text(encoding="utf-8")
    match = re.search(r'wsm-target-contract\.git",\s*rev\s*=\s*"([0-9a-f]{40})"', cargo_toml)
    if not match:
        raise GateFailure("CML Cargo.toml has no pinned wsm-target-contract revision")
    revision = match.group(1)
    projection = git_show(target_dir, revision, "target-contract.wsm")
    return {
        "revision": revision,
        "projection_sha256": sha256_bytes(projection),
        "projection_path": "target-contract.wsm",
    }


def compile_simulator(out_dir: Path) -> Path:
    simulator = out_dir / "tb_cml_e2e.vvp"
    run(
        [
            "iverilog",
            "-g2012",
            "-I",
            "fpga/rtl",
            "-o",
            str(simulator),
            *RTL_SOURCES,
        ],
        cwd=ROOT,
    )
    return simulator


def run_fixture(
    fixture: Fixture,
    *,
    out_dir: Path,
    cml_bin: Path,
    simulator: Path,
    truth: tuple[int, int],
    comparison_expected: str | None = None,
) -> tuple[dict[str, Any], str]:
    if fixture.error is not None:
        raise GateFailure("first shared-oracle slice accepts value fixtures only")
    source_path = out_dir / f"corpus-{fixture.ordinal:02d}.my"
    asm_path = source_path.with_suffix(".asm")
    binary_path = source_path.with_suffix(".bin")
    source_path.write_text(fixture.expression + "\n", encoding="utf-8")
    compiled = run([str(cml_bin), str(source_path)])
    asm_path.write_text(compiled.stdout, encoding="utf-8")
    run(["python3", str(ROOT / "assembler.py"), str(asm_path)], cwd=out_dir)
    simulated = run(["vvp", str(simulator), f"+bin_file={binary_path}"], cwd=out_dir)
    transcript_path = out_dir / f"corpus-{fixture.ordinal:02d}.rtl.txt"
    transcript_path.write_text(simulated.stdout, encoding="utf-8")
    tag, value = parse_observation(simulated.stdout)
    actual = decode_semantic_value(tag, value, truth)
    expected = comparison_expected if comparison_expected is not None else fixture.expected
    if actual != expected:
        raise GateFailure(
            f"oracle mismatch at compiler-corpus ordinal {fixture.ordinal}: "
            f"expected {expected!r}, FPGA decoded {actual!r}"
        )
    record = {
            "ordinal": fixture.ordinal,
            "status": "confirmed",
            "source_sha256": sha256_bytes(fixture.expression.encode("utf-8")),
            "expected_sha256": sha256_bytes(fixture.expected.encode("utf-8")),
            "observation": {"tag": tag, "value": value, "decoded": actual},
            "assembly_sha256": sha256_file(asm_path),
            "image_sha256": sha256_file(binary_path),
            "symbol_sidecar_sha256": sha256_file(binary_path.with_suffix(".bin.sym")),
            "transcript": transcript_path.name,
            "transcript_sha256": sha256_file(transcript_path),
        }
    # The evidence keeps the image and its transcript, not a second copy of
    # the upstream source string or CML's readable assembly listing.
    source_path.unlink()
    asm_path.unlink()
    return record, actual


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--my-lisp-dir", type=Path, required=True)
    parser.add_argument("--cml-dir", type=Path, required=True)
    parser.add_argument("--cml-bin", type=Path, required=True)
    parser.add_argument("--target-contract-dir", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--mutation-witness", action="store_true")
    parser.add_argument(
        "--mutate-expected-ordinal",
        type=int,
        help="deliberately replace one upstream expected value; the gate must fail",
    )
    args = parser.parse_args()

    pin = json.loads(PIN_PATH.read_text(encoding="utf-8"))
    corpus = git_show(args.my_lisp_dir, pin["revision"], pin["path"])
    digest = sha256_bytes(corpus)
    if digest != pin["sha256"]:
        raise GateFailure(f"pinned corpus digest mismatch: expected {pin['sha256']}, got {digest}")
    fixtures = extract_compiler_corpus(corpus)
    selected = [fixtures[index - 1] for index in SELECTED_ORDINALS]
    args.out.mkdir(parents=True, exist_ok=True)
    truth = read_fpga_truth_representation()
    # The compiled .vvp is reproducible from the recorded RTL source digests;
    # it is an execution by-product, not a durable evidence artifact.
    simulator_dir = Path(tempfile.mkdtemp(prefix="fpga-shared-oracle-sim-"))
    simulator = compile_simulator(simulator_dir)

    result_records: list[dict[str, Any]] = []
    observations: dict[int, str] = {}
    for fixture in selected:
        comparison_expected = None
        if args.mutate_expected_ordinal == fixture.ordinal:
            comparison_expected = "()" if fixture.expected != "()" else "t"
        record, actual = run_fixture(
            fixture,
            out_dir=args.out,
            cml_bin=args.cml_bin,
            simulator=simulator,
            truth=truth,
            comparison_expected=comparison_expected,
        )
        result_records.append(record)
        observations[fixture.ordinal] = actual

    mutation: dict[str, Any] = {"status": "not-requested"}
    if args.mutation_witness:
        fixture = selected[0]
        mutated = "()" if fixture.expected != "()" else "t"
        # Exercise the exact same run_fixture comparison branch used by a
        # normal gate, but isolate its generated image in a disposable dir.
        # A mismatch is success for this negative witness; an accidental pass
        # is a failure of the evidence system itself.
        with tempfile.TemporaryDirectory(prefix="fpga-shared-oracle-mutation-") as temporary:
            try:
                run_fixture(
                    fixture,
                    out_dir=Path(temporary),
                    cml_bin=args.cml_bin,
                    simulator=simulator,
                    truth=truth,
                    comparison_expected=mutated,
                )
            except GateFailure as error:
                mutation = {
                    "status": "detected",
                    "ordinal": fixture.ordinal,
                    "mutated_expected_sha256": sha256_bytes(mutated.encode("utf-8")),
                    "comparator_rejected_mutation": True,
                    "red_gate_error": str(error),
                }
            else:
                raise GateFailure("mutation witness unexpectedly passed")

    coverage = []
    confirmed = {record["ordinal"] for record in result_records}
    for fixture in fixtures:
        entry: dict[str, Any] = {
            "ordinal": fixture.ordinal,
            "source_sha256": sha256_bytes(fixture.expression.encode("utf-8")),
            "expected_or_error_sha256": sha256_bytes((fixture.expected or fixture.error or "").encode("utf-8")),
        }
        if fixture.ordinal in confirmed:
            entry["status"] = "confirmed"
        else:
            entry["status"] = "unsupported"
            entry["reason"] = coverage_reason(fixture.ordinal)
        coverage.append(entry)

    provenance = {
        "my_lisp": {
            "repository": pin["upstream_repository"],
            "revision": pin["revision"],
            "corpus_path": pin["path"],
            "corpus_sha256": digest,
        },
        "cml": {
            "source_revision": git_head(args.cml_dir),
            "worktree_status": git_status(args.cml_dir),
            "binary_sha256": sha256_file(args.cml_bin),
        },
        "target_contract": target_contract_provenance(args.cml_dir, args.target_contract_dir),
        "fpga": {
            "source_revision": git_head(ROOT),
            "worktree_status": git_status(ROOT),
            "gate_sha256": sha256_file(Path(__file__)),
            "isa_contract_sha256": sha256_file(ROOT / "isa-contract.my"),
            "truth_representation": {"tag_symbol": truth[0], "sym_t": truth[1]},
            "rtl_source_sha256": {path: sha256_file(ROOT / path) for path in RTL_SOURCES},
            "simulator_sha256": sha256_file(simulator),
            "bitstream": {"status": "not-produced", "reason": "RTL-SIM evidence only"},
        },
        "physical": {
            "status": "not-run",
            "reason": "the CML-produced images in this gate were not loaded onto the board",
        },
    }
    result = {
        "schema": "fpga-shared-oracle-parity-v1",
        "scope": "compiler-corpus ordinals 2 and 3 only",
        "results": result_records,
        "mutation_witness": mutation,
        "provenance": provenance,
    }
    (args.out / "result.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (args.out / "coverage.json").write_text(
        json.dumps(
            {
                "schema": "fpga-shared-oracle-coverage-v1",
                "upstream_revision": pin["revision"],
                "corpus_sha256": digest,
                "fixtures": coverage,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    shutil.rmtree(simulator_dir)
    print(json.dumps({"status": "pass", "confirmed": SELECTED_ORDINALS, "out": str(args.out)}))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except GateFailure as error:
        print(f"shared-oracle gate failed: {error}", file=sys.stderr)
        raise SystemExit(1)
