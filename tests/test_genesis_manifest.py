import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("genesis_manifest", ROOT / "genesis_manifest.py")
GENESIS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENESIS)


class GenesisManifestTest(unittest.TestCase):
    def test_builds_manifest_without_guessing_unknown_state(self):
        manifest = GENESIS.build_manifest(
            timestamp="2026-09-18T00:00:00Z",
            fpga_lisp_commit="abc123",
            build_or_bitstream_ref="bitstream:e0.fs",
            fpga_target="GW5A-25A",
            toolchain="Gowin EDA",
            program_ref="bootstrap_nullp_demo.bin",
            initial_register_state_ref=None,
            initial_memory_state_ref=None,
            enabled_mechanisms_ref="isa-contract-v1",
            external_interfaces=["UART"],
            seed_or_determinism="deterministic reset; no PRNG",
            explicitly_absent_mechanisms=["GC"],
            notes=None,
        )
        self.assertEqual(manifest["schema"], "shunya-bhumi-genesis-v0")
        self.assertEqual(manifest["fpga_lisp_commit"], "abc123")
        self.assertEqual(manifest["initial_register_state_ref"], "UNKNOWN")
        self.assertEqual(manifest["initial_memory_state_ref"], "UNKNOWN")
        self.assertEqual(manifest["explicitly_absent_mechanisms"], ["GC"])

    def test_write_manifest_refuses_to_overwrite_existing_genesis(self):
        manifest = GENESIS.build_manifest(
            timestamp="2026-09-18T00:00:00Z",
            fpga_lisp_commit="abc123",
            build_or_bitstream_ref="UNKNOWN",
            fpga_target="UNKNOWN",
            toolchain="UNKNOWN",
            program_ref="UNKNOWN",
            initial_register_state_ref=None,
            initial_memory_state_ref=None,
            enabled_mechanisms_ref="UNKNOWN",
            external_interfaces=[],
            seed_or_determinism="UNKNOWN",
            explicitly_absent_mechanisms=[],
            notes=None,
        )
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "genesis.json"
            GENESIS.write_manifest(path, manifest)
            with self.assertRaises(FileExistsError):
                GENESIS.write_manifest(path, manifest)
            loaded = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(loaded, manifest)


if __name__ == "__main__":
    unittest.main()
