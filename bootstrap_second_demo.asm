; M20 bootstrap: second -- the second function ported from my-lisp's
; lib/core.my: (def second (lambda (values) (car (cdr values)))).
; A different composition shape than M19's null?: the closure body
; chains TWO primitive calls (car of cdr), rather than calling one
; primitive directly on the parameter. Applied to a quoted 3-element
; list (x y z), expect 'y.

LOADSYM R1, 700
LOADSYM R2, 701
EQ R6, R1, R2         ; R6 = NIL
LOADSYM R1, 702
LOADSYM R2, 703
EQ R11, R1, R2         ; R11 = NIL (stack)

LOADI R1, 0
MAKEPRIM R1, R1          ; PRIM0 = car
LOADI R2, 1
MAKEPRIM R2, R2            ; PRIM1 = cdr

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
LOADSYM R1, 50                          ; 'quote
CONS R2, R10, R6                          ; ((x y z))
CONS R10, R1, R2                            ; q_list = (quote (x y z))

LOADSYM R1, 600                               ; 'second
CONS R2, R10, R6                                ; (q_list)
CONS R3, R1, R2                                   ; expr = (second (quote (x y z)))
MOV R4, R9                                          ; env = outer_env
CALL R5, eval

HALT                       ; R9 should hold 'y

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
