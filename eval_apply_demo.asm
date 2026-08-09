; M15 eval-apply: eval(expr, env) now handles application (f arg) where
; f evaluates to a closure from M11 -- (params . (body . env)). This
; closes the loop the plan calls for: eval(operator), eval(arg), bind
; the parameter by extending the closure's captured env, then
; eval(body, new_env) -- three more recursive eval calls, using the
; same CONS-based software stack (R11) built for M14's cond. Only a
; single fixed parameter is supported (matches M11's closure shape).
;
; Test: bind 'identity to the closure (n . (n . NIL)) -- a function of
; one parameter n whose body is just n itself -- in an outer env, then
; eval (identity 42). Exercises all four eval paths in one expression:
; self-evaluating (the literal 42), symbol lookup (resolving
; 'identity and, inside the call, n), and application.

LOADSYM R1, 110
LOADSYM R2, 111
EQ R6, R1, R2      ; R6 = NIL
LOADSYM R1, 112
LOADSYM R2, 113
EQ R11, R1, R2      ; R11 = NIL (stack initialized empty)

LOADSYM R1, 40      ; 'n (parameter name, also used as the body)
CONS R3, R1, R6     ; (body . env) = (n . NIL)
CONS R4, R1, R3     ; closure = (params . rest) = (n . (n . NIL))

LOADSYM R7, 41      ; 'identity
CONS R8, R7, R4     ; (identity . closure)
CONS R9, R8, R6     ; outer_env = ((identity . closure))

LOADI R10, 42       ; the argument
CONS R1, R10, R6    ; (42)
CONS R2, R7, R1     ; expr = (identity 42)

MOV R3, R2          ; eval input: expr
MOV R4, R9          ; eval input: env
CALL R5, eval
HALT                ; R9 should hold 42

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
CAR R6, R3            ; head = car(expr), kept alive for try_apply below
LOADSYM R7, 50         ; 'quote
EQ R8, R6, R7
JF R8, check_cond
CDR R10, R3            ; --- quote form ---
CAR R9, R10
JMP done
check_cond:
LOADSYM R7, 80          ; 'cond
EQ R8, R6, R7
JF R8, try_apply
CDR R6, R3               ; --- cond form (unchanged since M14) ---
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
; --- application: expr = (operator arg), R6 = operator, R3 = expr ---
CDR R10, R3           ; args = cdr(expr)
CAR R7, R10           ; arg_expr = car(args)   (single-arg only)
CONS R11, R5, R11     ; push retaddr
CONS R11, R4, R11     ; push env
CONS R11, R7, R11     ; push arg_expr
MOV R3, R6            ; eval(operator, env)
CALL R5, eval
CAR R7, R11           ; pop arg_expr
CDR R11, R11
CAR R4, R11           ; pop env
CDR R11, R11
CAR R5, R11           ; pop retaddr
CDR R11, R11
MOV R6, R9            ; R6 = closure
CONS R11, R5, R11     ; push retaddr
CONS R11, R4, R11     ; push env
CONS R11, R6, R11     ; push closure
MOV R3, R7            ; eval(arg_expr, env)
CALL R5, eval
CAR R6, R11           ; pop closure
CDR R11, R11
CAR R4, R11           ; pop env
CDR R11, R11
CAR R5, R11           ; pop retaddr
CDR R11, R11
MOV R8, R9            ; R8 = arg value
CAR R7, R6            ; params = car(closure)
CDR R10, R6           ; rest = cdr(closure) = (body . captured_env)
CAR R6, R10           ; body = car(rest)
CDR R10, R10          ; captured_env = cdr(rest)
CONS R9, R7, R8       ; pair = (params . arg)
CONS R4, R9, R10      ; new_env = (pair . captured_env)
CONS R11, R5, R11     ; push retaddr
MOV R3, R6            ; eval(body, new_env)
CALL R5, eval
CAR R5, R11           ; pop retaddr
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
