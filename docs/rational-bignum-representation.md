# Rational/Bignum representation — DRAFT PROPOSAL, not a contract yet

Status: draft, unreviewed. Not wired into `isa-contract.my`, not
implemented in RTL. Written to satisfy the rule this repo already
follows for every other capability: agree the representation and get
cross-repo sign-off *before* writing hardware, not after. Plan item 25
(`docs/lisp-machine-plan.md`) is next after item 24 (recursion, closed by
`lisp-machine-v0.04`).

## Why boxed, not inline

The current 32-bit word (4-bit tag + 28-bit payload) physically cannot
hold an arbitrary-precision integer or an exact rational inline —
`my-lisp`'s language contract fixes "bare integer literals are exact at
arbitrary precision" as semantics, not an implementation detail of the
Rust reference. `docs/lisp-machine-plan.md`'s "Числа" section already
calls this: bignum as a limb array, rational as numerator/denominator —
both **heap structures**, not a wider ALU.

## Tags

Two tag slots remain unused (6 of 16 occupied: `FIXNUM=0 CONS=1 SYMBOL=2
NIL=3 TRUE=4 PRIMITIVE=5`):

```
TAG_BIGNUM   = 6
TAG_RATIONAL = 7
```

Both tags' 28-bit payload is a heap address, exactly like `TAG_CONS` —
no new addressing mode needed, `car_ram`/`cdr_ram` access already exists.

## Bignum: limb chain

Payload points to the head of a `CONS`-shaped chain, reusing the existing
heap cell layout instead of inventing a new one:

```
car: sign     -- TAG_TRUE (negative) or TAG_NIL (non-negative), reusing
                 the existing truth tags rather than a new one
cdr: TAG_CONS -> (car: TAG_FIXNUM limb_0, cdr: next_cell | TAG_NIL)
```

Each limb is a `TAG_FIXNUM` payload, i.e. 28 bits — but `ADD`'s hardware
carry logic works on the full 28-bit field, so the *usable* limb base
should be smaller (e.g. base 2^24) to leave headroom for a carry bit
during limb-wise addition without a wider adder. Exact base TBD; needs a
fixture-driven decision (see Open questions), not a guess baked into RTL
first.

Little-endian limb order (least-significant limb first) — matches every
other little-endian convention already in this ISA (word byte order,
boot-length byte order).

## Rational: numerator/denominator pair

Payload points to a single `CONS` cell:

```
car: numerator   -- TAG_FIXNUM or TAG_BIGNUM
cdr: denominator -- TAG_FIXNUM or TAG_BIGNUM, always > 0
```

Invariant (must match `my-lisp`'s exactness model exactly, not be
invented independently): always stored in lowest terms, denominator
always positive (sign lives on the numerator). A rational whose
denominator reduces to 1 is **not** a valid `TAG_RATIONAL` — it must
collapse to a plain `TAG_FIXNUM`/`TAG_BIGNUM`. This makes `equal?`
correct for free (M32's structural comparison doesn't need a special
case) and matches the checklist's already-confirmed rule that exactness
kind is part of value identity (`(equal? 1 1/1) => ()` per
`docs/equal-oracle-checklist.my`).

## What this does NOT decide yet

- Limb base (16-bit? 24-bit? machine word minus carry headroom?) —
  needs a real GCD/multiply fixture from `my-lisp` to size against, not
  a guess.
- GCD algorithm for rational normalization (binary GCD is simplest in
  hardware — no division — but that's an RTL concern, not this
  contract's).
- Whether bignum arithmetic primitives (`ADD`/`SUB`/multiply) get new
  opcodes or reuse `eval`-level dispatch the way `PRIM_ADD` (M27) already
  does for fixnum — the same "extend an existing opcode via an unused
  field" discipline this ISA has followed since `LOADSYM` filled the
  16/16 opcode space applies here too; no slot is spent lightly.
- Interaction with `equal?` (M32) beyond the normalization invariant
  above — needs its own fixture pass once bignum/rational actually
  exist, not before.

## Before any RTL: cross-repo checklist

1. my-lisp confirms the tag semantics above match `language-contract.my`
   exactly (exactness, normalization, sign placement) — this document is
   fpga-lisp's proposal, not a unilateral decision.
2. A representation-only fixture set (my-lisp oracle: printed/read forms
   of a handful of bignums and rationals at the chosen limb base) lands
   in `tests/fixtures/` or `evidence/` before a single opcode is touched.
3. Only then: RTL for the two new tags, then `ADD`/`SUB`/multiply
   primitives, then `cml` lowering.

Skipping straight to RTL here would repeat the exact mistake this
repo's own conventions exist to prevent (see `AGENTS.md`: "no opcode is
added lightly").
