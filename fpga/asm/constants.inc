; Shared named constants for fpga-lisp asm programs, via `.include`.
; Centralizes the two numbers eval_core.inc's dispatch logic hardcodes
; (quote/cond) so no other file can accidentally reuse those exact
; symbol ids for something else -- the actual bug class this file
; exists to prevent (see docs/lisp-machine-plan.md's M19/M22 notes on
; symbol-list ordering mistakes; this addresses the sibling risk of
; symbol-id collisions instead).
;
; Only the two ids eval_core.inc's own dispatch depends on are defined
; here. Test-specific symbols (env keys, test data like 'a/'b/'x/'y)
; still belong in each .asm file -- they don't need central coordination,
; only uniqueness within that one file.

.define SYM_QUOTE 50
.define SYM_COND  80

; Hardware primitive ids (see lisp_data_unit.sv / control.sv's
; try_apply primitive dispatch) -- pair with MAKEPRIM to build a
; PRIMITIVE-tagged value: `LOADI R1, PRIM_CAR` / `MAKEPRIM R1, R1`.
.define PRIM_CAR  0
.define PRIM_CDR  1
.define PRIM_CONS 2
.define PRIM_ATOM 3
.define PRIM_EQ   4
.define PRIM_ADD  5
