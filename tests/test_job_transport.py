import importlib.util
import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("job_transport", ROOT / "job_transport.py")
BRIDGE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BRIDGE)


class JobTransportProtocolTest(unittest.TestCase):
    def test_parses_the_cml_v1_binary_request(self):
        request = b"CMLJ" + struct.pack(
            "<HBBHII", 1, 9, 0, 2, 0x11223344, 0xAABBCCDD
        )
        result_register, frame = BRIDGE.parse_request(request)
        self.assertEqual(result_register, 9)
        self.assertEqual(frame, struct.pack("<HII", 2, 0x11223344, 0xAABBCCDD))

    def test_preserves_the_isa_1_1_extended_register_input_frame(self):
        frame = (
            struct.pack("<HB", 0x8002, 2)
            + struct.pack("<BI", 0, 3)
            + struct.pack("<BI", 1, 4)
            + struct.pack("<II", 0xD2010000, 0xB0000000)
        )
        request = b"CMLJ" + struct.pack("<HBB", 1, 2, 0) + frame
        result_register, parsed_frame = BRIDGE.parse_request(request)
        self.assertEqual(result_register, 2)
        self.assertEqual(parsed_frame, frame)

    def test_rejects_duplicate_extended_register_inputs(self):
        frame = (
            struct.pack("<HB", 0x8001, 2)
            + struct.pack("<BI", 0, 3)
            + struct.pack("<BI", 0, 4)
            + struct.pack("<I", 0xB0000000)
        )
        with self.assertRaisesRegex(ValueError, "duplicate register input"):
            BRIDGE.parse_request(b"CMLJ" + struct.pack("<HBB", 1, 0, 0) + frame)

    def test_rejects_truncated_and_unversioned_requests(self):
        with self.assertRaises(ValueError):
            BRIDGE.parse_request(b"CMLJ")
        with self.assertRaises(ValueError):
            BRIDGE.parse_request(b"CMLJ" + struct.pack("<HBBHI", 2, 0, 0, 1, 0))


if __name__ == "__main__":
    unittest.main()
