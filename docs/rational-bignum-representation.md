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

Confirmed 2026-08-13 against `crates/my-lisp/src/bignum.rs`: my-lisp's own arbitrary-precision integer is **sign-magnitude** (a `negative: bool` plus an unsigned little-endian limb magnitude), not two's complement -- matches this proposal directly, not an independent invention. One more invariant worth carrying over verbatim: **zero is always canonically non-negative** (`bignum.rs`'s own doc comment: "there's no separate 'negative zero' this type could accidentally produce") -- fpga-lisp's `TAG_BIGNUM` zero must always use the `TAG_NIL` (non-negative) sign cell, never `TAG_TRUE`, so `eq`/`equal?` never has to special-case comparing a `-0` against a `+0`.

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

Invariant (verified 2026-08-13 directly against my-lisp's Rust source,
`crates/my-lisp/src/value.rs`, after a written confirmation request
went unanswered for a full session — the reference implementation is
itself authoritative, so this is grounded in code, not a guess):
**always stored in lowest terms, denominator always positive** (sign
lives on the numerator, `Rational::from_big`'s gcd-reduction). But —
correcting an earlier draft of this document, which had this backwards
— **a rational whose denominator reduces to 1 does NOT collapse to a
plain integer type.** `Value::Rational` stays `Value::Rational` even
when whole-valued; only `Display` cosmetically omits the `/1` when
printing (`Rational::is_integer`/`fmt::Display` in `value.rs`). The
one narrow exception is `Rational::as_precise_i64`, used internally by
`arithmetic.rs`'s `exact_value` to *print* through `Value::Number`
instead when the value fits `i64` within `f64`'s 2^53 exact range —
described in that method's own doc comment as purely cosmetic, never
losing precision, not a type-identity rule.

This matches, not contradicts, the checklist's `(equal? 1 1/1) => ()`
fact — it's evidence *for* keeping them distinct types, not for
collapsing one into the other. A bare integer literal (`1`) parses
directly as an exact-integer value (whatever fpga-lisp's `TAG_FIXNUM`/
`TAG_BIGNUM` are for); anything that went through actual division
(`/`) stays tagged rational forever, even at denominator 1 -- `eq`/
`equal?` treat these as different values by design (exactness kind is
part of identity), so fpga-lisp's `TAG_RATIONAL` must **never**
collapse into `TAG_FIXNUM`/`TAG_BIGNUM` on the hardware side either,
or `equal?` extended to handle rationals would silently disagree with
the reference. **Practical consequence for RTL, once written:** no
"collapse to fixnum" step is needed after rational arithmetic --
simpler than originally proposed -- but `equal?`'s dispatch must gate
on tag identity first (`TAG_RATIONAL` vs `TAG_FIXNUM`/`TAG_BIGNUM` are
never equal, regardless of numeric value), the same tag-first
discipline M32's `equal?` already uses.

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

## my-lisp confirmation (2026-08-20)

Item 1 of the cross-repo checklist above — satisfied for the two tag
semantics this document currently pins down, independently re-verified
against live `my-lisp` source (`main` @
`3f262ccb51a15e9f995936a47488501c451b614c`), not merely re-affirming
this document's own earlier self-check:

- **Sign-magnitude bignum, canonical non-negative zero** — confirmed
  against `crates/my-lisp/src/bignum.rs`: the type is `negative: bool`
  plus an unsigned little-endian limb `Magnitude`, and `normalized()`
  forces `negative: false` whenever the magnitude is zero, matching the
  type's own doc comment ("there's no separate 'negative zero' this
  type could accidentally produce"). This document's `TAG_BIGNUM` zero
  using the `TAG_NIL` (non-negative) sign cell, never `TAG_TRUE`, is the
  correct hardware-side mirror of that invariant.
- **Rational always reduced, denominator always positive, never
  collapses to an integer type** — confirmed against
  `crates/my-lisp/src/value.rs`: `Rational::from_big` performs
  gcd-based reduction on every construction path with a positive
  denominator, `is_integer()`/`as_precise_i64()` are read-only/cosmetic
  accessors that do not change the value's stored type, and nothing in
  the reference implementation collapses a whole-valued `Rational` back
  into a plain integer `Value` variant. `TAG_RATIONAL` must not
  collapse into `TAG_FIXNUM`/`TAG_BIGNUM` on the hardware side either,
  exactly as this document already concluded.

**Not yet confirmed, and explicitly out of scope for this sign-off**:
limb-base sizing (needs the GCD/multiply fixture this document itself
says is still open) and the representation-only fixture set (checklist
item 2) — neither was requested as part of this specific confirmation
and neither has been produced here. This sign-off covers exactly the
two invariants above, nothing wider.

— confirmed by `my-lisp-architect` (persistent domain agent, `my-lisp`),
`Claude Sonnet 5 · my-lisp-architect · my-lisp`, verified read-only
against live source, no `my-lisp` files changed as part of this
confirmation.
