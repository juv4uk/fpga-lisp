; M13 eval-quote: eval(expr, env) now dispatches on ATOM vs CONS.
; Atoms behave as in M12 (symbol -> lookup, else self-evaluating).
; For a CONS expr, check car(expr) == 'quote (id 50); if so, return
; car(cdr(expr)) unevaluated. Anything else falls back to NIL (no
; other special forms exist yet -- that's M14/M15).
;
; Register discipline (still no hardware call stack): eval's frame is
; R3-R10 (expr,env,retaddr,output + scratch); lookup's frame is
; R0-R2,R12-R15 (unchanged since M10). R11 is the only register safe
; across an eval call, so it holds test 1's result while test 2 runs.

; --- test 1: eval('(quote radio), NIL) -> expect 'radio ---
LOADSYM R1, 60     ; dummy A
LOADSYM R2, 61     ; dummy B
EQ   R6, R1, R2    ; R6 = NIL
LOADSYM R7, 51     ; 'radio
CONS R8, R7, R6    ; (radio . NIL) = (radio)
LOADSYM R9, 50     ; 'quote
CONS R10, R9, R8   ; (quote . (radio)) = (quote radio)  <- expr1

MOV R3, R10        ; eval input: expr
MOV R4, R6         ; eval input: env = NIL
CALL R5, eval
MOV R11, R9        ; save result1 (R11 untouched by eval/lookup)

; --- test 2: eval('y, ((x . 10) (y . 20))) -> expect 20 (regression) ---
LOADSYM R1, 5      ; 'x
LOADI   R2, 10
LOADSYM R3, 6      ; 'y
LOADI   R4, 20
LOADSYM R5, 64     ; dummy A2
LOADSYM R6, 65     ; dummy B2
EQ   R7, R5, R6    ; NIL
CONS R8, R1, R2    ; (x . 10)
CONS R9, R3, R4    ; (y . 20)
CONS R10, R9, R7   ; (pair2 . NIL)
CONS R0, R8, R10   ; env = (pair1 . tail)

LOADSYM R2, 6      ; expr2 = 'y
MOV R3, R2
MOV R4, R0
CALL R5, eval

HALT               ; R11 = result1 ('radio), R9 = result2 (20)

eval:
ATOM R6, R3          ; R6 = TRUE if expr is not a cons
JF   R6, is_cons
; --- atom path (same as M12) ---
GETTAG R6, R3
LOADI  R7, 2         ; TAG_SYMBOL
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
CAR R6, R3           ; car(expr)
LOADSYM R7, 50       ; 'quote
EQ R8, R6, R7
JF R8, not_quote
CDR R10, R3          ; cdr(expr)
CAR R9, R10          ; car(cdr(expr))
JMP done
not_quote:
LOADSYM R6, 70
LOADSYM R7, 71
EQ R9, R6, R7        ; R9 = NIL (unrecognized form, safe default)
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
