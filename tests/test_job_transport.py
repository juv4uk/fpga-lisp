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

    def test_rejects_truncated_and_unversioned_requests(self):
        with self.assertRaises(ValueError):
            BRIDGE.parse_request(b"CMLJ")
        with self.assertRaises(ValueError):
            BRIDGE.parse_request(b"CMLJ" + struct.pack("<HBBHI", 2, 0, 0, 1, 0))


if __name__ == "__main__":
    unittest.main()
