; Data only, per evidence/README.md's schema (my-lisp, f96936d). Read via
; (read-file ...), never (load ...).

(evidence
  (fixture . "(eq 3 3.0) / (print 3.0) / (+ 2.0 1.0) — full 193-fixture sweep, see note")
  (requirement . S1)
  (implementation . fpga-lisp)
  (commit . "0d6643e")
  (runner . "my-lisp TCP oracle :9999 (independent witness; not the Rust test harness)")
  (expected . "canonical contract values")
  (actual . "see docs/conformance-adversarial-report-2026-08-23.md")
  (result . pass)
  (timestamp . "2026-08-23")
  (note . "Adversarial verification FPGA-CONFORMANCE-TESTING by ganaka-1. Canonical fixture set: Rust implementation matches contract 193/193 semantically (5 Arity wire-naming normalizations; 2 bare-builtin oracle-path quirks flagged to my-lisp domain, not contract violations). KEY FINDING: fpga-lisp's own docs/reference/conformance.my copy is stale pre-item-10 semantics — expects ()/3.0/0.75 where canonical+impl give t/3/3/4 for eq-of-exact-vs-decimal, print of whole inexact, mixed addition; 5 real mismatches + ~75 missing later fixtures. Copy must be refreshed before hardware-side semantic reliance. Keyed S1 because exactness-by-default is the drifted axis."))
