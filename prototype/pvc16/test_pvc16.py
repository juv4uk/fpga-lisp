"""Unit tests for PVC-16 Hardware & Python Model."""

import unittest
from pvc16 import REGISTRY, get_phoneme

class TestPVC16(unittest.TestCase):
    def test_vowel_classification(self):
        a = get_phoneme("a")
        k = get_phoneme("k")
        self.assertTrue(a.is_vowel)
        self.assertFalse(k.is_vowel)
        self.assertTrue(k.is_consonant)

    def test_savarna_homogeneity_sutra_1_1_9(self):
        a = get_phoneme("a")
        A = get_phoneme("A")
        i = get_phoneme("i")
        k = get_phoneme("k")
        K = get_phoneme("K")
        t = get_phoneme("t")

        # Short and Long 'a' have same Sthana (Kanthya) and Prayatna -> Savarna
        self.assertTrue(a.is_savarna_with(A))
        # 'a' and 'i' differ in Sthana -> Not Savarna
        self.assertFalse(a.is_savarna_with(i))
        # 'k' and 'kh' have same Sthana and Sprsta -> Savarna
        self.assertTrue(k.is_savarna_with(K))
        # 'k' (velar) and 't' (dental) -> Not Savarna
        self.assertFalse(k.is_savarna_with(t))

    def test_voicing_transformation(self):
        k = get_phoneme("k")
        self.assertFalse(k.is_voiced)
        g_derived = k.with_voicing(True)
        self.assertTrue(g_derived.is_voiced)
        self.assertEqual(g_derived.sthana_mask, k.sthana_mask)

    def test_palatalization_modifier(self):
        t_soft = get_phoneme("т'")
        self.assertTrue(t_soft.is_palatalized)
        self.assertTrue(t_soft.is_consonant)

if __name__ == "__main__":
    unittest.main()
