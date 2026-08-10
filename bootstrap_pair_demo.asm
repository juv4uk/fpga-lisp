; M22 bootstrap: pair -- (def pair (lambda (left right) (cons left
; (cons right '())))) from my-lisp's lib/core.my. First TWO-parameter
; closure: params is now EITHER a single symbol (1-arg, M11-M21's
; shape) OR a 2-element list (param1 param2), distinguished by ATOM
; on the params slot (a bare symbol is an atom; a list is a cons).
; do_closure_apply's closure_nary loop (generalized in M24 -- see
; fpga/asm/eval_core.inc) binds both parameters by walking params and
; args together and extending the captured env once per parameter.
;
; Uses .include (constants.inc + eval_core.inc) instead of hand-copied
; eval/lookup and magic numbers -- see fpga/asm/*.inc.
;
; Test: (pair (quote a) (quote b)) => (a . b)

.include "fpga/asm/constants.inc"

LOADSYM R1, 1000
LOADSYM R2, 1001
EQ R6, R1, R2         ; R6 = NIL
LOADSYM R1, 1002
LOADSYM R2, 1003
EQ R11, R1, R2         ; R11 = NIL (stack)

LOADI R1, PRIM_CONS
MAKEPRIM R1, R1
LOADSYM R2, 302             ; 'cons
CONS R7, R2, R1               ; (cons . PRIM2)
CONS R7, R7, R6                 ; base_env = (pair_cons)

LOADSYM R1, 1010                  ; 'left (param1)
LOADSYM R2, 1011                    ; 'right (param2)
CONS R8, R2, R6                       ; (right)
CONS R8, R1, R8                         ; params = (left . (right)) = (left right)

LOADSYM R3, 302                           ; 'cons
CONS R9, R6, R6                             ; (NIL)
CONS R9, R2, R9                               ; (right NIL)
CONS R9, R3, R9                                 ; inner = (cons right NIL)
CONS R10, R9, R6                                  ; (inner)
CONS R10, R1, R10                                   ; (left inner)
CONS R10, R3, R10                                     ; body = (cons left inner)

CONS R4, R10, R7                                        ; rest = (body . base_env)
CONS R4, R8, R4                                           ; pair_closure = (params . rest)

LOADSYM R2, 1020                                            ; 'pair
CONS R2, R2, R4                                               ; (pair . closure)
CONS R9, R2, R6                                                 ; outer_env = (pair_pair)

; --- build (quote a), (quote b) ---
LOADSYM R1, SYM_QUOTE
LOADSYM R2, 1030           ; 'a
CONS R3, R2, R6              ; (a)
CONS R7, R1, R3                ; q_a = (quote a)

LOADSYM R2, 1031                 ; 'b
CONS R3, R2, R6                    ; (b)
CONS R8, R1, R3                      ; q_b = (quote b)

LOADSYM R1, 1020                       ; 'pair
CONS R3, R8, R6                          ; (q_b)
CONS R3, R7, R3                            ; (q_a q_b)
CONS R3, R1, R3                              ; expr = (pair q_a q_b)
MOV R4, R9                                     ; env = outer_env
CALL R5, eval

HALT                       ; R9 should hold a CONS pointer to (a . b)

.include "fpga/asm/eval_core.inc"
