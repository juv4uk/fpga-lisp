; M25 bootstrap: third -- (def third (lambda (values) (car (cdr (cdr
; values))))) from my-lisp's lib/core.my. Same one-parameter chained-
; primitive shape as M20's second and M23's caar, one level deeper:
; cdr, then cdr again, then car. Applied to a quoted 4-element list
; (w x y z), expect 'y.
;
; Uses .include (constants.inc + eval_core.inc) instead of hand-copied
; eval/lookup and magic numbers -- see fpga/asm/*.inc.

.include "fpga/asm/constants.inc"

LOADSYM R1, 900
LOADSYM R2, 901
EQ R6, R1, R2         ; R6 = NIL
LOADSYM R1, 902
LOADSYM R2, 903
EQ R11, R1, R2         ; R11 = NIL (stack)

LOADI R1, PRIM_CAR
MAKEPRIM R1, R1
LOADI R2, PRIM_CDR
MAKEPRIM R2, R2

LOADSYM R3, 200               ; 'car
CONS R3, R3, R1                 ; (car . PRIM_CAR)
LOADSYM R4, 201                   ; 'cdr
CONS R4, R4, R2                     ; (cdr . PRIM_CDR)
CONS R4, R4, R6                       ; (pair_cdr)
CONS R7, R3, R4                         ; base_env = (pair_car pair_cdr)

LOADSYM R1, 904                           ; 'values (param name)
LOADSYM R2, 201                             ; 'cdr
CONS R3, R1, R6                               ; (values) = (values)
CONS R3, R2, R3                                 ; inner1 = (cdr values)
CONS R3, R3, R6                                   ; (inner1)
CONS R8, R2, R3                                     ; inner2 = (cdr inner1)
CONS R8, R8, R6                                       ; (inner2)
LOADSYM R2, 200                                         ; 'car
CONS R8, R2, R8                                           ; body = (car inner2)

CONS R4, R8, R7                                             ; rest = (body . base_env)
CONS R4, R1, R4                                               ; third_closure = (values . rest)

LOADSYM R2, 900                                                 ; 'third
CONS R2, R2, R4                                                   ; (third . closure)
CONS R9, R2, R6                                                     ; outer_env = (pair_third)

; --- build the argument: (quote (w x y z)) ---
LOADSYM R1, 910             ; 'w
LOADSYM R2, 911               ; 'x
LOADSYM R3, 912                 ; 'y
LOADSYM R4, 913                   ; 'z
CONS R10, R4, R6                    ; (z)
CONS R10, R3, R10                     ; (y z)
CONS R10, R2, R10                       ; (x y z)
CONS R10, R1, R10                         ; (w x y z)
LOADSYM R1, SYM_QUOTE
CONS R2, R10, R6                              ; ((w x y z))
CONS R10, R1, R2                                ; q_list = (quote (w x y z))

LOADSYM R1, 900                                   ; 'third
CONS R2, R10, R6                                    ; (q_list)
CONS R3, R1, R2                                       ; expr = (third (quote (w x y z)))
MOV R4, R9                                              ; env = outer_env
CALL R5, eval

HALT                       ; R9 should hold 'y

.include "fpga/asm/eval_core.inc"
