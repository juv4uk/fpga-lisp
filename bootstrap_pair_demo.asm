; M22 bootstrap: pair -- (def pair (lambda (left right) (cons left
; (cons right '())))) from my-lisp's lib/core.my. First TWO-parameter
; closure: params is now EITHER a single symbol (1-arg, M11-M21's
; shape) OR a 2-element list (param1 param2), distinguished by ATOM
; on the params slot (a bare symbol is an atom; a list is a cons).
; do_closure_apply now branches on that check: the 1-arg path is
; unchanged; the 2-arg path evaluates both eagerly-extracted argument
; expressions (try_apply already extracts up to two, for cons/eq's
; sake) and binds both parameters by extending the captured env twice.
;
; Test: (pair (quote a) (quote b)) => (a . b)

LOADSYM R1, 1000
LOADSYM R2, 1001
EQ R6, R1, R2         ; R6 = NIL
LOADSYM R1, 1002
LOADSYM R2, 1003
EQ R11, R1, R2         ; R11 = NIL (stack)

LOADI R1, 2
MAKEPRIM R1, R1          ; PRIM2 = cons
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
LOADSYM R1, 50           ; 'quote
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

eval:
ATOM R6, R3
JF   R6, is_cons
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
CDR R10, R3
CAR R9, R10
JMP done
check_cond:
LOADSYM R7, 80
EQ R8, R6, R7
JF R8, try_apply
CDR R6, R3
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

GETVAL R8, R6
LOADI R10, 0
EQ R9, R8, R10
JF R9, chk_cdr
CAR R10, R11
CDR R11, R11
CONS R11, R5, R11
MOV R3, R7
CALL R5, eval
CAR R5, R11
CDR R11, R11
CAR R9, R9
JMP done
chk_cdr:
LOADI R10, 1
EQ R9, R8, R10
JF R9, chk_atom
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
JF R9, chk_cons
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
chk_cons:
LOADI R10, 2
EQ R9, R8, R10
JF R9, prim_fallback
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
CONS R9, R6, R9
JMP done
prim_fallback:
CAR R10, R11
CDR R11, R11
LOADSYM R6, 92
LOADSYM R7, 93
EQ R9, R6, R7
JMP done
do_closure_apply:
; R6=closure, R7=arg1_expr; pop arg2_expr into R10.
CAR R10, R11
CDR R11, R11
CAR R9, R6            ; params = car(closure), peek without disturbing R6
ATOM R8, R9
JF R8, closure_2arg    ; params is a CONS (list) -> two-parameter path
; --- one-parameter closure (unchanged since M11/M15) ---
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
closure_2arg:
; --- two-parameter closure: params = (param1 param2) ---
CONS R11, R10, R11     ; push arg2_expr
CONS R11, R5, R11        ; push retaddr
CONS R11, R4, R11         ; push calling env
CONS R11, R6, R11          ; push closure
MOV R3, R7                    ; eval(arg1_expr, calling env)
CALL R5, eval
MOV R8, R9                       ; arg1 value
CAR R6, R11                        ; pop closure
CDR R11, R11
CAR R4, R11                          ; pop calling env
CDR R11, R11
CAR R5, R11                           ; pop retaddr
CDR R11, R11
CAR R10, R11                            ; pop arg2_expr
CDR R11, R11
CONS R11, R8, R11                         ; push arg1 value
CONS R11, R5, R11                           ; push retaddr
CONS R11, R4, R11                             ; push calling env
CONS R11, R6, R11                               ; push closure
MOV R3, R10                                        ; eval(arg2_expr, calling env)
CALL R5, eval
MOV R7, R9                                            ; arg2 value  [R7 free: arg1_expr done with]
CAR R6, R11                                             ; pop closure
CDR R11, R11
CAR R4, R11                                               ; pop calling env
CDR R11, R11
CAR R5, R11                                                 ; pop retaddr
CDR R11, R11
CAR R8, R11                                                   ; pop arg1 value
CDR R11, R11
CAR R1, R6              ; params_list = car(closure)
CAR R2, R1                ; param1
CDR R1, R1                  ; rest_params
CAR R12, R1                   ; param2
CDR R6, R6                      ; closure_rest = cdr(closure) = (body.captured_env)
CAR R13, R6                       ; body
CDR R6, R6                          ; captured_env
CONS R1, R2, R8                       ; pair1 = (param1 . arg1val)
CONS R1, R1, R6                         ; env1 = (pair1 . captured_env)
CONS R2, R12, R7                          ; pair2 = (param2 . arg2val)
CONS R4, R2, R1                             ; new_env = (pair2 . env1)
CONS R11, R5, R11                             ; push retaddr
MOV R3, R13                                     ; expr = body
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
