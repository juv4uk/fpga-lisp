; M16 eval-primitive-apply: bind 'car and 'cons in a base environment
; to PRIMITIVE-tagged markers (new TAG_PRIMITIVE, made via the MOV
; submode MAKEPRIM) instead of closures, and teach eval's application
; path to dispatch straight to the hardware CAR/CONS opcodes when the
; evaluated operator is a primitive. This finally reaches the plan's
; literal Etap-1 goal:
;
;   (eval '(car (cons 'a 'b)) env) => a
;
; try_apply now eagerly extracts BOTH possible argument expressions
; (arg1, arg2) since it doesn't know yet whether the operator needs
; one (car) or two (cons) -- arg2_expr is pushed onto the CONS-based
; software stack immediately and popped (used or discarded) on every
; path, so the shared stack stays balanced for whoever called us.

LOADSYM R1, 150
LOADSYM R2, 151
EQ R6, R1, R2       ; R6 = NIL
LOADSYM R1, 152
LOADSYM R2, 153
EQ R11, R1, R2       ; R11 = NIL (stack initialized empty)

LOADI R1, 0
MAKEPRIM R7, R1       ; R7 = PRIMITIVE(0) = car
LOADI R1, 2
MAKEPRIM R8, R1        ; R8 = PRIMITIVE(2) = cons

LOADSYM R1, 200          ; 'car (env key)
LOADSYM R2, 201           ; 'cons (env key)
CONS R9, R1, R7            ; pair1 = (car . PRIMITIVE(0))
CONS R10, R2, R8            ; pair2 = (cons . PRIMITIVE(2))
CONS R3, R10, R6              ; (pair2 . NIL)
CONS R4, R9, R3                ; env = (pair1 pair2)

LOADSYM R1, 50                  ; 'quote
LOADSYM R2, 210                  ; 'a
CONS R3, R2, R6                    ; (a)
CONS R5, R1, R3                     ; quoted_a = (quote a)

LOADSYM R2, 211                       ; 'b
CONS R3, R2, R6                         ; (b)
CONS R7, R1, R3                          ; quoted_b = (quote b)

LOADSYM R1, 201                            ; 'cons
CONS R3, R7, R6                              ; (quoted_b)
CONS R3, R5, R3                               ; (quoted_a quoted_b)
CONS R8, R1, R3                                ; innerexpr = (cons quoted_a quoted_b)

LOADSYM R1, 200                                  ; 'car
CONS R3, R8, R6                                    ; (innerexpr)
CONS R9, R1, R3                                     ; expr = (car innerexpr)

MOV R3, R9              ; eval input: expr = (car (cons (quote a) (quote b)))
; R4 already holds env
CALL R5, eval
HALT                     ; R9 should hold 'a

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
CAR R6, R3
LOADSYM R7, 50
EQ R8, R6, R7
JF R8, check_cond
CDR R10, R3           ; --- quote form ---
CAR R9, R10
JMP done
check_cond:
LOADSYM R7, 80
EQ R8, R6, R7
JF R8, try_apply
CDR R6, R3             ; --- cond form (unchanged since M14) ---
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
; expr = (operator arg1 [arg2]). Extract both possible args eagerly --
; we don't yet know if the operator wants one (car) or two (cons).
CDR R10, R3            ; args = cdr(expr)
CAR R7, R10             ; arg1_expr = car(args)
CDR R10, R10             ; args_rest = cdr(args)
ATOM R9, R10              ; TRUE if args_rest is NOT a cons (no second arg)
JF R9, has_second_arg
MOV R8, R10                 ; no second arg: arg2_expr = NIL (safe placeholder,
JMP arg2_done                ; never read except by the (unused-here) cons path)
has_second_arg:
CAR R8, R10                   ; arg2_expr = car(args_rest)
arg2_done:
CONS R11, R8, R11           ; push arg2_expr (long-lived: popped on every path below)
CONS R11, R5, R11             ; push retaddr
CONS R11, R4, R11               ; push env
CONS R11, R7, R11                 ; push arg1_expr
MOV R3, R6                           ; eval(operator, env)
CALL R5, eval
CAR R7, R11                            ; pop arg1_expr
CDR R11, R11
CAR R4, R11                             ; pop env
CDR R11, R11
CAR R5, R11                              ; pop retaddr
CDR R11, R11
MOV R6, R9                                 ; R6 = operator's value

GETTAG R8, R6
LOADI R10, 5              ; TAG_PRIMITIVE
EQ R8, R8, R10
JF R8, do_closure_apply

; --- primitive dispatch ---
GETVAL R8, R6                ; primitive id as a fixnum
LOADI R10, 0
EQ R9, R8, R10
JF R9, check_cons_prim
; --- car primitive (1 arg) ---
CAR R10, R11                   ; pop arg2_expr (discard, car ignores it)
CDR R11, R11
CONS R11, R5, R11
MOV R3, R7                       ; eval(arg1_expr, env)
CALL R5, eval
CAR R5, R11
CDR R11, R11
CAR R9, R9                        ; apply hardware CAR to the evaluated value
JMP done
check_cons_prim:
LOADI R10, 2
EQ R9, R8, R10
JF R9, prim_fallback
; --- cons primitive (2 args) ---
CAR R10, R11                       ; pop arg2_expr (this time we use it)
CDR R11, R11
CONS R11, R5, R11
CONS R11, R10, R11                   ; keep arg2_expr alive across arg1's eval
MOV R3, R7                             ; eval(arg1_expr, env)
CALL R5, eval
MOV R6, R9                               ; R6 = arg1 value
CAR R10, R11                               ; pop arg2_expr
CDR R11, R11
CAR R5, R11                                 ; pop retaddr
CDR R11, R11
CONS R11, R5, R11
CONS R11, R6, R11                             ; keep arg1 value alive across arg2's eval
MOV R3, R10                                     ; eval(arg2_expr, env)
CALL R5, eval
CAR R6, R11                                       ; pop arg1 value
CDR R11, R11
CAR R5, R11                                         ; pop retaddr
CDR R11, R11
CONS R9, R6, R9                                       ; apply hardware CONS
JMP done
prim_fallback:
CAR R10, R11                ; pop arg2_expr (discard, keep stack balanced)
CDR R11, R11
LOADSYM R6, 92
LOADSYM R7, 93
EQ R9, R6, R7                ; unrecognized primitive -> NIL
JMP done
do_closure_apply:
CAR R10, R11                  ; pop arg2_expr (discard; single-param closures never use it)
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
