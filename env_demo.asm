; M10 ENVIRONMENT: build ((x . 10) (y . 20)) as an alist of CONS pairs,
; then call a hand-written `lookup` subroutine (walks the alist with
; CAR/CDR/EQ) to find the value bound to 'y. This is the environment
; representation the plan calls for -- no special ENV hardware type,
; just ordinary cons structure -- exercised before eval exists.
LOADSYM R1, 5     ; 'x
LOADI   R2, 10
LOADSYM R3, 6     ; 'y
LOADI   R4, 20
LOADSYM R5, 9     ; dummy A
LOADSYM R6, 10    ; dummy B (different, for the EQ->NIL trick)
EQ   R7, R5, R6   ; R7 = NIL
CONS R8, R1, R2   ; pair1 = (x . 10)
CONS R9, R3, R4   ; pair2 = (y . 20)
CONS R10, R9, R7  ; tail  = (pair2 . NIL)
CONS R11, R8, R10 ; env   = (pair1 . tail) = ((x . 10) (y . 20))

LOADSYM R12, 6    ; search key = 'y
MOV  R13, R11     ; env cursor = env
CALL R14, lookup
HALT              ; lookup returns here; R15 should hold the value

lookup:
CAR R0, R13       ; R0 = current pair
CAR R1, R0        ; R1 = key-of-pair
EQ  R2, R1, R12   ; R2 = (key-of-pair == search key)
JF  R2, next
CDR R15, R0       ; found: R15 = value
RET R14
next:
CDR R13, R13      ; env cursor = cdr(env)
JMP lookup
