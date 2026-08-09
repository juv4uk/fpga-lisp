; M12 eval-atom: eval(expr, env) for atoms only.
; Symbol -> looked up in env (reuses the M10 `lookup` subroutine).
; Non-symbol (fixnum here) -> self-evaluating, returned unchanged.
; Register discipline (no hardware call stack, so each subroutine
; claims a disjoint register set): main uses R0/R1/R11 as staging;
; eval's frame is R3-R9; lookup's frame is R0-R2,R12-R15 (unchanged
; from M10) so a nested eval->lookup call never clobbers eval's own
; state (expr/env/return-address/output all live outside R0-R2,R12-R15).

; --- build env = ((x . 10) (y . 20)), identical to M10 ---
LOADSYM R1, 5     ; 'x
LOADI   R2, 10
LOADSYM R3, 6     ; 'y
LOADI   R4, 20
LOADSYM R5, 9     ; dummy A
LOADSYM R6, 10    ; dummy B
EQ   R7, R5, R6   ; R7 = NIL
CONS R8, R1, R2   ; (x . 10)
CONS R9, R3, R4   ; (y . 20)
CONS R10, R9, R7  ; (pair2 . NIL)
CONS R11, R8, R10 ; env

; --- eval(expr='y, env) -> expect 20 ---
LOADSYM R0, 6     ; expr1 = 'y
MOV R3, R0
MOV R4, R11
CALL R5, eval
MOV R10, R9       ; save result1 (R10 is untouched by eval/lookup frames)

; --- eval(expr=99, env) -> expect 99 (self-evaluating) ---
LOADI R0, 99      ; expr2 = 99
MOV R3, R0
MOV R4, R11
CALL R5, eval

HALT              ; R10 = result1 (should be 20), R9 = result2 (should be 99)

eval:
GETTAG R6, R3        ; tag of expr
LOADI  R7, 2         ; TAG_SYMBOL
EQ     R8, R6, R7
JF     R8, not_symbol
MOV R12, R3          ; lookup key = expr
MOV R13, R4          ; lookup env = env
CALL R14, lookup
MOV R9, R15          ; output = lookup result
JMP eval_done
not_symbol:
MOV R9, R3           ; self-evaluating
eval_done:
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
