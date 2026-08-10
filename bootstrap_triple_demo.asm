; M24: a genuine three-parameter closure -- not from core.my, but the
; first real proof that the N-ary generalization in eval_core.inc
; (fpga/asm/eval_core.inc's closure_nary loop) works for N > 2, since
; M22's pair only ever exercised N = 2.
;
; (lambda (a b c) (cons a (cons b c))) applied to ('x 'y 'z)
; => (x y . z), i.e. outer = (x . inner), inner = (y . z)
;
; Uses .include (constants.inc + eval_core.inc).

.include "fpga/asm/constants.inc"

LOADSYM R1, 2000
LOADSYM R2, 2001
EQ R6, R1, R2         ; R6 = NIL
LOADSYM R1, 2002
LOADSYM R2, 2003
EQ R11, R1, R2         ; R11 = NIL (stack)

LOADI R1, PRIM_CONS
MAKEPRIM R1, R1
LOADSYM R2, 302             ; 'cons
CONS R7, R2, R1               ; (cons . PRIM_CONS)
CONS R7, R7, R6                 ; base_env = (pair_cons)

; params = (a b c)
LOADSYM R1, 2010                  ; 'a
LOADSYM R2, 2011                    ; 'b
LOADSYM R3, 2012                      ; 'c
CONS R8, R3, R6                         ; (c)
CONS R8, R2, R8                           ; (b c)
CONS R8, R1, R8                             ; params = (a b c)

; body = (cons a (cons b c))
LOADSYM R4, 302                               ; 'cons
CONS R9, R3, R6                                 ; (c)
CONS R9, R2, R9                                   ; (b c)
CONS R9, R4, R9                                     ; inner = (cons b c)
CONS R10, R9, R6                                      ; (inner)
CONS R10, R1, R10                                       ; (a inner)
CONS R10, R4, R10                                         ; body = (cons a inner)

CONS R4, R10, R7                                            ; rest = (body . base_env)
CONS R4, R8, R4                                               ; triple_closure = (params . rest)

LOADSYM R2, 2020                                                ; 'triple
CONS R2, R2, R4                                                   ; (triple . closure)
CONS R9, R2, R6                                                     ; outer_env = (pair_triple)

; --- build (quote x) (quote y) (quote z) ---
LOADSYM R1, SYM_QUOTE
LOADSYM R2, 2030           ; 'x
CONS R3, R2, R6              ; (x)
CONS R7, R1, R3                ; q_x = (quote x)

LOADSYM R2, 2031                 ; 'y
CONS R3, R2, R6                    ; (y)
CONS R8, R1, R3                      ; q_y = (quote y)

LOADSYM R2, 2032                       ; 'z
CONS R3, R2, R6                          ; (z)
CONS R10, R1, R3                           ; q_z = (quote z)

LOADSYM R1, 2020                             ; 'triple
CONS R2, R10, R6                               ; (q_z)
CONS R2, R8, R2                                  ; (q_y q_z)
CONS R2, R7, R2                                    ; (q_x q_y q_z)
CONS R3, R1, R2                                      ; expr = (triple q_x q_y q_z)
MOV R4, R9                                             ; env = outer_env
CALL R5, eval

HALT                       ; R9 should hold a CONS pointer to (x y . z)

.include "fpga/asm/eval_core.inc"
