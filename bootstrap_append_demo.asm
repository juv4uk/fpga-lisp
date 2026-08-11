; M31: canonical core.my `append`, built on top of the M30 reverse-onto/
; reverse letrec pair:
;   (def append (lambda (left right) (reverse-onto (reverse left) right)))
; (append '(a b) '(c d)) => (a b c d)
;
; Unlike M28-M30, `append` itself is NOT self-referential -- lib/core.my
; defines it as (reverse-onto (reverse left) right), a two-parameter
; closure that just looks up two already-bound names. So no third letrec
; placeholder is needed for `append`: build the reverse-onto/reverse
; letrec pair exactly as M30 does (same bytes, same registers), then
; extend that same env frame with one more ordinary (non-recursive)
; closure binding for `append`. It finds `reverse`/`reverse-onto` via
; plain lexical lookup through its captured env, the same mechanism
; every earlier bootstrap demo relies on -- letrec's SETCDR backpatch is
; only needed when a closure must find *itself*.
;
; Learned from M28/M29's first real run (2026-08-11): a literal list
; passed as a call argument MUST be quoted, or it gets evaluated as code.
; Applied here from the start for both `(quote (a b))` and `(quote (c d))`.
;
; STATUS: assembled and run locally with real iverilog before this file
; was committed -- see docs/lisp-machine-plan.md's M31 entry for the
; actual result before trusting this comment alone.

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
;     either closure is built (same mechanism as M28/M29/M30) ---
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

; ============================================================
; closure_append: (lambda (left right) (reverse-onto (reverse left) right))
; NOT self-referential -- just an ordinary two-param closure that looks
; up 'reverse and 'reverse-onto by name through its captured env (R7),
; the same as any earlier bootstrap demo's chained primitive calls.
; ============================================================

; --- params_append = (left right) ---
LOADSYM R0, 923                ; 'left   [R0 kept live through this section]
LOADSYM R10, 924               ; 'right  [R10 kept live through this section]
CONS R1, R10, R6                 ; (right)
CONS R1, R0, R1                    ; params_append = (left right)   [R1 kept live]

; --- inner1 = (reverse left) ---
LOADSYM R2, 917                      ; 'reverse
CONS R3, R0, R6                        ; (left)
CONS R3, R2, R3                          ; inner1 = (reverse left)   [R3 kept live]

; --- body_append = (reverse-onto inner1 right) ---
CONS R4, R10, R6                           ; (right)
CONS R4, R3, R4                              ; (inner1 right)
LOADSYM R2, 916                                ; 'reverse-onto
CONS R4, R2, R4                                  ; body_append = (reverse-onto inner1 right)   [R4 kept live]

; --- closure_append = (params_append . (body_append . new_env)) ---
CONS R5, R4, R7                                    ; rest = (body_append . new_env)
CONS R5, R1, R5                                      ; closure_append = (params_append . rest)

; --- extend env with 'append -> closure_append (no letrec: not self-referential) ---
LOADSYM R2, 919                                        ; 'append
CONS R2, R2, R5                                          ; pair_append = (append . closure_append)
CONS R7, R2, R7                                            ; final_env = (pair_append . new_env)   [R7 kept live]

; --- test data: (a b) and (c d), each quoted since they're call arguments
;     and call arguments are always evaluated ---
LOADSYM R1, 930
LOADSYM R2, 931
LOADSYM R3, 900
LOADSYM R4, 901
EQ R11, R3, R4                ; fresh NIL -> R11
CONS R11, R2, R11              ; (b)
CONS R11, R1, R11               ; list_ab = (a b)

LOADSYM R1, 932
LOADSYM R2, 933
LOADSYM R3, 900
LOADSYM R4, 901
EQ R13, R3, R4                 ; fresh NIL -> R13
CONS R13, R2, R13                ; (d)
CONS R13, R1, R13                 ; list_cd = (c d)

LOADSYM R3, 900
LOADSYM R4, 901
EQ R14, R3, R4                     ; fresh NIL -> R14
CONS R14, R11, R14                   ; (list_ab)
LOADSYM R1, SYM_QUOTE
CONS R11, R1, R14                      ; q_ab = (quote (a b))

LOADSYM R3, 900
LOADSYM R4, 901
EQ R15, R3, R4                           ; fresh NIL -> R15
CONS R15, R13, R15                         ; (list_cd)
LOADSYM R1, SYM_QUOTE
CONS R13, R1, R15                            ; q_cd = (quote (c d))

; --- args = (q_ab q_cd) ---
LOADSYM R1, 900
LOADSYM R2, 901
EQ R6, R1, R2                                  ; fresh NIL -> R6
CONS R6, R13, R6                                 ; (q_cd)
CONS R6, R11, R6                                   ; (q_ab q_cd)

; --- expr = (append q_ab q_cd) ---
LOADSYM R1, 919                                      ; 'append
CONS R3, R1, R6                                        ; expr = (append q_ab q_cd)
MOV R4, R7                                               ; env = final_env (append/reverse/reverse-onto bound)

; --- re-derive NIL fresh for the software call stack init ---
LOADSYM R10, 900
LOADSYM R12, 901
EQ R11, R10, R12                                           ; R11 = NIL (software call stack, untouched until eval runs)

CALL R5, eval

HALT                       ; R9 should hold a CONS pointer to (a b c d)

.include "fpga/asm/eval_core.inc"
