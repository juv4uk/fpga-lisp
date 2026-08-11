; M28: letrec via SETCDR backpatch -- the first self-referential closure.
;
; NOT canonical core.my `length` -- deliberately simplified to prove the
; letrec mechanism itself, not full parity with the reference implementation.
; The canonical form (my-lisp's lib/core.my, confirmed 2026-08-11) is
; tail-recursive through a length-onto accumulator, and mutually recursive
; between two functions:
;   (def length-onto (lambda (values acc)
;                       (cond ((atom values) acc)
;                             (t (length-onto (cdr values) (+ acc 1))))))
;   (def length (lambda (values) (length-onto values 0)))
; This demo instead uses the simpler, NON-tail-recursive single-function form:
;   (def length (lambda (lst) (cond ((atom lst) 0)
;                                    (t (add 1 (length (cdr lst)))))))
; Both give the same result for short lists (confirmed against
; tests/fixtures/conformance.my fixture #37: (length '(radio antenna signal))
; => 3), but this form grows call-stack depth with list length; the
; canonical -onto form does not. Bootstrapping the canonical tail-recursive,
; mutually-recursive form (two letrec-bound closures referencing each other)
; is follow-up work, not yet done here.
;
; The mechanism the plan settled on (docs/lisp-machine-plan.md, GC section,
; 2026-08-10, confirmed with the my-lisp session): a placeholder pair
; (name . NIL) is CONS'd into a fresh env frame, a closure is built
; capturing that same frame, then SETCDR backpatches the placeholder's cdr
; from NIL to the closure -- producing a deliberate cycle
; (ph_pair -> closure -> new_env -> ph_pair) so the body's own `lookup` of
; 'length finds the closure it is itself running inside. This is exactly
; the cycle M26/SETCDR's rationale predicted, and the reason a future GC
; must be trace-based, never refcounting.
;
; (length '(a b c)) => 3 (fixnum), through three self-recursive eval calls.
;
; NOT YET RUN IN SIMULATION on this machine (no iverilog/vvp available in
; this environment) -- verified only by hand-tracing every register through
; eval_core.inc's dispatch. Run the M28 regression below before trusting it:
;   python assembler.py bootstrap_length_demo.asm
;   iverilog -g2012 -I fpga/rtl -o tb.vvp fpga/rtl/lisp_word.sv fpga/rtl/heap.sv \
;     fpga/rtl/lisp_data_unit.sv fpga/rtl/registers.sv fpga/rtl/instruction_decoder.sv \
;     fpga/rtl/control.sv fpga/rtl/uart.sv fpga/rtl/bootloader.sv fpga/rtl/lisp_machine.sv \
;     fpga/sim/tb_bootstrap_length.sv
;   vvp tb.vvp

.include "fpga/asm/constants.inc"

; --- NIL and software call-stack init ---
LOADSYM R1, 900
LOADSYM R2, 901
EQ R6, R1, R2            ; R6 = NIL (list terminator through body/closure construction)
MOV R11, R6                ; R11 = NIL (software call stack, untouched until eval runs)

; --- base_env: 'cdr, 'add, 'atom bound to their hardware primitives ---
LOADI R1, PRIM_CDR
MAKEPRIM R1, R1
LOADSYM R2, 910             ; 'cdr
CONS R2, R2, R1               ; (cdr . PRIM_CDR)
CONS R7, R2, R6                 ; env0 = (pair_cdr)

LOADI R1, PRIM_ADD
MAKEPRIM R1, R1
LOADSYM R2, 911               ; 'add
CONS R2, R2, R1                 ; (add . PRIM_ADD)
CONS R7, R2, R7                   ; env1 = (pair_add . env0)

LOADI R1, PRIM_ATOM
MAKEPRIM R1, R1
LOADSYM R2, 912                  ; 'atom
CONS R2, R2, R1                    ; (atom . PRIM_ATOM)
CONS R7, R2, R7                      ; base_env = (pair_atom . env1)   [R7 kept live: grows into new_env below]

; --- letrec: placeholder pair for 'length, extend env with it ---
LOADSYM R0, 913                        ; 'length
CONS R8, R0, R6                          ; ph_pair = (length . NIL)   [R8 kept live for the SETCDR below]
CONS R7, R8, R7                            ; new_env = (ph_pair . base_env)   [R7 kept live: closure's captured env]

LOADSYM R0, 920                              ; params = 'lst   [R0 kept live through closure construction]

; --- test1 = (atom lst) ---
CONS R1, R0, R6                                ; (lst)
LOADSYM R2, 912                                  ; 'atom
CONS R1, R2, R1                                    ; test1 = (atom lst)   [R1 kept live]

; --- value1 = 0 (self-evaluating fixnum leaf) ---
LOADI R2, 0

; --- clause1 = (test1 value1) ---
CONS R2, R2, R6                                      ; (value1)
CONS R1, R1, R2                                        ; clause1 = (test1 value1)   [R1 kept live]

; --- test2 = TRUE (any word EQ'd against itself; not a symbol lookup) ---
EQ R10, R0, R0                                           ; [R10 kept live]

; --- value2 = (add 1 (length (cdr lst))) ---
LOADSYM R2, 910                                            ; 'cdr
CONS R3, R0, R6                                              ; (lst)
CONS R3, R2, R3                                                ; (cdr lst)
CONS R3, R3, R6                                                  ; ((cdr lst))
LOADSYM R2, 913                                                    ; 'length
CONS R3, R2, R3                                                      ; len_call = (length (cdr lst))
CONS R3, R3, R6                                                        ; (len_call)
LOADI R2, 1
CONS R3, R2, R3                                                          ; (1 len_call)
LOADSYM R2, 911                                                            ; 'add
CONS R3, R2, R3                                                             ; value2 = (add 1 len_call)   [R3 kept live]

; --- clause2 = (test2 value2) ---
CONS R3, R3, R6                                                               ; (value2)
CONS R3, R10, R3                                                                ; clause2 = (TRUE value2)   [R3 kept live]

; --- clauses = (clause1 clause2); body = (cond clause1 clause2) ---
CONS R3, R3, R6                                                                   ; (clause2)
CONS R3, R1, R3                                                                     ; (clause1 clause2)
LOADSYM R2, SYM_COND
CONS R3, R2, R3                                                                       ; body = (cond clause1 clause2)   [R3 kept live]

; --- closure = (lst . (body . new_env)); backpatch the placeholder ---
CONS R4, R3, R7                                                                         ; rest = (body . new_env)
CONS R4, R0, R4                                                                           ; length_closure = (lst . rest)
SETCDR R1, R8, R4                                                                           ; ph_pair's cdr: NIL -> closure

; --- test data: (a b c) --- (R6/NIL's job as list terminator is done; safe to reuse)
LOADSYM R1, 930
LOADSYM R2, 931
LOADSYM R3, 932
CONS R6, R3, R6              ; (c)
CONS R6, R2, R6              ; (b c)
CONS R6, R1, R6              ; (a b c)

; --- expr = (length (a b c)) ---
LOADSYM R1, 913
LOADSYM R2, 900
LOADSYM R3, 901
EQ R2, R2, R3                  ; fresh NIL for the args-list tail
CONS R2, R6, R2                  ; ((a b c))
CONS R3, R1, R2                    ; expr = (length (a b c))
MOV R4, R7                           ; env = new_env (where 'length now resolves via the backpatched ph_pair)
CALL R5, eval

HALT                       ; R9 should hold FIXNUM 3

.include "fpga/asm/eval_core.inc"
