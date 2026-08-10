; M26 bootstrap: SETCDR (ATOM with rs2 != 0) -- an internal, bootstrap-
; only cell-mutation capability. Build (a . b), overwrite its cdr to
; 'z in place, then read both fields back through ordinary CAR/CDR to
; prove the heap itself changed (not just a register). See
; fpga/rtl/lisp_data_unit.sv's cmd_setcdr for the hardware rationale.

LOADSYM R1, 1        ; 'a
LOADSYM R2, 2        ; 'b
CONS R6, R1, R2      ; R6 = (a . b)
LOADSYM R3, 3        ; 'z
SETCDR R7, R6, R3    ; mutate R6's cdr to 'z in place; R7 = confirmation (unused)
CDR R9, R6           ; read back cdr from the heap -> must be 'z, not 'b
CAR R8, R6           ; read back car from the heap -> must still be 'a
HALT
