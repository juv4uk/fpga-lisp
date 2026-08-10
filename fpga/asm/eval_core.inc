; Shared eval/lookup subroutine body for fpga-lisp asm programs, via
; `.include`. Extracted verbatim (mechanically) from the version built
; up through M11-M22 (docs/lisp-machine-plan.md), currently the
; fullest one: atoms, quote, cond (with the CONS-based software call
; stack for self-recursion), all five hardware primitives dispatched
; as procedures, and closure application supporting either one
; parameter (a bare symbol) or exactly two (a 2-element list).
;
; Every caller must:
;   - `.include "constants.inc"` first (eval_core.inc uses SYM_QUOTE/
;     SYM_COND/PRIM_* rather than bare numbers).
;   - Initialize R11 to NIL before the first top-level `CALL R5, eval`
;     (it is the software call-stack pointer).
;   - Follow the register discipline documented in the plan: eval's
;     own frame is R3-R10; lookup's is R0-R2/R12-R15; nothing survives
;     a nested top-level eval() call except via push/pop on R11.
;
; This file defines the labels `eval`, `lookup`, and everything eval's
; own control flow jumps to (is_cons, try_apply, do_closure_apply,
; chk_*, done, next, etc.) -- callers must not reuse those names.

eval:
ATOM R6, R3
JF   R6, is_cons
GETTAG R6, R3
LOADI  R7, 2
EQ     R8, R6, R7
JF     R8, self_eval
MOV R12, R3
MOV R13, R4
CALL R14, lookup
MOV R9, R15
JMP done
self_eval:
MOV R9, R3
JMP done
is_cons:
CAR R6, R3
LOADSYM R7, SYM_QUOTE
EQ R8, R6, R7
JF R8, check_cond
CDR R10, R3
CAR R9, R10
JMP done
check_cond:
LOADSYM R7, SYM_COND
EQ R8, R6, R7
JF R8, try_apply
CDR R6, R3
cond_loop:
ATOM R8, R6
JF R8, has_clause
LOADSYM R6, 90
LOADSYM R7, 91
EQ R9, R6, R7
JMP done
has_clause:
CAR R10, R6
CAR R7, R10
CONS R11, R5, R11
CONS R11, R6, R11
CONS R11, R10, R11
MOV R3, R7
CALL R5, eval
CAR R10, R11
CDR R11, R11
CAR R6, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
JF R9, clause_false
CDR R8, R10
CAR R8, R8
CONS R11, R5, R11
MOV R3, R8
CALL R5, eval
CAR R5, R11
CDR R11, R11
JMP done
clause_false:
CDR R6, R6
JMP cond_loop
try_apply:
CDR R10, R3
CAR R7, R10
CDR R10, R10
ATOM R9, R10
JF R9, has_second_arg
MOV R8, R10
JMP arg2_done
has_second_arg:
CAR R8, R10
arg2_done:
CONS R11, R8, R11
CONS R11, R5, R11
CONS R11, R4, R11
CONS R11, R7, R11
MOV R3, R6
CALL R5, eval
CAR R7, R11
CDR R11, R11
CAR R4, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
MOV R6, R9

GETTAG R8, R6
LOADI R10, 5
EQ R8, R8, R10
JF R8, do_closure_apply

GETVAL R8, R6
LOADI R10, PRIM_CAR
EQ R9, R8, R10
JF R9, chk_cdr
CAR R10, R11
CDR R11, R11
CONS R11, R5, R11
MOV R3, R7
CALL R5, eval
CAR R5, R11
CDR R11, R11
CAR R9, R9
JMP done
chk_cdr:
LOADI R10, PRIM_CDR
EQ R9, R8, R10
JF R9, chk_atom
CAR R10, R11
CDR R11, R11
CONS R11, R5, R11
MOV R3, R7
CALL R5, eval
CAR R5, R11
CDR R11, R11
CDR R9, R9
JMP done
chk_atom:
LOADI R10, PRIM_ATOM
EQ R9, R8, R10
JF R9, chk_eq
CAR R10, R11
CDR R11, R11
CONS R11, R5, R11
MOV R3, R7
CALL R5, eval
CAR R5, R11
CDR R11, R11
ATOM R9, R9
JMP done
chk_eq:
LOADI R10, PRIM_EQ
EQ R9, R8, R10
JF R9, chk_cons
CAR R10, R11
CDR R11, R11
CONS R11, R5, R11
CONS R11, R10, R11
MOV R3, R7
CALL R5, eval
MOV R6, R9
CAR R10, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
CONS R11, R5, R11
CONS R11, R6, R11
MOV R3, R10
CALL R5, eval
CAR R6, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
EQ R9, R6, R9
JMP done
chk_cons:
LOADI R10, PRIM_CONS
EQ R9, R8, R10
JF R9, prim_fallback
CAR R10, R11
CDR R11, R11
CONS R11, R5, R11
CONS R11, R10, R11
MOV R3, R7
CALL R5, eval
MOV R6, R9
CAR R10, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
CONS R11, R5, R11
CONS R11, R6, R11
MOV R3, R10
CALL R5, eval
CAR R6, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
CONS R9, R6, R9
JMP done
prim_fallback:
CAR R10, R11
CDR R11, R11
LOADSYM R6, 92
LOADSYM R7, 93
EQ R9, R6, R7
JMP done
do_closure_apply:
CAR R10, R11
CDR R11, R11
CAR R9, R6
ATOM R8, R9
JF R8, closure_2arg
CONS R11, R5, R11
CONS R11, R4, R11
CONS R11, R6, R11
MOV R3, R7
CALL R5, eval
CAR R6, R11
CDR R11, R11
CAR R4, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
MOV R8, R9
CAR R7, R6
CDR R10, R6
CAR R6, R10
CDR R10, R10
CONS R9, R7, R8
CONS R4, R9, R10
CONS R11, R5, R11
MOV R3, R6
CALL R5, eval
CAR R5, R11
CDR R11, R11
JMP done
closure_2arg:
CONS R11, R10, R11
CONS R11, R5, R11
CONS R11, R4, R11
CONS R11, R6, R11
MOV R3, R7
CALL R5, eval
MOV R8, R9
CAR R6, R11
CDR R11, R11
CAR R4, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
CAR R10, R11
CDR R11, R11
CONS R11, R8, R11
CONS R11, R5, R11
CONS R11, R4, R11
CONS R11, R6, R11
MOV R3, R10
CALL R5, eval
MOV R7, R9
CAR R6, R11
CDR R11, R11
CAR R4, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
CAR R8, R11
CDR R11, R11
CAR R1, R6
CAR R2, R1
CDR R1, R1
CAR R12, R1
CDR R6, R6
CAR R13, R6
CDR R6, R6
CONS R1, R2, R8
CONS R1, R1, R6
CONS R2, R12, R7
CONS R4, R2, R1
CONS R11, R5, R11
MOV R3, R13
CALL R5, eval
CAR R5, R11
CDR R11, R11
JMP done
done:
RET R5

lookup:
CAR R0, R13
CAR R1, R0
EQ  R2, R1, R12
JF  R2, next
CDR R15, R0
RET R14
next:
CDR R13, R13
JMP lookup
