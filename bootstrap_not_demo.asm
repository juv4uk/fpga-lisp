; M21 bootstrap: not -- the third function from my-lisp's lib/core.my:
; (def not (lambda (value) (cond (value '()) (t t)))). First closure
; body built from `cond` (a special form, not a primitive call) rather
; than an application -- so this closure's captured env can be NIL,
; it never needs to look anything up. `t` is embedded directly as the
; literal TRUE atom rather than a bound symbol, matching how NIL
; literals were embedded directly in M14/M19 rather than going through
; a symbol lookup.
;
; clause1 = (value NIL)   -- if value is truthy, returns NIL
; clause2 = (TRUE TRUE)   -- unconditional fallback, returns TRUE
;
; Test 1: (not NIL) -> value=NIL is falsy -> clause1 skipped -> TRUE
; Test 2: (not (quote a)) -> value='a is truthy -> clause1 matches -> NIL

LOADSYM R1, 800
LOADSYM R2, 801
EQ R6, R1, R2         ; R6 = NIL
LOADSYM R1, 802
LOADSYM R2, 803
EQ R11, R1, R2         ; R11 = NIL (stack)
LOADSYM R1, 804
EQ R7, R1, R1           ; R7 = TRUE (EQ of a register against itself)

LOADSYM R1, 900           ; 'value (param name)
CONS R2, R6, R6             ; (NIL) -- clause1's value-list
CONS R2, R1, R2               ; (value NIL)
CONS R8, R7, R6                 ; (TRUE)  -- clause2's value-list
CONS R8, R7, R8                   ; (TRUE TRUE)
CONS R3, R8, R6                     ; (clause2)
CONS R3, R2, R3                       ; clauses = (clause1 clause2)
LOADSYM R2, 80                          ; 'cond
CONS R3, R2, R3                           ; body = (cond clause1 clause2)

CONS R4, R3, R6                             ; rest = (body . NIL)  [captured env = NIL]
CONS R4, R1, R4                               ; not_closure = (value . rest)

LOADSYM R2, 901                                 ; 'not
CONS R2, R2, R4                                   ; (not . closure)
CONS R9, R2, R6                                     ; outer_env = (pair_not)

CONS R11, R9, R11        ; push outer_env for safekeeping across test1

; --- test 1: (not NIL) -> expect TRUE ---
LOADSYM R1, 901            ; 'not
CONS R2, R6, R6              ; (NIL)
CONS R3, R1, R2                ; expr1 = (not NIL)
MOV R4, R9                       ; env = outer_env
CALL R5, eval
CONS R11, R9, R11        ; push result1 (stack: [result1, outer_env])
CAR R9, R11               ; pop result1 back into R9 (temp)
CDR R11, R11
CAR R4, R11                ; pop outer_env directly into R4 (test2's env)
CDR R11, R11
CONS R11, R9, R11             ; re-push result1 so it survives test2

; --- test 2: (not (quote a)) -> expect NIL ---
LOADSYM R1, 901              ; 'not
LOADSYM R2, 50                 ; 'quote
LOADSYM R6, 805
LOADSYM R7, 806
EQ R7, R6, R7                    ; R7 = NIL (fresh)
LOADSYM R6, 902                    ; 'a
CONS R10, R6, R7                     ; (a)
CONS R10, R2, R10                      ; quoted_a = (quote a)
CONS R10, R10, R7                        ; (quoted_a)
CONS R3, R1, R10                           ; expr2 = (not (quote a))
CALL R5, eval
; R9 = result2. result1 is still safely on the stack from before test2.
CAR R8, R11               ; pop result1 -> R8 (final)
CDR R11, R11

HALT                       ; R8 = result1 (TRUE), R9 = result2 (NIL)

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
