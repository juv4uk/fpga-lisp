; M19 bootstrap: null? -- the first function ported from my-lisp's
; lib/core.my, defined there as (defun null? (x) (eq x nil)).
; Represented as a closure: params='x, body=(eq x NIL), captured
; env=((eq . PRIMITIVE(eq))). Bound to 'null? in an outer env, then
; applied to two arguments: NIL itself (expect TRUE) and (quote a)
; (expect NIL). Exercises a closure body that calls a primitive
; procedure -- the first real step of bootstrap, using nothing but
; mechanisms already verified (M11 closures, M16/M18 primitives, M15
; application).
;
; Register discipline: main builds outer_env once, pushes it onto the
; R11 software stack (transparent to eval's own push/pop -- eval never
; touches what's below its own frames), pops it back between the two
; top-level eval calls. Nothing here is new hardware or new eval
; logic; it is the first payload built entirely from existing pieces.

LOADSYM R1, 500
LOADSYM R2, 501
EQ R6, R1, R2         ; R6 = NIL
LOADSYM R1, 502
LOADSYM R2, 503
EQ R11, R1, R2         ; R11 = NIL (stack initialized empty)

LOADI R1, 4
MAKEPRIM R1, R1          ; PRIMITIVE(4) = eq
LOADSYM R2, 304            ; 'eq
CONS R2, R2, R1              ; pair_eq = (eq . PRIM4)
CONS R7, R2, R6                ; base_env = (pair_eq)   [null?'s captured env]

LOADSYM R1, 402                  ; x (parameter name)
CONS R8, R6, R6                    ; (NIL . NIL) = (NIL)
CONS R8, R1, R8                      ; (x NIL)
LOADSYM R2, 304                        ; 'eq
CONS R8, R2, R8                          ; body = (eq x NIL)

CONS R4, R8, R7                            ; rest = (body . base_env)
CONS R4, R1, R4                              ; null?_closure = (x . (body . base_env))

LOADSYM R2, 400                                    ; 'null?
CONS R2, R2, R4                                      ; (null? . closure)
CONS R9, R2, R6                                        ; outer_env = (pair_null?)

CONS R11, R9, R11        ; push outer_env for safekeeping across test1's call

; --- test 1: (null? NIL) -> expect TRUE ---
LOADSYM R1, 400            ; 'null?
CONS R2, R6, R6              ; (NIL)
CONS R3, R1, R2                ; expr1 = (null? NIL)
MOV R4, R9                       ; env = outer_env
CALL R5, eval
; R9 = result1. It must NOT be left in any plain register: eval's own
; scratch usage during test2 will clobber every register except R11's
; stack discipline (this is exactly the outer_env-preservation trick,
; applied to our own result this time -- forgetting to do so here was
; the actual bug in an earlier version of this test).
CONS R11, R9, R11        ; push result1 (stack: [result1, outer_env])
CAR R9, R11               ; pop result1 back into R9 (temp)
CDR R11, R11
CAR R4, R11                ; pop outer_env directly into R4 (env for
CDR R11, R11                ; test2; nothing below touches R4 before use)
CONS R11, R9, R11             ; re-push result1 so it survives test2

; --- test 2: (null? (quote a)) -> expect NIL ---
LOADSYM R1, 400              ; 'null?
LOADSYM R2, 50                 ; 'quote
LOADSYM R6, 504
LOADSYM R7, 505
EQ R7, R6, R7                        ; R7 = NIL (fresh, since R6 was reused as scratch)
LOADSYM R6, 401                        ; 'a (reload)
CONS R10, R6, R7                         ; (a)
CONS R10, R2, R10                          ; quoted_a = (quote a)
CONS R10, R10, R7                            ; (quoted_a)
CONS R3, R1, R10                               ; expr2 = (null? (quote a))
; R4 already holds outer_env (set at line 59, untouched by expr2 build)
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
