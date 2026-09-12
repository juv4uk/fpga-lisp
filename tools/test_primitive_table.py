#!/usr/bin/env python3
"""Evidence tests for the Canon primitive execution table
(tools/gen_primitive_table.py).

Proves two things fpga-lisp needs to demonstrate, per the Canon
migration plan (2026-09-11):

1. Every declared surface (en/uk/sa/sym, where the registry marks it
   present) of a Canon-bridged primitive resolves to the SAME
   generated-table entry -- one semantic identity, one execution
   mechanism, regardless of which language named it.
2. An ordinary quoted user/data symbol (e.g. 'radio', 'RADIO') is NOT
   a Canon identity and therefore never appears in, or is reachable
   through, the primitive execution table -- Canon and ordinary
   symbol ids stay in separate namespaces, per
   docs/canon-symbol-registry-fpga-lisp-part.md and
   docs/shared-oracle-parity-2-symbol-identity-gate.md.

This is a Python-level proof over the generated table, not a claim
that fpga-lisp hardware parses Ukrainian/Sanskrit source text --
fpga-lisp has no such reader. What is proven is that the TABLE itself
-- the thing any future evaluator/tooling dispatch would consult -- is
surface-agnostic and does not conflate Canon identities with ordinary
data.
"""
import unittest

from gen_primitive_table import build_table


class TestPrimitiveTableSurfaceParity(unittest.TestCase):
    def setUp(self):
        self.table = build_table()
        # Reverse index: surface spelling -> canon_id, restricted to
        # exactly the Canon ids this table declares (the same index an
        # evaluator/LSP-style dispatch would build).
        self.surface_index = {}
        for canon_id, entry in self.table.items():
            for word in entry["surfaces"].values():
                self.surface_index.setdefault(word, set()).add(canon_id)

    def test_car_surfaces_share_one_execution_entry(self):
        car_entry = self.table["0005"]
        surfaces = car_entry["surfaces"]
        # en/uk/sa must all be present and stable for car (checked by
        # build_table's own fail-closed validation already).
        self.assertEqual(surfaces["en"], "car")
        self.assertIn("uk", surfaces)
        self.assertIn("sa", surfaces)
        for word in surfaces.values():
            self.assertEqual(
                self.surface_index[word],
                {"0005"},
                f"surface {word!r} must resolve to exactly Canon 0005 (car)",
            )
        self.assertEqual(car_entry["local_primitive_id"], 0)
        self.assertEqual(car_entry["opcode"], "OP_CAR")

    def test_all_spec_primitives_are_surface_unambiguous(self):
        # No surface spelling may be shared by two different Canon ids
        # in this table -- if it were, one language's word for one
        # primitive would silently alias another primitive.
        for word, ids in self.surface_index.items():
            self.assertEqual(
                len(ids), 1, f"surface {word!r} is ambiguous across Canon ids {ids}"
            )

    def test_ordinary_data_symbols_are_not_canon_identities(self):
        # 'radio'/'RADIO' are the exact pair from
        # docs/shared-oracle-parity-2-symbol-identity-gate.md's
        # confirmed cml collision -- neither is, or should ever become,
        # a Canon semantic id. They must not appear anywhere in the
        # primitive table's surface index.
        for ordinary_symbol in ("radio", "RADIO", "foo", "atom-but-user-defined"):
            self.assertNotIn(
                ordinary_symbol,
                self.surface_index,
                f"ordinary data symbol {ordinary_symbol!r} must never be "
                f"reachable through the Canon primitive execution table",
            )

    def test_all_six_first_wave_primitives_present(self):
        # The plan's explicit ABI: car=0, cdr=1, cons=2, atom=3, eq=4, add=5.
        expected = {
            "0005": 0,
            "0006": 1,
            "0004": 2,
            "0002": 3,
            "0003": 4,
            "0104": 5,
        }
        for canon_id, local_id in expected.items():
            self.assertIn(canon_id, self.table)
            self.assertEqual(self.table[canon_id]["local_primitive_id"], local_id)


if __name__ == "__main__":
    unittest.main()
