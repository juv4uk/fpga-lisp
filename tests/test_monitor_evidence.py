import importlib.util
import json
import sys
import tempfile
import types
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.modules.setdefault("serial", types.SimpleNamespace())
SPEC = importlib.util.spec_from_file_location("monitor", ROOT / "monitor.py")
MONITOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MONITOR)


class MonitorEvidenceTest(unittest.TestCase):
    def test_builds_explicit_observation_record(self):
        record = MONITOR.make_observation_record(
            experiment_id="E0",
            run_id="run-1",
            input_event="monitor:reg:3",
            transition_or_action="read-register",
            state_after_ref="inline:R3=0x00000007",
            fpga_lisp_commit="abc123",
            build_or_bitstream_ref="bitstream:test.fs",
            cycle_or_timestamp="2026-09-18T00:00:00Z",
        )
        self.assertEqual(record["record_type"], "observation")
        self.assertEqual(record["status"], "OBSERVED")
        self.assertEqual(record["evidence_level"], "OBSERVED")
        self.assertEqual(record["state_before_ref"], "UNKNOWN")
        self.assertEqual(record["state_after_ref"], "inline:R3=0x00000007")
        self.assertEqual(record["fpga_lisp_commit"], "abc123")

    def test_appends_jsonl_without_rewriting_prior_observations(self):
        first = MONITOR.make_observation_record(
            experiment_id="E0",
            run_id="run-1",
            input_event="monitor:hp",
            transition_or_action="read-heap-pointer",
            state_after_ref="inline:HP=12",
            fpga_lisp_commit="abc123",
            build_or_bitstream_ref="UNKNOWN",
            cycle_or_timestamp="2026-09-18T00:00:00Z",
        )
        second = MONITOR.make_observation_record(
            experiment_id="E0",
            run_id="run-1",
            input_event="monitor:err",
            transition_or_action="read-error-state",
            state_after_ref="inline:ERR=none",
            fpga_lisp_commit="abc123",
            build_or_bitstream_ref="UNKNOWN",
            cycle_or_timestamp="2026-09-18T00:00:01Z",
        )
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "observations.jsonl"
            MONITOR.append_observation(path, first)
            MONITOR.append_observation(path, second)
            rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]
        self.assertEqual(rows, [first, second])


if __name__ == "__main__":
    unittest.main()
