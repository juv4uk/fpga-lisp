# Wire error-kind ↔ contract vocabulary mapping

Resolves finding F2 of docs/conformance-adversarial-report-2026-08-23.md
(fpga-lisp side). The semantic oracle (:9999, owned by my-lisp) reports
kebab-case kinds on the wire; contract fixtures use Rust Debug names.
Third-party implementations must map through this table.

| Wire kind (oracle)     | Contract fixture name | Meaning |
|------------------------|-----------------------|---------|
| `arity-error`          | `Arity`               | wrong argument count |
| `type-error`           | `Type`                | operand type mismatch |
| `invalid-form`         | `InvalidForm`         | malformed expression structure |
| `numeric-overflow`     | `NumericOverflow`     | bignum/rational range |
| `unknown-symbol`       | `UnknownSymbol`       | unbound symbol |

Upstream unification tracked in my-lisp; if oracle vocabulary changes,
refresh this table and re-run adversarial fixtures.
