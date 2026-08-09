; M18 eval-all-primitives: extends M16's primitive dispatch (car=0,
; cons=2) with the three remaining hardware primitives: cdr=1, atom=3,
; eq=4. Together M16+M18 make all five hardware primitives callable
; from eval as ordinary procedures bound in a base environment.
; One-argument primitives (cdr/atom) share a shape: pop+discard arg2,
; eval arg1, apply the hardware op. Two-argument eq shares cons's
; shape: pop+use arg2, eval both, apply the hardware op.
;
; (266 instructions would exceed the 256-word imem if this file also
; carried car/cons dispatch, so this test builds its (a . b) pair
; directly via hardware CONS at setup time -- wrapped in a literal
; quote -- rather than calling 'cons as a procedure; M16 already
; covers that path.)
;
; Test expression:
;   (eq (atom (cdr (quote (a . b)))) (atom (quote c)))
; (cdr (a . b)) -> b (a symbol, not a cons); (atom b) -> TRUE;
; (quote c) -> c; (atom c) -> TRUE; (eq TRUE TRUE) -> TRUE.

LOADSYM R1, 320
LOADSYM R2, 321
EQ R6, R1, R2       ; R6 = NIL
LOADSYM R1, 322
LOADSYM R2, 323
EQ R11, R1, R2       ; R11 = NIL (stack initialized empty)

LOADI R1, 1
MAKEPRIM R7, R1       ; PRIMITIVE(1) = cdr
LOADI R1, 3
MAKEPRIM R8, R1        ; PRIMITIVE(3) = atom
LOADI R1, 4
MAKEPRIM R9, R1         ; PRIMITIVE(4) = eq

LOADSYM R1, 301           ; 'cdr
CONS R2, R1, R7             ; (cdr . PRIM1)
LOADSYM R1, 303               ; 'atom
CONS R3, R1, R8                 ; (atom . PRIM3)
LOADSYM R1, 304                   ; 'eq
CONS R1, R1, R9                     ; (eq . PRIM4)
CONS R1, R1, R6                       ; (pair_eq)
CONS R3, R3, R1                         ; (pair_atom pair_eq)
CONS R4, R2, R3                           ; env = (pair_cdr pair_atom pair_eq)

; --- (a . b), built directly, then quoted ---
LOADSYM R1, 310         ; 'a
LOADSYM R2, 311           ; 'b
CONS R3, R1, R2             ; pair_ab = (a . b)
LOADSYM R1, 50                ; 'quote
CONS R2, R3, R6                 ; (pair_ab)
CONS R7, R1, R2                   ; q_pair = (quote pair_ab)

; --- (cdr q_pair) ---
LOADSYM R1, 301                     ; 'cdr
CONS R2, R7, R6
CONS R2, R1, R2                       ; cdr_expr = (cdr q_pair)

; --- (atom cdr_expr) ---
LOADSYM R1, 303                         ; 'atom
CONS R3, R2, R6
CONS R2, R1, R3                           ; atom1_expr = (atom cdr_expr)

; --- (quote c), (atom (quote c)) ---
LOADSYM R1, 50                              ; 'quote
LOADSYM R3, 312                               ; 'c
CONS R8, R3, R6
CONS R8, R1, R8                                 ; q_c = (quote c)
LOADSYM R1, 303                                   ; 'atom
CONS R9, R8, R6
CONS R3, R1, R9                                     ; atom2_expr = (atom q_c)

; --- (eq atom1_expr atom2_expr) ---
LOADSYM R1, 304                                       ; 'eq
CONS R5, R3, R6
CONS R5, R2, R5
CONS R9, R1, R5                                         ; final_expr

MOV R3, R9              ; eval input: expr
; R4 already holds env
CALL R5, eval
HALT                     ; R9 should hold TRUE

eval:
ATOM R6, R3
JF   R6, is_cons
; --- atom path (unchanged since M12) ---
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
LOADSYM R7, 50
EQ R8, R6, R7
JF R8, check_cond
CDR R10, R3           ; --- quote form ---
CAR R9, R10
JMP done
check_cond:
LOADSYM R7, 80
EQ R8, R6, R7
JF R8, try_apply
CDR R6, R3             ; --- cond form (unchanged since M14) ---
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
; expr = (operator arg1 [arg2])
CDR R10, R3
CAR R7, R10
CDR R10, R10
ATOM R9, R10
JF R9, has_second_arg
MOV R8, R10
JMP arg2_done
has_second_arg:
CAR R8, R10
arg2_done:
CONS R11, R8, R11
CONS R11, R5, R11
CONS R11, R4, R11
CONS R11, R7, R11
MOV R3, R6
CALL R5, eval
CAR R7, R11
CDR R11, R11
CAR R4, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
MOV R6, R9

GETTAG R8, R6
LOADI R10, 5
EQ R8, R8, R10
JF R8, do_closure_apply

; --- primitive dispatch: cdr=1, atom=3, eq=4 ---
GETVAL R8, R6
LOADI R10, 1
EQ R9, R8, R10
JF R9, chk_atom
; --- cdr (1-arg) ---
CAR R10, R11
CDR R11, R11
CONS R11, R5, R11
MOV R3, R7
CALL R5, eval
CAR R5, R11
CDR R11, R11
CDR R9, R9
JMP done
chk_atom:
LOADI R10, 3
EQ R9, R8, R10
JF R9, chk_eq
; --- atom (1-arg) ---
CAR R10, R11
CDR R11, R11
CONS R11, R5, R11
MOV R3, R7
CALL R5, eval
CAR R5, R11
CDR R11, R11
ATOM R9, R9
JMP done
chk_eq:
LOADI R10, 4
EQ R9, R8, R10
JF R9, prim_fallback
; --- eq (2-arg) ---
CAR R10, R11
CDR R11, R11
CONS R11, R5, R11
CONS R11, R10, R11
MOV R3, R7
CALL R5, eval
MOV R6, R9
CAR R10, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
CONS R11, R5, R11
CONS R11, R6, R11
MOV R3, R10
CALL R5, eval
CAR R6, R11
CDR R11, R11
CAR R5, R11
CDR R11, R11
EQ R9, R6, R9
JMP done
prim_fallback:
CAR R10, R11
CDR R11, R11
LOADSYM R6, 92
LOADSYM R7, 93
EQ R9, R6, R7
JMP done
do_closure_apply:
CAR R10, R11
CDR R11, R11
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
