; M32: canonical core.my `equal?`, structural equality via letrec
; self-recursion (single placeholder, unlike M29/M30's mutually-recursive
; pairs -- equal? calls only itself):
;   (def equal? (lambda (a b)
;                 (cond
;                   ((atom a) (cond ((atom b) (eq a b)) (t '())))
;                   ((atom b) '())
;                   (t (cond
;                        ((equal? (car a) (car b)) (equal? (cdr a) (cdr b)))
;                        (t '()))))))
; (equal? (quote (p . q)) (quote (p . q))) => t
;   -- two SEPARATE cons cells with the same content, proving real
;      structural comparison rather than an `eq` pointer-identity shortcut
;      (the whole reason `equal?` exists as distinct from `eq`).
;
; Edge-case checklist gathered from my-lisp's TCP sexpr-protocol oracle
; (mailbox ids 15/16/19, 2026-08-12, cross-checked by both the OpenCode
; and my-lisp agents independently) confirms: self-referential/circular
; cons is out of scope -- the language has no set-cdr!/mutation primitive
; reachable from user code, so equal? can never be asked to walk a cycle.
; No watchdog-avoidance logic needed here beyond the same one every other
; testbench already has.
;
; Three-clause top-level `cond` (unlike M28-M31's two-clause bodies) --
; the general recursive cond dispatcher proven by M14 handles N clauses,
; not just two; this is the first bootstrap demo to actually exercise
; that generality.
;
; Learned from M28/M29's first real run: a literal list passed as a call
; argument MUST be quoted. Applied here from the start for both operands.
;
; STATUS: assembled locally; iverilog/vvp run deferred (cml reported
; concurrent-simulation resource contention on this shared WSL machine,
; 2026-08-12) -- see docs/lisp-machine-plan.md's M32 entry for the actual
; run result before trusting this comment alone.

.include "fpga/asm/constants.inc"

; --- NIL (re-derived fresh right before the top-level eval call) ---
LOADSYM R1, 900
LOADSYM R2, 901
EQ R6, R1, R2             ; R6 = NIL

; --- base_env: 'cdr, 'car, 'atom, 'eq bound to their hardware primitives ---
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

LOADI R1, PRIM_ATOM
MAKEPRIM R1, R1
LOADSYM R2, 912                    ; 'atom
CONS R2, R2, R1
CONS R7, R2, R7                      ; env2 = (pair_atom . env1)

LOADI R1, PRIM_EQ
MAKEPRIM R1, R1
LOADSYM R2, 941                       ; 'eq
CONS R2, R2, R1
CONS R7, R2, R7                         ; base_env = (pair_eq . env2)

; --- letrec: single placeholder, `equal?` is self-recursive only
;     (not mutually recursive with a second function like M29/M30) ---
LOADSYM R0, 940                           ; 'equal?
CONS R8, R0, R6                             ; ph_equal = (equal? . NIL)   [R8 kept live until its SETCDR]
CONS R7, R8, R7                               ; new_env = (ph_equal . base_env)   [R7 kept live]

; ============================================================
; closure_equal: (lambda (a b)
;                  (cond
;                    ((atom a) (cond ((atom b) (eq a b)) (t '())))
;                    ((atom b) '())
;                    (t (cond
;                         ((equal? (car a) (car b)) (equal? (cdr a) (cdr b)))
;                         (t '())))))
; ============================================================

; --- params = (a b) ---
LOADSYM R0, 930                                     ; 'a   [R0 kept live through this closure's build]
LOADSYM R9, 931                                     ; 'b   [R9 kept live through this closure's build]
CONS R1, R9, R6                                       ; (b)
CONS R1, R0, R1                                         ; params = (a b)   [R1 kept live]

; --- test_atom_a = (atom a) ---
CONS R2, R0, R6                                           ; (a)
LOADSYM R3, 912
CONS R2, R3, R2                                             ; test_atom_a = (atom a)   [R2 kept live]

; --- test_atom_b (first use, inside the nested atom-a-true cond) ---
CONS R4, R9, R6                                               ; (b)
LOADSYM R3, 912
CONS R4, R3, R4                                                 ; test_atom_b_1 = (atom b)   [R4 kept live]

; --- value1b = (eq a b) ---
CONS R5, R9, R6                                                   ; (b)
CONS R5, R0, R5                                                     ; (a b)
LOADSYM R3, 941
CONS R5, R3, R5                                                       ; value1b = (eq a b)   [R5 kept live]

; --- clause1b = (test_atom_b_1 value1b) ---
CONS R10, R5, R6
CONS R10, R4, R10                                                       ; clause1b   [R10 kept live]

; --- TRUE (reused for every `t` clause in this closure) ---
EQ R11, R0, R0                                                             ; TRUE   [R11 kept live]

; --- clause2b = (TRUE NIL) ---
CONS R12, R6, R6                                                             ; (NIL)
CONS R12, R11, R12                                                             ; clause2b = (TRUE NIL)   [R12 kept live]

; --- inner_cond1 = (cond clause1b clause2b) ---
CONS R13, R12, R6                                                                ; (clause2b)
CONS R13, R10, R13                                                                 ; (clause1b clause2b)
LOADSYM R3, SYM_COND
CONS R13, R3, R13                                                                    ; inner_cond1   [R13 kept live]

; --- clause1 = (test_atom_a inner_cond1) ---
CONS R14, R13, R6
CONS R14, R2, R14                                                                       ; clause1   [R14 kept live]

; --- test_atom_b_2 = (atom b) (second use, top-level clause2's test) ---
CONS R15, R9, R6
LOADSYM R3, 912
CONS R15, R3, R15                                                                          ; test_atom_b_2   [R15 kept live]

; --- clause2 = (test_atom_b_2 NIL) ---
CONS R4, R6, R6                                                                              ; (NIL)   [R4 reused, test_atom_b_1 already consumed]
CONS R4, R15, R4                                                                               ; clause2   [R4 kept live]

; --- inner_a_car = (car a) ---
CONS R2, R0, R6                                                                                 ; (a)   [R2 reused, test_atom_a already consumed]
LOADSYM R3, 918
CONS R2, R3, R2                                                                                    ; inner_a_car   [R2 kept live]

; --- inner_b_car = (car b) ---
CONS R5, R9, R6                                                                                     ; (b)   [R5 reused, value1b already consumed]
CONS R5, R3, R5                                                                                        ; inner_b_car (reuses R3=918)   [R5 kept live]

; --- test2a = (equal? inner_a_car inner_b_car) ---
CONS R10, R5, R6                                                                                        ; (inner_b_car)   [R10 reused]
CONS R10, R2, R10                                                                                          ; (inner_a_car inner_b_car)
LOADSYM R3, 940
CONS R10, R3, R10                                                                                             ; test2a   [R10 kept live]

; --- inner_a_cdr = (cdr a) ---
CONS R12, R0, R6                                                                                                ; (a)   [R12 reused, clause2b already consumed]
LOADSYM R3, 910
CONS R12, R3, R12                                                                                                  ; inner_a_cdr   [R12 kept live]

; --- inner_b_cdr = (cdr b) ---
CONS R13, R9, R6                                                                                                    ; (b)   [R13 reused, inner_cond1 already consumed]
CONS R13, R3, R13                                                                                                      ; inner_b_cdr (reuses R3=910)   [R13 kept live]

; --- value2a = (equal? inner_a_cdr inner_b_cdr) ---
CONS R15, R13, R6                                                                                                        ; (inner_b_cdr)   [R15 reused, test_atom_b_2 already consumed]
CONS R15, R12, R15                                                                                                          ; (inner_a_cdr inner_b_cdr)
LOADSYM R3, 940
CONS R15, R3, R15                                                                                                              ; value2a   [R15 kept live]

; --- clause_i1 = (test2a value2a) ---
CONS R2, R15, R6                                                                                                                 ; (value2a)   [R2 reused, inner_a_car already consumed]
CONS R2, R10, R2                                                                                                                    ; clause_i1   [R2 kept live]

; --- clause_i2 = (TRUE NIL) ---
CONS R5, R6, R6                                                                                                                      ; (NIL)   [R5 reused, inner_b_car already consumed]
CONS R5, R11, R5                                                                                                                        ; clause_i2   [R5 kept live]

; --- inner_cond2 = (cond clause_i1 clause_i2) ---
CONS R10, R5, R6                                                                                                                          ; (clause_i2)   [R10 reused, test2a already consumed]
CONS R10, R2, R10                                                                                                                            ; (clause_i1 clause_i2)
LOADSYM R3, SYM_COND
CONS R10, R3, R10                                                                                                                               ; inner_cond2   [R10 kept live]

; --- clause3 = (TRUE inner_cond2) ---
CONS R12, R10, R6                                                                                                                                  ; (inner_cond2)   [R12 reused, inner_a_cdr already consumed]
CONS R12, R11, R12                                                                                                                                    ; clause3   [R12 kept live]

; --- body = (cond clause1 clause2 clause3) -- three top-level clauses ---
CONS R13, R12, R6                                                                                                                                       ; (clause3)   [R13 reused, inner_b_cdr already consumed]
CONS R13, R4, R13                                                                                                                                          ; (clause2 clause3)
CONS R13, R14, R13                                                                                                                                           ; (clause1 clause2 clause3)
LOADSYM R3, SYM_COND
CONS R13, R3, R13                                                                                                                                              ; body   [R13 kept live]

; --- closure_equal = (params . (body . new_env)); backpatch ph_equal ---
CONS R2, R13, R7                                                                                                                                                 ; rest = (body . new_env)   [R2 reused]
CONS R2, R1, R2                                                                                                                                                    ; closure_equal = (params . rest)
SETCDR R0, R8, R2                                                                                                                                                    ; ph_equal's cdr: NIL -> closure_equal

; --- test data: (p . q) built TWICE as distinct cons cells, each quoted
;     since they're call arguments and call arguments are always
;     evaluated -- proves structural, not pointer, equality ---
LOADSYM R1, 934                ; 'p
LOADSYM R2, 935                ; 'q
CONS R3, R1, R2                  ; list1 = (p . q)

LOADSYM R1, 934
LOADSYM R2, 935
CONS R4, R1, R2                    ; list2 = (p . q) -- a second, distinct cons cell

LOADSYM R1, 900
LOADSYM R2, 901
EQ R5, R1, R2                        ; fresh NIL
CONS R5, R3, R5                        ; (list1)
LOADSYM R1, SYM_QUOTE
CONS R3, R1, R5                          ; q1 = (quote list1)

LOADSYM R1, 900
LOADSYM R2, 901
EQ R6, R1, R2                              ; fresh NIL
CONS R6, R4, R6                              ; (list2)
LOADSYM R1, SYM_QUOTE
CONS R4, R1, R6                                ; q2 = (quote list2)

; --- args = (q1 q2) ---
LOADSYM R1, 900
LOADSYM R2, 901
EQ R6, R1, R2                                    ; fresh NIL
CONS R6, R4, R6                                    ; (q2)
CONS R6, R3, R6                                      ; (q1 q2)

; --- expr = (equal? q1 q2) ---
LOADSYM R1, 940                                        ; 'equal?
CONS R3, R1, R6                                          ; expr = (equal? q1 q2)
MOV R4, R7                                                 ; env = final env (equal?/eq/atom/car/cdr bound)

; --- re-derive NIL fresh for the software call stack init ---
LOADSYM R10, 900
LOADSYM R12, 901
EQ R11, R10, R12                                             ; R11 = NIL (software call stack, untouched until eval runs)

CALL R5, eval

HALT                       ; R9 should hold TRUE (t)

.include "fpga/asm/eval_core.inc"
