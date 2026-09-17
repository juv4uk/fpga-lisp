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

    def test_register_read_emits_observation_from_real_monitor_path(self):
        class FakeSerial:
            def __init__(self, reply):
                self.reply = bytearray(reply)
                self.writes = []

            def write(self, data):
                self.writes.append(bytes(data))

            def read(self, n):
                out = bytes(self.reply[:n])
                del self.reply[:n]
                return out

        class Recorder:
            def __init__(self):
                self.calls = []

            def record(self, **kwargs):
                self.calls.append(kwargs)

        import struct

        serial = FakeSerial(struct.pack("<I", 0x00000007))
        recorder = Recorder()
        MONITOR.cmd_reg(serial, 3, recorder=recorder)

        self.assertEqual(serial.writes, [bytes([0x01, 3])])
        self.assertEqual(len(recorder.calls), 1)
        self.assertEqual(recorder.calls[0]["input_event"], "monitor:reg:3")
        self.assertEqual(recorder.calls[0]["transition_or_action"], "read-register")
        self.assertEqual(recorder.calls[0]["state_after_ref"], "inline:R3=0x00000007")


if __name__ == "__main__":
    unittest.main()
