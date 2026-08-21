"""Unit tests and Golden Reference Model for FPGA Lisp Phonetic ALU."""

import unittest

# Sthāna Place Bits [5:1]
STHANA_NONE      = 0 << 1
STHANA_KANTHYA   = 1 << 1  # Velar: a, k, kh, g, gh, nG, h
STHANA_TALAVYA   = 2 << 1  # Palatal: i, c, ch, j, jh, nY, y, S
STHANA_MURDHANYA = 3 << 1  # Retroflex: R, T, Th, D, Dh, N, r, z
STHANA_DANTYA    = 4 << 1  # Dental: L, t, th, d, dh, n, l, s
STHANA_OSHTHYA   = 5 << 1  # Labial: u, p, ph, b, bh, m, v

# Prayatna Manner Bits [9:6]
PRAYATNA_SPRSTA    = 1 << 6  # Stop (k, c, T, t, p)
PRAYATNA_MAHAPRANA = 1 << 7  # Aspirate (kh, gh, ch, jh)
PRAYATNA_GHOSHA    = 1 << 8  # Voiced (g, gh, j, jh, d, dh, b, bh, nasals)
PRAYATNA_ANUNASIKA = 1 << 9  # Nasal (nG, nY, N, n, m)

FLAG_VOWEL         = 1 << 0  # 1 = Vowel (ac), 0 = Consonant (hal)
MOD_PALATALIZED    = 1 << 14 # Soft sign modifier [ь]

# 42 Classical Pratyāhāra Bitmask Dictionary
CANON_MASKS = {
    "ac":   0x00000000000001FF,
    "ak":   0x000000000000001F,
    "ik":   0x000000000000001E,
    "uk":   0x000000000000001C,
    "hal":  0x000003FFFFFFFFFE00,
    "al":   0x000003FFFFFFFFFF,
    "yaR":  0x0000000000003C00,
    "jaS":  0x000000001F000000,
    "JaS":  0x000000001FFE0000,
    "Kar":  0x000003FFE0000000,
    "Sar":  0x0000038000000000,
}

class GoldenAluModel:
    """Software Bit-Accurate Reference Model for FPGA Phonetic ALU."""

    @staticmethod
    def is_savarna(sound_a: int, sound_b: int) -> bool:
        """Sūtra 1.1.9: tulyāsyaprayatnaṁ savarṇam."""
        sth_a = (sound_a >> 1) & 0x1F
        sth_b = (sound_b >> 1) & 0x1F
        if sth_a == 0 or sth_b == 0 or sth_a != sth_b:
            return False
        same_stop = bool(sound_a & PRAYATNA_SPRSTA) == bool(sound_b & PRAYATNA_SPRSTA)
        same_vowel = bool(sound_a & FLAG_VOWEL) == bool(sound_b & FLAG_VOWEL)
        return same_stop and same_vowel

    @staticmethod
    def voice(sound: int) -> int:
        return sound | PRAYATNA_GHOSHA

    @staticmethod
    def devoice(sound: int) -> int:
        return sound & ~PRAYATNA_GHOSHA

    @staticmethod
    def palatalize(sound: int) -> int:
        return sound | MOD_PALATALIZED

    @staticmethod
    def depalatalize(sound: int) -> int:
        return sound & ~MOD_PALATALIZED

    @staticmethod
    def pratyahara_test(sound_code: int, mask: int) -> bool:
        if 0 <= sound_code < 42:
            return bool((mask >> sound_code) & 1)
        return False


class TestFpgaAlu(unittest.TestCase):
    def setUp(self):
        self.model = GoldenAluModel()
        self.a_short = FLAG_VOWEL | STHANA_KANTHYA | PRAYATNA_GHOSHA | (1 << 10)
        self.a_long  = FLAG_VOWEL | STHANA_KANTHYA | PRAYATNA_GHOSHA | (2 << 10)
        self.i_short = FLAG_VOWEL | STHANA_TALAVYA  | PRAYATNA_GHOSHA | (1 << 10)
        self.k_stop  = STHANA_KANTHYA | PRAYATNA_SPRSTA
        self.kh_stop = STHANA_KANTHYA | PRAYATNA_SPRSTA | PRAYATNA_MAHAPRANA
        self.g_stop  = STHANA_KANTHYA | PRAYATNA_SPRSTA | PRAYATNA_GHOSHA
        self.t_stop  = STHANA_DANTYA  | PRAYATNA_SPRSTA

    def test_savarna_homogeneity(self):
        self.assertTrue(self.model.is_savarna(self.a_short, self.a_long))
        self.assertFalse(self.model.is_savarna(self.a_short, self.i_short))
        self.assertTrue(self.model.is_savarna(self.k_stop, self.kh_stop))
        self.assertFalse(self.model.is_savarna(self.k_stop, self.t_stop))

    def test_voicing_transformation(self):
        voiced_k = self.model.voice(self.k_stop)
        self.assertEqual(voiced_k, self.g_stop)
        devoiced_g = self.model.devoice(self.g_stop)
        self.assertEqual(devoiced_g, self.k_stop)

    def test_palatalization_modifier(self):
        soft_t = self.model.palatalize(self.t_stop)
        self.assertTrue(soft_t & MOD_PALATALIZED)
        restored_t = self.model.depalatalize(soft_t)
        self.assertEqual(restored_t, self.t_stop)

    def test_pratyahara_bitmask(self):
        # 'i' has code 1 -> in 'ac' (0..8) and 'ik' (1..4)
        self.assertTrue(self.model.pratyahara_test(1, CANON_MASKS["ac"]))
        self.assertTrue(self.model.pratyahara_test(1, CANON_MASKS["ik"]))
        # 'k' has code 37 -> in 'hal' (9..41), not in 'ac'
        self.assertFalse(self.model.pratyahara_test(37, CANON_MASKS["ac"]))
        self.assertTrue(self.model.pratyahara_test(37, CANON_MASKS["hal"]))

if __name__ == "__main__":
    unittest.main()
