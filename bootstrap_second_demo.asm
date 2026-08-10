; M20 bootstrap: second -- the second function ported from my-lisp's
; lib/core.my: (def second (lambda (values) (car (cdr values)))).
; A different composition shape than M19's null?: the closure body
; chains TWO primitive calls (car of cdr), rather than calling one
; primitive directly on the parameter. Applied to a quoted 3-element
; list (x y z), expect 'y.
;
; Uses .include (constants.inc + eval_core.inc) instead of hand-copied
; eval/lookup and magic numbers -- see fpga/asm/*.inc.

.include "fpga/asm/constants.inc"

LOADSYM R1, 700
LOADSYM R2, 701
EQ R6, R1, R2         ; R6 = NIL
LOADSYM R1, 702
LOADSYM R2, 703
EQ R11, R1, R2         ; R11 = NIL (stack)

LOADI R1, PRIM_CAR
MAKEPRIM R1, R1
LOADI R2, PRIM_CDR
MAKEPRIM R2, R2

LOADSYM R3, 200               ; 'car
CONS R3, R3, R1                 ; (car . PRIM0)
LOADSYM R4, 201                   ; 'cdr
CONS R4, R4, R2                     ; (cdr . PRIM1)
CONS R4, R4, R6                       ; (pair_cdr)
CONS R7, R3, R4                         ; base_env = (pair_car pair_cdr)

LOADSYM R1, 604                           ; 'values (param name)
LOADSYM R2, 201                             ; 'cdr
CONS R3, R1, R6                               ; (values . NIL) = (values)
CONS R3, R2, R3                                 ; inner = (cdr values)
CONS R3, R3, R6                                   ; (inner)
LOADSYM R2, 200                                     ; 'car
CONS R8, R2, R3                                       ; body = (car inner)

CONS R4, R8, R7                                         ; rest = (body . base_env)
CONS R4, R1, R4                                           ; second_closure = (values . rest)

LOADSYM R2, 600                                             ; 'second
CONS R2, R2, R4                                               ; (second . closure)
CONS R9, R2, R6                                                 ; outer_env = (pair_second)

; --- build the argument: (quote (x y z)) ---
LOADSYM R1, 601             ; 'x
LOADSYM R2, 602               ; 'y
LOADSYM R3, 603                 ; 'z
CONS R10, R3, R6                  ; (z)
CONS R10, R2, R10                   ; (y z)
CONS R10, R1, R10                     ; (x y z)
LOADSYM R1, SYM_QUOTE
CONS R2, R10, R6                          ; ((x y z))
CONS R10, R1, R2                            ; q_list = (quote (x y z))

LOADSYM R1, 600                               ; 'second
CONS R2, R10, R6                                ; (q_list)
CONS R3, R1, R2                                   ; expr = (second (quote (x y z)))
MOV R4, R9                                          ; env = outer_env
CALL R5, eval

HALT                       ; R9 should hold 'y

.include "fpga/asm/eval_core.inc"
