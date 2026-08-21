"""PVC-16: 16-Bit Phonetic Vector Code for FPGA Lisp & Hardware Co-Design."""

from dataclasses import dataclass
from typing import Optional

# Sthana (Place of Articulation) Bits [5:1]
STHANA_NONE      = 0 << 1
STHANA_KANTHYA   = 1 << 1  # Velar / Guttural (a, k, kh, g, gh, nG, h)
STHANA_TALAVYA   = 2 << 1  # Palatal (i, c, ch, j, jh, nY, y, S)
STHANA_MURDHANYA = 3 << 1  # Retroflex (R, T, Th, D, Dh, N, r, z)
STHANA_DANTYA    = 4 << 1  # Dental (L, t, th, d, dh, n, l, s)
STHANA_OSHTHYA   = 5 << 1  # Labial (u, p, ph, b, bh, m, v)

# Prayatna (Manner of Articulation) Bits [9:6]
PRAYATNA_SPRSTA     = 1 << 6  # Stop (k, c, T, t, p...)
PRAYATNA_MAHAPRANA  = 1 << 7  # Aspirate (kh, gh, ch, jh...)
PRAYATNA_GHOSHA     = 1 << 8  # Voiced (g, gh, j, jh, d, dh, b, bh, nasals, semivowels, vowels)
PRAYATNA_ANUNASIKA  = 1 << 9  # Nasal (nG, nY, N, n, m)

# Vowel Flag Bit [0]
FLAG_VOWEL          = 1 << 0  # 1 = Vowel (ac), 0 = Consonant (hal)

# Length / Svara Bits [13:10]
LEN_HRASVA          = 1 << 10
LEN_DIRGHA          = 2 << 10
LEN_PLUTA           = 3 << 10

# Modifiers Bits [15:14]
MOD_PALATALIZED     = 1 << 14 # Ukrainian [ь] / Palatalized consonant
MOD_DIPHTHONG       = 1 << 15

@dataclass(frozen=True)
class PhonemeVector:
    symbol: str
    code: int

    @property
    def is_vowel(self) -> bool:
        return bool(self.code & FLAG_VOWEL)

    @property
    def is_consonant(self) -> bool:
        return not self.is_vowel

    @property
    def is_voiced(self) -> bool:
        return bool(self.code & PRAYATNA_GHOSHA)

    @property
    def is_aspirate(self) -> bool:
        return bool(self.code & PRAYATNA_MAHAPRANA)

    @property
    def is_palatalized(self) -> bool:
        return bool(self.code & MOD_PALATALIZED)

    @property
    def sthana_mask(self) -> int:
        return self.code & (0x1F << 1)

    def is_savarna_with(self, other: "PhonemeVector") -> bool:
        """Sutra 1.1.9: tulyasyaprayatnam savarnam."""
        same_sthana = (self.sthana_mask == other.sthana_mask) and (self.sthana_mask != 0)
        same_prayatna = (bool(self.code & PRAYATNA_SPRSTA) == bool(other.code & PRAYATNA_SPRSTA)) and \
                         (self.is_vowel == other.is_vowel)
        return same_sthana and same_prayatna

    def with_voicing(self, voiced: bool = True) -> "PhonemeVector":
        new_code = (self.code | PRAYATNA_GHOSHA) if voiced else (self.code & ~PRAYATNA_GHOSHA)
        return PhonemeVector(self.symbol, new_code)

    def with_palatalization(self, palatalized: bool = True) -> "PhonemeVector":
        new_code = (self.code | MOD_PALATALIZED) if palatalized else (self.code & ~MOD_PALATALIZED)
        return PhonemeVector(self.symbol, new_code)

# Standard Canonical Phoneme Registry in PVC-16
REGISTRY = {
    # Vowels
    "a":  PhonemeVector("a",  FLAG_VOWEL | STHANA_KANTHYA   | PRAYATNA_GHOSHA | LEN_HRASVA),
    "A":  PhonemeVector("A",  FLAG_VOWEL | STHANA_KANTHYA   | PRAYATNA_GHOSHA | LEN_DIRGHA),
    "i":  PhonemeVector("i",  FLAG_VOWEL | STHANA_TALAVYA   | PRAYATNA_GHOSHA | LEN_HRASVA),
    "I":  PhonemeVector("I",  FLAG_VOWEL | STHANA_TALAVYA   | PRAYATNA_GHOSHA | LEN_DIRGHA),
    "u":  PhonemeVector("u",  FLAG_VOWEL | STHANA_OSHTHYA   | PRAYATNA_GHOSHA | LEN_HRASVA),
    "U":  PhonemeVector("U",  FLAG_VOWEL | STHANA_OSHTHYA   | PRAYATNA_GHOSHA | LEN_DIRGHA),
    "f":  PhonemeVector("f",  FLAG_VOWEL | STHANA_MURDHANYA | PRAYATNA_GHOSHA | LEN_HRASVA), # ṛ
    "x":  PhonemeVector("x",  FLAG_VOWEL | STHANA_DANTYA    | PRAYATNA_GHOSHA | LEN_HRASVA), # ḷ

    # Velars (Kavarga)
    "k":  PhonemeVector("k",  STHANA_KANTHYA | PRAYATNA_SPRSTA),
    "K":  PhonemeVector("K",  STHANA_KANTHYA | PRAYATNA_SPRSTA | PRAYATNA_MAHAPRANA),
    "g":  PhonemeVector("g",  STHANA_KANTHYA | PRAYATNA_SPRSTA | PRAYATNA_GHOSHA),
    "G":  PhonemeVector("G",  STHANA_KANTHYA | PRAYATNA_SPRSTA | PRAYATNA_MAHAPRANA | PRAYATNA_GHOSHA),
    "N":  PhonemeVector("N",  STHANA_KANTHYA | PRAYATNA_SPRSTA | PRAYATNA_GHOSHA | PRAYATNA_ANUNASIKA),

    # Dentals (Tavarga)
    "t":  PhonemeVector("t",  STHANA_DANTYA  | PRAYATNA_SPRSTA),
    "T":  PhonemeVector("T",  STHANA_DANTYA  | PRAYATNA_SPRSTA | PRAYATNA_MAHAPRANA),
    "d":  PhonemeVector("d",  STHANA_DANTYA  | PRAYATNA_SPRSTA | PRAYATNA_GHOSHA),
    "D":  PhonemeVector("D",  STHANA_DANTYA  | PRAYATNA_SPRSTA | PRAYATNA_MAHAPRANA | PRAYATNA_GHOSHA),
    "n":  PhonemeVector("n",  STHANA_DANTYA  | PRAYATNA_SPRSTA | PRAYATNA_GHOSHA | PRAYATNA_ANUNASIKA),

    # Ukrainian Extensions
    "т'": PhonemeVector("т'", STHANA_DANTYA  | PRAYATNA_SPRSTA | MOD_PALATALIZED),
    "д'": PhonemeVector("д'", STHANA_DANTYA  | PRAYATNA_SPRSTA | PRAYATNA_GHOSHA | MOD_PALATALIZED),
}

def get_phoneme(sym: str) -> Optional[PhonemeVector]:
    return REGISTRY.get(sym)
