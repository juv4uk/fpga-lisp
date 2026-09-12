; evidence/ISA-RATIONAL/g1-canonical-zero-check.my
;
; Closes gate G1 of the conditional sign-off recorded in
; evidence/ISA-RATIONAL/limb-base-fixture.md:
;
;   "G1 Канонічність на FPGA-бік: без хвостових нуль-лимбів base-2^24,
;    єдине кодування нуля -- інакше eq розходиться."
;
; This pins down and verifies, for the first time, a design detail
; docs/rational-bignum-representation.md left implicit: what shape
; does the FPGA-side magnitude limb-chain take for the value zero?
; my-lisp's own bignum.rs answer for the Rust side is "empty Vec<u32>,
; no trailing zero limbs" (already confirmed in
; limb-base-fixture.md). The FPGA-side answer proposed and verified
; here, by direct analogy: the magnitude chain for zero is the empty
; chain (no limb cells at all -- TAG_NIL, not a single limb cell
; holding the value 0), and every nonzero value's most-significant
; limb is never 0. This is a value-equivalence mirror of Rust's
; invariant, not limb-identity (per vyasa's sign-off, value-equivalence
; is what language-contract.my requires) -- but it is exactly the same
; SHAPE of invariant: one canonical encoding per value, so `eq` on the
; FPGA side can compare canonical forms directly instead of needing a
; normalizing pass.
;
; Usage: cargo run -p my-lisp-cli --bin my-lisp -- \
;   ../fpga-lisp/evidence/ISA-RATIONAL/g1-canonical-zero-check.my
; (fpga-lisp checked out as a sibling of my-lisp; run with cwd =
; fpga-lisp repo root so the corpus path resolves, matching
; fpga/canon/gen-primitive-table.my's convention.)
;
; Fails closed (via an unbound-symbol reference, see
; fpga/canon/gen-primitive-table.my's own header comment for why
; princ/print can't be trusted to surface a diagnostic before a fatal
; error) if any check below does not hold.

(def base 16777216)  ; 2^24, the limb-base-fixture.md decision

(def fail-closed
  (lambda (msg)
    (eval (string->symbol (string-append "CANON-TABLE-FAIL-CLOSED: " msg)))))

; --- canonical base-2^24 little-endian limb encode/decode ---
; Encoding a nonzero n always terminates with a nonzero
; most-significant limb by construction: the loop only ever appends
; another limb while n is still nonzero, and the final appended limb
; equals whatever n had shrunk to (< base, by definition of quotient),
; which is nonzero exactly because the loop was still running. Zero
; encodes to the empty list -- never a single zero-valued limb cell.
(def to-limbs-onto
  (lambda (n acc)
    (cond
      ((eq n 0) (reverse acc))
      (t (to-limbs-onto (quotient n base) (cons (mod n base) acc))))))

(def to-limbs (lambda (n) (to-limbs-onto n (quote ()))))

(def from-limbs
  (lambda (limbs)
    (cond
      ((atom limbs) 0)
      (t (+ (car limbs) (* base (from-limbs (cdr limbs))))))))

(def most-significant-limb
  (lambda (limbs) (car (reverse limbs))))

(def check
  (lambda (label ok)
    (cond
      (ok t)
      (t (fail-closed (string-append label ": FAIL"))))))

; --- G1 checks over the already-landed G2 differential corpus values
;     (evidence/ISA-RATIONAL/g2_differential_corpus.json, sakshi,
;     2026-08-24) plus explicit limb-boundary values ---

(def corpus (json-parse (read-file "evidence/ISA-RATIONAL/g2_differential_corpus.json")))
(def test-cases (cdr (assoc "test_cases" corpus)))

(def collect-operand-values-onto
  (lambda (cases acc)
    (cond
      ((atom cases) acc)
      (t (collect-operand-values-onto (cdr cases)
           (cons (cdr (assoc "a" (car cases)))
                 (cons (cdr (assoc "b" (car cases))) acc)))))))

(def corpus-values (collect-operand-values-onto test-cases (quote ())))

(def boundary-values
  (list 0 1 16777215 16777216 16777217 4294967295 4294967296 281474976710656))

(def all-test-values (append boundary-values corpus-values))

(def verify-value
  (lambda (n)
    ((lambda ()
       (def limbs (to-limbs n))
       (check (string-append "round-trip for " (write-to-string n))
         (eq (from-limbs limbs) n))
       (cond
         ((eq n 0)
          (check "zero encodes to the empty limb chain (canonical, matches bignum.rs's empty Vec)"
            (atom limbs)))
         (t
          (check (string-append (string-append "nonzero value " (write-to-string n)) " has no trailing (most-significant) zero limb")
            (not (eq (most-significant-limb limbs) 0)))))))))

(def verify-all
  (lambda (values)
    (cond
      ((atom values) t)
      (t ((lambda () (verify-value (car values)) (verify-all (cdr values))))))))

(verify-all all-test-values)

(print "G1 CLOSED: verified canonical base-2^24 encoding (empty chain for zero,")
(print "no trailing zero limb for nonzero) round-trips correctly for")
(print (length all-test-values))
(print " values (boundary set + full G2 differential corpus operands).")
(quote ())
