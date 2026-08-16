; Data only, per evidence/README.md's schema (my-lisp, f96936d). Read via
; (read-file ...), never (load ...).

(evidence
  (fixture . "(cond (0 (quote zero-is-truthy)) (t (quote wrong)))")
  (requirement . G8)
  (implementation . fpga-lisp)
  (commit . "3673875")
  (runner . iverilog)
  (expected . "zero-is-truthy")
  (actual . "zero-is-truthy")
  (result . pass)
  (timestamp . "2026-08-11")
  (note . "RTL fpga/rtl/control.sv OP_JF branch condition narrowed from (tag==TAG_NIL || (tag==TAG_FIXNUM && value==0)) to (tag==TAG_NIL) only, ISA 0.2 -> 1.0. Testbench fpga/sim/tb_jf_truthiness.sv, runner Icarus Verilog 12.0 (devel), simulated-time-units 3992970. Verified by local run since this commit's own CI run was Cancelled and never re-run."))
