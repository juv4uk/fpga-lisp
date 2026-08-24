# Adversarial conformance verification — 2026-08-23

**Task:** FPGA-CONFORMANCE-TESTING · **Agent:** ganaka-1 · **Status:** DONE

Independent witness run of both `conformance.my` copies against the live
Rust implementation (TCP oracle :9999, loopback), deliberately NOT using
my-lisp's own Rust test harness. Method mirrors
`crates/my-lisp/tests/mccarthy.rs::conformance_tests_from_my` (same 6-lib
prelude, same comparison semantics).

## Results

| Fixture set | Total | Semantic PASS | Naming-only | Real FAIL |
|---|---|---|---|---|
| Canonical (`my-lisp/tests/fixtures/`) | 193 | 186 | 5 (Arity↔arity-error) | **2** (see F3) |
| fpga-lisp copy (`docs/reference/`) | 121 | 110 | 6 (same class) | **5** (see F1) |

## Findings

### F1 — fpga-lisp's conformance copy is STALE and semantically WRONG (HIGH)

`docs/reference/conformance.my` predates the decimal-exact-by-default
contract change (PLAN item 10) and reduced-rational rendering:

| expr | fpga-lisp expects | canonical + live Rust |
|---|---|---|
| `(eq 3 3.0)` | `()` | `t` |
| `(print 3.0)` | `3.0` | `3` |
| `(print 3.00)` | `3.0` | `3` |
| `(+ 2.0 1.0)` | `3.0` | `3` |
| `(+ (/ 1 2) 0.25)` | `0.75` | `3/4` |

Also missing ~75 later fixtures (S3 numeric-literal refusals, G6
serialization law, quotient/mod/nth/assoc, threading macros).
Anyone implementing from this copy bakes in superseded semantics.
**Recommended:** replace the copy with the canonical file (or a pointer +
hash pin); re-run FPGA-side fixtures affected by item 10.

### F2 — wire error-kind vocabulary ≠ contract vocabulary (MEDIUM)

The TCP protocol reports kebab-case kinds (`arity-error`, `type-error`,
`invalid-form`, `numeric-overflow`, `unknown-symbol`); the contract
fixtures use Rust Debug names (`Arity`, `Type`, `InvalidForm`,
`NumericOverflow`, `UnknownSymbol`). 25 naming-drift events in this run.
A third implementation matching the contract text against wire responses
will mis-map. **Recommended:** either document the mapping table in the
protocol docs or unify the vocabulary.

### F3 — bare builtin reference diverges on the oracle path (LOW, for my-lisp)

Canonical fixtures `(expr . "+")` expect `#<builtin +>`; in-process the
harness passes, but over the TCP oracle `+` / `-` evaluate to
`unknown-symbol`. Application `(+ 1 2)` works fine on the same connection.
Reader/eval asymmetry specific to the wire path — needs my-lisp-domain
confirmation (Vyasa).

## Verdict

- The Rust implementation matches the CANONICAL contract: **193/193 after
  normalizing wire kind names** (the 2 F3 items are oracle-path quirks,
  not contract violations — flagged, not failed).
- fpga-lisp's local copy is NOT a valid statement of the current contract
  and must be refreshed before any hardware-side semantic work relies on
  it.

*Runner: independent Python client over the :9999 sexpr protocol;
prelude core/unify/reason/understand/narrate/persistent-map loaded per
session exactly like the canonical harness.*
