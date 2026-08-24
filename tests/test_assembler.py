import importlib.util
import unittest


ROOT = __import__("pathlib").Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("assembler", ROOT / "assembler.py")
ASSEMBLER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ASSEMBLER)


class SymbolInterningTest(unittest.TestCase):
    def test_interns_symbolic_loadsym_operands_per_program(self):
        machine_code, symbols = ASSEMBLER.assemble_with_symbols(
            [
                "LOADSYM R1 FOO",
                "LOADSYM R2 FOO",
                "LOADSYM R3 BAR",
                "HALT",
            ]
        )
        self.assertEqual(symbols, {"FOO": 900, "BAR": 901})
        self.assertEqual(machine_code[0], (9 << 28) | (1 << 24) | 900)
        self.assertEqual(machine_code[1], (9 << 28) | (2 << 24) | 900)
        self.assertEqual(machine_code[2], (9 << 28) | (3 << 24) | 901)

    def test_preserves_numeric_loadsym_operands(self):
        machine_code, symbols = ASSEMBLER.assemble_with_symbols(
            ["LOADSYM R1 42", "HALT"]
        )
        self.assertEqual(symbols, {})
        self.assertEqual(machine_code[0], (9 << 28) | (1 << 24) | 42)


if __name__ == "__main__":
    unittest.main()
