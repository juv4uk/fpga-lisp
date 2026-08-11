; M30: canonical core.my `reverse`, via the same letrec/SETCDR mechanism
; M28/M29 proved (bootstrap_length_onto_demo.asm), applied to a second
; mutually-recursive pair:
;   (def reverse-onto (lambda (values acc)
;                        (cond ((atom values) acc)
;                              (t (reverse-onto (cdr values) (cons (car values) acc))))))
;   (def reverse (lambda (values) (reverse-onto values '())))
; (reverse '(a b c)) => (c b a)
;
; Two letrec placeholders (ph_onto, ph_reverse) share one env frame before
; either closure is built, exactly as in M29 -- see that file's header for
; the full mechanism writeup, not repeated here.
;
; Learned from M28/M29's first real run (2026-08-11, docs/lisp-machine-plan.md's
; M28 entry): a literal list passed as a call argument MUST be quoted, or
; it gets evaluated as code (applying its first element as an operator)
; instead of treated as data. Applied here from the start, not bolted on
; after a failure.
;
; STATUS: assembled and run locally with real iverilog before this file
; was committed (unlike M28's first version) -- see docs/lisp-machine-plan.md's
; M30 entry for the actual result before trusting this comment alone.

.include "fpga/asm/constants.inc"

; --- NIL (re-derived fresh right before the top-level eval call, since R6
;     gets repurposed for test-list data below) ---
LOADSYM R1, 900
LOADSYM R2, 901
EQ R6, R1, R2             ; R6 = NIL

; --- base_env: 'cdr, 'car, 'cons, 'atom bound to their hardware primitives ---
LOADI R1, PRIM_CDR
MAKEPRIM R1, R1
LOADSYM R2, 910              ; 'cdr
CONS R2, R2, R1
CONS R7, R2, R6                ; env0 = (pair_cdr)

LOADI R1, PRIM_CAR
MAKEPRIM R1, R1
LOADSYM R2, 918                 ; 'car
CONS R2, R2, R1
CONS R7, R2, R7                   ; env1 = (pair_car . env0)

LOADI R1, PRIM_CONS
MAKEPRIM R1, R1
LOADSYM R2, 915                    ; 'cons
CONS R2, R2, R1
CONS R7, R2, R7                      ; env2 = (pair_cons . env1)

LOADI R1, PRIM_ATOM
MAKEPRIM R1, R1
LOADSYM R2, 912                       ; 'atom
CONS R2, R2, R1
CONS R7, R2, R7                         ; base_env = (pair_atom . env2)

; --- letrec: two placeholders, both extending the same frame, before
;     either closure is built ---
LOADSYM R0, 916                           ; 'reverse-onto
CONS R8, R0, R6                             ; ph_onto = (reverse-onto . NIL)   [R8 kept live until its SETCDR]
CONS R7, R8, R7                               ; env += ph_onto

LOADSYM R0, 917                               ; 'reverse
CONS R9, R0, R6                                 ; ph_reverse = (reverse . NIL)   [R9 kept live until its SETCDR]
CONS R7, R9, R7                                   ; new_env = (ph_reverse . (ph_onto . base_env))   [R7 kept live]

; ============================================================
; closure_onto: (lambda (values acc) (cond ((atom values) acc)
;                                           (t (reverse-onto (cdr values) (cons (car values) acc)))))
; ============================================================

; --- params_onto = (values acc) ---
LOADSYM R0, 921                                     ; 'values   [R0 kept live through this closure's build]
LOADSYM R10, 922                                     ; 'acc   [R10 kept live through this closure's build]
CONS R1, R10, R6                                       ; (acc)
CONS R1, R0, R1                                          ; params_onto = (values acc)   [R1 kept live]

; --- test1 = (atom values) ---
CONS R2, R0, R6                                            ; (values)
LOADSYM R3, 912                                               ; 'atom
CONS R2, R3, R2                                                 ; test1 = (atom values)   [R2 kept live]

; --- clause1 = (test1 acc) -- value1 is the bare symbol 'acc ---
CONS R3, R10, R6                                                  ; (acc)
CONS R2, R2, R3                                                     ; clause1 = (test1 (acc)) = (test1 value1)   [R2 kept live]

; --- test2 = TRUE ---
EQ R4, R0, R0                                                        ; [R4 kept live]

; --- cdr_expr = (cdr values) ---
LOADSYM R3, 910
CONS R5, R0, R6
CONS R5, R3, R5                                                        ; cdr_expr   [R5 kept live]

; --- car_expr = (car values) ---
LOADSYM R3, 918
CONS R12, R0, R6
CONS R12, R3, R12                                                       ; car_expr   [R12 kept live]

; --- cons_expr = (cons car_expr acc) ---
CONS R13, R10, R6                                                         ; (acc)
CONS R13, R12, R13                                                          ; (car_expr acc)
LOADSYM R3, 915
CONS R13, R3, R13                                                             ; cons_expr = (cons car_expr acc)   [R13 kept live]

; --- value2 = (reverse-onto cdr_expr cons_expr) ---
CONS R14, R13, R6                                                               ; (cons_expr)
CONS R14, R5, R14                                                                 ; (cdr_expr cons_expr)
LOADSYM R3, 916
CONS R14, R3, R14                                                                   ; value2 = (reverse-onto cdr_expr cons_expr)   [R14 kept live]

; --- clause2 = (test2 value2) ---
CONS R15, R14, R6
CONS R15, R4, R15                                                                     ; clause2   [R15 kept live]

; --- body_onto = (cond clause1 clause2) ---
CONS R15, R15, R6                                                                       ; (clause2)
CONS R15, R2, R15                                                                         ; (clause1 clause2)
LOADSYM R3, SYM_COND
CONS R15, R3, R15                                                                           ; body_onto = (cond clause1 clause2)   [R15 kept live]

; --- closure_onto = (params_onto . (body_onto . new_env)); backpatch ph_onto ---
CONS R2, R15, R7                                                                              ; rest = (body_onto . new_env)
CONS R2, R1, R2                                                                                 ; closure_onto = (params_onto . rest)
SETCDR R0, R8, R2                                                                                 ; ph_onto's cdr: NIL -> closure_onto

; ============================================================
; closure_reverse: (lambda (values) (reverse-onto values NIL))
; ============================================================

LOADSYM R0, 921                ; params = 'values (bare symbol, single param)

LOADSYM R2, 916                  ; 'reverse-onto
CONS R4, R6, R6                    ; (NIL) -- a literal NIL atom, self-evaluating, needs no quote
CONS R4, R0, R4                      ; (values NIL)
CONS R4, R2, R4                        ; body_reverse = (reverse-onto values NIL)

; --- closure_reverse = (params . (body_reverse . new_env)); backpatch ph_reverse ---
CONS R5, R4, R7
CONS R5, R0, R5
SETCDR R1, R9, R5

; --- test data: (a b c), quoted (unlike M28's first version) since it's
;     used as a call argument and call arguments are always evaluated ---
LOADSYM R1, 930
LOADSYM R2, 931
LOADSYM R3, 932
CONS R6, R3, R6              ; (c)
CONS R6, R2, R6              ; (b c)
CONS R6, R1, R6              ; (a b c)

LOADSYM R2, 900
LOADSYM R3, 901
EQ R2, R2, R3                  ; fresh NIL
CONS R2, R6, R2                  ; ((a b c))
LOADSYM R1, SYM_QUOTE
CONS R6, R1, R2                    ; q_list = (quote (a b c))

; --- expr = (reverse (quote (a b c))) ---
LOADSYM R1, 917
LOADSYM R2, 900
LOADSYM R3, 901
EQ R2, R2, R3                        ; fresh NIL for the args-list tail
CONS R2, R6, R2                        ; ((quote (a b c)))
CONS R3, R1, R2                          ; expr = (reverse (quote (a b c)))
MOV R4, R7                                 ; env = new_env

; --- re-derive NIL fresh for the software call stack init ---
LOADSYM R10, 900
LOADSYM R12, 901
EQ R11, R10, R12                             ; R11 = NIL (software call stack, untouched until eval runs)

CALL R5, eval

HALT                       ; R9 should hold a CONS pointer to (c b a)

.include "fpga/asm/eval_core.inc"
