; M14 eval-cond: eval(expr, env) now recognizes (cond (t1 v1) (t2 v2) ...)
; and evaluates clauses in order. This is eval's first genuine
; self-recursion (evaluating a clause's test, and its value, both
; require calling eval again) -- which a fixed register-frame calling
; convention cannot survive, since the recursive call reuses the exact
; same registers. Solution: a software call stack built from ordinary
; CONS cells, R11 as the stack-top pointer. push(v): R11=CONS(v,R11);
; pop into v: v=CAR(R11), R11=CDR(R11). Whatever a recursive eval call
; would otherwise clobber (our own return address, the clauses cursor,
; the current clause) gets pushed right before the call and popped
; right after -- the heap itself becomes the missing call stack.
;
; Mirrors conformance.my's fixture: (cond (() 'wrong) (t 'right)) => right

; Values are (quote X) sub-expressions, not bare symbols -- a bare
; symbol value would make eval look it up as a variable (M12's own
; rule), which is not what `(cond (t 'right))` means: 'right is reader
; shorthand for (quote right).
LOADSYM R1, 100
LOADSYM R2, 101
EQ R11, R1, R2      ; R11 = NIL (stack initialized empty)

LOADSYM R1, 102
EQ R2, R1, R1        ; R2 = TRUE (EQ of a register against itself)

LOADSYM R3, 103
LOADSYM R4, 104
EQ R5, R3, R4         ; R5 = NIL (falsy test value, and list terminator)

LOADSYM R6, 81         ; 'wrong
CONS R7, R6, R5        ; (wrong)
LOADSYM R6, 50         ; 'quote
CONS R7, R6, R7        ; value1 = (quote wrong)
CONS R8, R7, R5        ; (value1)
CONS R8, R5, R8        ; clause1 = (NIL (quote wrong))   [test=NIL -> falsy]

LOADSYM R9, 82         ; 'right
CONS R10, R9, R5       ; (right)
LOADSYM R9, 50         ; 'quote
CONS R10, R9, R10      ; value2 = (quote right)
CONS R1, R10, R5       ; (value2)
CONS R1, R2, R1        ; clause2 = (TRUE (quote right)) [test=TRUE -> truthy]

CONS R3, R1, R5        ; (clause2)
CONS R4, R8, R3        ; clauses = (clause1 clause2)

LOADSYM R6, 80         ; 'cond
CONS R9, R6, R4        ; cond-expr = (cond (NIL (quote wrong)) (TRUE (quote right)))

MOV R3, R9             ; eval input: expr = cond-expr
MOV R4, R5             ; eval input: env = NIL
CALL R5, eval
HALT                   ; R9 should hold 'right

eval:
ATOM R6, R3
JF   R6, is_cons
; --- atom path (unchanged from M12/M13) ---
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
CAR R6, R3           ; head = car(expr)
LOADSYM R7, 50        ; 'quote
EQ R8, R6, R7
JF R8, check_cond
CDR R10, R3           ; --- quote form ---
CAR R9, R10
JMP done
check_cond:
LOADSYM R7, 80        ; 'cond
EQ R8, R6, R7
JF R8, unknown_form
CDR R6, R3            ; clauses = cdr(expr)
cond_loop:
ATOM R8, R6           ; TRUE if clauses exhausted (not a cons)
JF R8, has_clause
LOADSYM R6, 90
LOADSYM R7, 91
EQ R9, R6, R7         ; no clause matched -> NIL
JMP done
has_clause:
CAR R10, R6           ; clause = car(clauses)
CAR R7, R10           ; test = car(clause)
CONS R11, R5, R11     ; push retaddr
CONS R11, R6, R11     ; push clauses cursor
CONS R11, R10, R11    ; push clause
MOV R3, R7            ; recursive eval(test, env)
CALL R5, eval
CAR R10, R11          ; pop clause
CDR R11, R11
CAR R6, R11           ; pop clauses cursor
CDR R11, R11
CAR R5, R11           ; pop retaddr
CDR R11, R11
JF R9, clause_false
CDR R8, R10           ; rest-of-clause = cdr(clause)
CAR R8, R8            ; value-expr = car(rest-of-clause)
CONS R11, R5, R11     ; push retaddr
MOV R3, R8            ; recursive eval(value-expr, env)
CALL R5, eval
CAR R5, R11           ; pop retaddr
CDR R11, R11
JMP done
clause_false:
CDR R6, R6            ; clauses = cdr(clauses)
JMP cond_loop
unknown_form:
LOADSYM R6, 92
LOADSYM R7, 93
EQ R9, R6, R7         ; unrecognized form -> NIL
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
