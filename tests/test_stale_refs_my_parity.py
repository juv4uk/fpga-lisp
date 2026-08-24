"""Parity check for the self-hosted stale-reference guard.

The Python script remains the bootstrap/reference implementation.  The
my-lisp program must agree on the current repository state before the Python
checker is retired from the operator path.
"""

from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
MY_LISP = Path("/home/agents/GitHub/my-lisp/target/release/my-lisp")


def _run(command):
    return subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        capture_output=True,
        timeout=30,
        check=False,
    )


class StaleReferenceParityTest(unittest.TestCase):
    def test_self_hosted_stale_reference_guard_matches_python(self):
        if not MY_LISP.exists():
            self.skipTest("release my-lisp binary not found")
        python = _run(["python3", "check_stale_refs.py"])
        my_lisp = _run([str(MY_LISP), "check-stale-refs.my"])
        self.assertEqual(python.returncode, 0, python.stdout + python.stderr)
        self.assertEqual(my_lisp.returncode, python.returncode, my_lisp.stdout + my_lisp.stderr)


if __name__ == "__main__":
    unittest.main()
