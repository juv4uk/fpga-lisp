; Shared eval/lookup subroutine body for fpga-lisp asm programs, via
; `.include`. Built up through M11-M24 (docs/lisp-machine-plan.md):
; atoms, quote, cond (with the CONS-based software call stack for
; self-recursion), all five hardware primitives dispatched as
; procedures, and closure application supporting either one parameter
; (a bare symbol, unchanged since M11) or an arbitrary-length parameter
; list (M22 generalized from a hardcoded two-parameter case to a real
; binding loop in M24 -- try_apply no longer eagerly extracts up to
; two argument expressions before knowing the operator; it preserves
; the whole unevaluated argument list across the operator's own eval
; call instead, and only primitives -- capped at two operands in
; hardware -- split off arg1/arg2 from it afterward).
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
; Preserve the whole unevaluated argument list (not just the first
; two) across the operator's own eval call. Primitives split off
; arg1/arg2 from it afterward (hardware ops cap at two operands);
; closures walk the whole thing in a binding loop (do_closure_apply).
CDR R1, R3           ; args = cdr(expr), the full unevaluated list
CONS R11, R5, R11
CONS R11, R4, R11
CONS R11, R1, R11
MOV R3, R6
CALL R5, eval
CAR R1, R11
CDR R11, R11
CAR R4, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
MOV R6, R9              ; R6 = operator's value

GETTAG R8, R6
LOADI R10, 5
EQ R8, R8, R10
JF R8, do_closure_apply

; --- primitive: split arg1_expr/arg2_expr off the preserved args list ---
GETVAL R2, R6            ; primitive id (R2: free, lookup isn't running)
CAR R7, R1
CDR R10, R1
ATOM R9, R10
JF R9, has_second_arg
MOV R8, R10
JMP arg2_done
has_second_arg:
CAR R8, R10
arg2_done:
LOADI R10, PRIM_CAR
EQ R9, R2, R10
JF R9, chk_cdr
CONS R11, R5, R11
MOV R3, R7
CALL R5, eval
CAR R5, R11
CDR R11, R11
CAR R9, R9
JMP done
chk_cdr:
LOADI R10, PRIM_CDR
EQ R9, R2, R10
JF R9, chk_atom
CONS R11, R5, R11
MOV R3, R7
CALL R5, eval
CAR R5, R11
CDR R11, R11
CDR R9, R9
JMP done
chk_atom:
LOADI R10, PRIM_ATOM
EQ R9, R2, R10
JF R9, chk_eq
CONS R11, R5, R11
MOV R3, R7
CALL R5, eval
CAR R5, R11
CDR R11, R11
ATOM R9, R9
JMP done
chk_eq:
; Two-operand primitive: arg2_expr already sits in R8 (split off by
; the shared prologue above) rather than needing a stack pop here --
; a stale pop of a since-removed eager push was an earlier bug in this
; exact spot (see docs/lisp-machine-plan.md's M24 notes).
LOADI R10, PRIM_EQ
EQ R9, R2, R10
JF R9, chk_cons
CONS R11, R5, R11
CONS R11, R8, R11
MOV R3, R7
CALL R5, eval
MOV R6, R9
CAR R8, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
CONS R11, R5, R11
CONS R11, R6, R11
MOV R3, R8
CALL R5, eval
CAR R6, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
EQ R9, R6, R9
JMP done
chk_cons:
LOADI R10, PRIM_CONS
EQ R9, R2, R10
JF R9, prim_fallback
CONS R11, R5, R11
CONS R11, R8, R11
MOV R3, R7
CALL R5, eval
MOV R6, R9
CAR R8, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
CONS R11, R5, R11
CONS R11, R6, R11
MOV R3, R8
CALL R5, eval
CAR R6, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
CONS R9, R6, R9
JMP done
prim_fallback:
LOADSYM R6, 92
LOADSYM R7, 93
EQ R9, R6, R7
JMP done
do_closure_apply:
; R6 = closure, R1 = args (full unevaluated list), R4 = calling env.
CAR R9, R6             ; params = car(closure)
ATOM R8, R9
JF R8, closure_nary
; --- single bare-symbol parameter (unchanged since M11) ---
CAR R7, R1               ; arg1_expr = car(args); only the first arg is used
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
closure_nary:
; params (R9) is a proper list of N parameter symbols. Walk params and
; args together, binding each pair by extending an accumulator
; environment, then eval the body in that environment. Every value
; that must survive an argument's eval call (the parameter itself,
; the remaining params/args, the growing env, the body, the calling
; env, our own return address) is pushed before that call and popped
; after -- the same discipline as every other recursive site in this
; file, just with more state in flight at once.
CDR R10, R6              ; rest = cdr(closure) = (body . captured_env)
CAR R2, R10                ; body
CDR R10, R10                 ; accum_env, grows with each binding
MOV R7, R9                     ; params cursor
nary_loop:
ATOM R8, R7
JF R8, nary_bind
JMP nary_done
nary_bind:
CAR R0, R7                ; current param symbol
CAR R9, R1                  ; current (unevaluated) arg expression
CDR R7, R7                    ; advance params cursor
CDR R1, R1                      ; advance args cursor
CONS R11, R0, R11                 ; push param
CONS R11, R7, R11                   ; push remaining params
CONS R11, R1, R11                     ; push remaining args
CONS R11, R10, R11                      ; push accum_env
CONS R11, R2, R11                         ; push body
CONS R11, R5, R11                           ; push retaddr
CONS R11, R4, R11                             ; push calling env
MOV R3, R9
CALL R5, eval
CAR R4, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
CAR R2, R11
CDR R11, R11
CAR R10, R11
CDR R11, R11
CAR R1, R11
CDR R11, R11
CAR R7, R11
CDR R11, R11
CAR R0, R11
CDR R11, R11
CONS R6, R0, R9              ; pair = (param . arg value)  [closure done with]
CONS R10, R6, R10               ; accum_env = (pair . accum_env)
JMP nary_loop
nary_done:
MOV R4, R10
CONS R11, R5, R11
MOV R3, R2
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
