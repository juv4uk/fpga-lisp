; M11 LAMBDA: represent a closure as (params . (body . env)) -- no
; special hardware closure type, just CONS structure, per the plan.
; "Calling" it means: extract params, extend the captured env with
; (param . arg), then look the param up in the new env to confirm the
; binding took -- standing in for what eval will later do when it
; evaluates the body in that extended environment (eval itself is the
; next milestone; this only proves the binding mechanism).
LOADSYM R3, 5     ; param name 'x
LOADI   R4, 42    ; argument value to bind
LOADSYM R5, 9     ; dummy A
LOADSYM R6, 10    ; dummy B (different, for EQ->NIL trick)
EQ   R7, R5, R6   ; R7 = NIL (closure's captured/outer env)
LOADSYM R8, 7     ; body placeholder symbol (not evaluated -- no eval yet)
CONS R9, R8, R7   ; (body . env)
CONS R10, R3, R9  ; closure = (params . (body . env))

CAR R11, R10      ; params = car(closure)
CDR R6, R10       ; rest = cdr(closure) = (body . env)   [R6 reused]
CDR R5, R6        ; env = cdr(rest)                       [R5 reused]

CONS R9, R11, R4  ; pair = (params . arg)                 [R9 reused]
CONS R8, R9, R5   ; new_env = (pair . env)                [R8 reused]

MOV  R12, R11     ; lookup search key = params
MOV  R13, R8      ; lookup env cursor = new_env
CALL R14, lookup
HALT              ; lookup returns here; R15 should hold the bound value (42)

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
