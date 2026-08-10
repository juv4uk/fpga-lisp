; M27: expose hardware ADD as a callable primitive through eval, the
; same way M16/M18 did for CAR/CDR/CONS/ATOM/EQ -- needed before any
; self-recursive core.my function (length-onto etc.) can be bootstrapped,
; since they all use `+`. (plus 3 4) => 7, both operands self-evaluating
; fixnum literals (no quote needed).

.include "fpga/asm/constants.inc"

LOADSYM R1, 400
LOADSYM R2, 401
EQ R6, R1, R2         ; R6 = NIL
LOADSYM R1, 402
LOADSYM R2, 403
EQ R11, R1, R2         ; R11 = NIL (stack)

LOADI R1, PRIM_ADD
MAKEPRIM R1, R1
LOADSYM R2, 300              ; 'plus
CONS R7, R2, R1                ; (plus . PRIM_ADD)
CONS R9, R7, R6                  ; outer_env = (pair_plus)

LOADSYM R1, 300                    ; 'plus
LOADI R2, 3
LOADI R3, 4
CONS R4, R3, R6                      ; (4)
CONS R4, R2, R4                        ; (3 4)
CONS R3, R1, R4                          ; expr = (plus 3 4)
MOV R4, R9                                 ; env = outer_env
CALL R5, eval

HALT                       ; R9 should hold FIXNUM 7

.include "fpga/asm/eval_core.inc"
