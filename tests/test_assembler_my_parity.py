"""Differential smoke tests for the my-lisp self-hosted assembler."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MY_LISP = Path("/home/agents/GitHub/my-lisp/target/release/my-lisp")


class MyLispAssemblerParityTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        configured = os.environ.get("MY_LISP_BIN")
        cls.my_lisp = Path(configured) if configured else DEFAULT_MY_LISP
        if not cls.my_lisp.is_file():
            raise unittest.SkipTest(
                "release my-lisp binary not found; set MY_LISP_BIN to enable parity tests"
            )

    def assert_fixture_matches_python(self, fixture):
        with tempfile.TemporaryDirectory(prefix="fpga-assembler-parity-") as temp:
            temp = Path(temp)
            python_bin = temp / "python.bin"
            my_lisp_bin = temp / "my-lisp.bin"
            subprocess.run(
                ["python3", "assembler.py", fixture, "-o", str(python_bin)],
                cwd=ROOT,
                check=True,
                capture_output=True,
                text=True,
                timeout=60,
            )
            subprocess.run(
                [str(self.my_lisp), "assembler.my", fixture, str(my_lisp_bin)],
                cwd=ROOT,
                check=True,
                capture_output=True,
                text=True,
                timeout=60,
            )
            self.assertEqual(python_bin.read_bytes(), my_lisp_bin.read_bytes(), fixture)

    def test_all_repo_fixtures(self):
        for fixture in (
            "call_demo.asm",
            "bootstrap_add_demo.asm",
            "bootstrap_pair_demo.asm",
            "bootstrap_length_onto_demo.asm",
            "bootstrap_equal_demo.asm",
            "lambda_demo.asm",
            "eval_quote_demo.asm",
            "bootstrap_append_demo.asm",
            "bootstrap_caar_demo.asm",
            "bootstrap_not_demo.asm",
            "bootstrap_nullp_demo.asm",
            "bootstrap_reverse_demo.asm",
            "bootstrap_length_demo.asm",
            "bootstrap_second_demo.asm",
            "bootstrap_third_demo.asm",
            "bootstrap_triple_demo.asm",
            "control_demo.asm",
            "echo_list.asm",
            "env_demo.asm",
            "eval_all_primitives_demo.asm",
            "eval_apply_demo.asm",
            "eval_atom_demo.asm",
            "eval_cond_demo.asm",
            "eval_primitive_demo.asm",
            "list_demo.asm",
            "monitor_demo.asm",
            "setcdr_demo.asm",
            "test_memory.asm",
        ):
            with self.subTest(fixture=fixture):
                self.assert_fixture_matches_python(fixture)


if __name__ == "__main__":
    unittest.main()
