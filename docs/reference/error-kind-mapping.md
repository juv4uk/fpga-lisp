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
| `division-by-zero`     | `DivisionByZero`      | exact arithmetic received a zero divisor |
| `parse-error`          | `Parse`               | reader or decoder rejected malformed input |
| `unknown-symbol`       | `UnknownSymbol`       | unbound symbol |

Upstream unification tracked in my-lisp; if oracle vocabulary changes,
refresh this table and re-run adversarial fixtures.

The canonical fixture copy is an upstream reference and gap-accounting input.
Its contract 3.0 pin does not claim that fpga-lisp hardware implements every
3.0 error category; backend support must be stated and evidenced separately.
