; M23 bootstrap: caar -- (def caar (lambda (values) (car (car
; values)))) from my-lisp's lib/core.my. Same composition shape as
; M20's second (two chained primitive calls), but both calls are car
; instead of car-of-cdr, so it only needs 'car bound in its captured
; env. Applied to a quoted nested list ((x y) z), expect 'x.
;
; Rewritten to use .include (constants.inc + eval_core.inc) instead of
; hand-copied eval/lookup and magic numbers -- see fpga/asm/*.inc.

.include "fpga/asm/constants.inc"

LOADSYM R1, 1100
LOADSYM R2, 1101
EQ R6, R1, R2         ; R6 = NIL
LOADSYM R1, 1102
LOADSYM R2, 1103
EQ R11, R1, R2         ; R11 = NIL (stack)

LOADI R1, PRIM_CAR
MAKEPRIM R1, R1          ; PRIM_CAR = car
LOADSYM R2, 200             ; 'car
CONS R7, R2, R1               ; (car . PRIM0)
CONS R7, R7, R6                 ; base_env = (pair_car)

LOADSYM R1, 1110                  ; 'values (param name)
CONS R3, R1, R6                     ; (values)
CONS R3, R2, R3                       ; inner = (car values)
CONS R3, R3, R6                         ; (inner)
CONS R8, R2, R3                           ; body = (car inner)

CONS R4, R8, R7                             ; rest = (body . base_env)
CONS R4, R1, R4                               ; caar_closure = (values . rest)

LOADSYM R2, 1120                                ; 'caar
CONS R2, R2, R4                                   ; (caar . closure)
CONS R9, R2, R6                                     ; outer_env = (pair_caar)

; --- build (quote ((x y) z)) ---
LOADSYM R1, 1130             ; 'x
LOADSYM R2, 1131               ; 'y
LOADSYM R3, 1132                 ; 'z
CONS R10, R2, R6                   ; (y)
CONS R10, R1, R10                    ; (x y)
CONS R2, R3, R6                        ; (z)
CONS R10, R10, R2                        ; ((x y) z)
LOADSYM R1, SYM_QUOTE                      ; 'quote
CONS R2, R10, R6                             ; (((x y) z))
CONS R10, R1, R2                               ; q_list = (quote ((x y) z))

LOADSYM R1, 1120                                 ; 'caar
CONS R2, R10, R6                                   ; (q_list)
CONS R3, R1, R2                                      ; expr = (caar q_list)
MOV R4, R9                                             ; env = outer_env
CALL R5, eval

HALT                       ; R9 should hold 'x

.include "fpga/asm/eval_core.inc"
