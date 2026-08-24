# Limb-base fixture — ISA-RATIONAL unblocking data

Extracted 2026-08-24 from `my-lisp @ bedece7` source (not from docs).

## Verified facts — crates/my-lisp/src/bignum.rs

| Fact | Value | Lines |
|---|---|---|
| Magnitude type | `Vec<u32>` | 39 |
| Limb base | **2^32** | 31–33 doc comment |
| Endianness | little-endian | 31 |
| Canonical zero | empty vec, no trailing zeros | 31–34, 42 |
| Multiplication | schoolbook O(n²), `u64` intermediates (32×32→64 fits) | 109–121 |
| GCD | present (`fn gcd`, Euclid via divmod) | 179, 411 |

## FPGA-side constraint (this repo)

TAG_FIXNUM payload = **28 bit** (docs/rational-bignum-representation.md).
Carry-headroom rule from that draft: usable base must be strictly smaller
than the payload so limb-wise ADD never overflows the field.

## Proposed decision (fixture-driven, replaces TBD)

**Base 2^24**, little-endian, one limb per TAG_FIXNUM cell.

Sizing vs my-lisp:
- 2^32 (Rust limb) ↔ ceil(32/24)=2 FPGA limbs (48 bit, top 16 unused-zero
  after normalization) — value-equivalent, NOT limb-identical; contract
  requires value equivalence only.
- Worst-case add: 24+24+carry ⇒ 25 bit ≤ 28 ✓ headroom 3 bit.
- Schoolbook mul on 2^24 limbs: product pair ⇒ ≤49 bit; fits existing
  28-bit cell pairs across two cells, or one DSP block on any FPGA with
  25×18 multipliers.

Conversion rule my-lisp↔RTL documented here so the future importer test
has an oracle: re-base 32→24 little-endian, drop leading zero limbs,
sign cell unchanged (canonical non-negative zero).

## Remaining blocker (unchanged)

my-lisp maintainer sign-off that value-equivalence (not limb-identity)
satisfies language-contract.my before any RTL lands.
