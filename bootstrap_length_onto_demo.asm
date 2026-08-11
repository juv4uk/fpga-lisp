; M29 (WIP): canonical core.my `length`, bootstrapped as the real
; tail-recursive, mutually-recursive pair -- the follow-up M28 deferred
; (bootstrap_length_demo.asm's header; confirmed against my-lisp's
; lib/core.my on 2026-08-11):
;   (def length-onto (lambda (values acc)
;                       (cond ((atom values) acc)
;                             (t (length-onto (cdr values) (add acc 1))))))
;   (def length (lambda (values) (length-onto values 0)))
; (Canonical core.my writes `(+ acc 1)`; this machine only has 'add bound
; as a hardware primitive, so `+` is spelled `add` here -- same operation.)
;
; Two letrec placeholders instead of M28's one: ph_onto = (length-onto . NIL)
; and ph_length = (length . NIL) are both CONS'd into the same env frame
; (new_env) before either closure is built, so both closures close over an
; env that already contains both placeholders. length-onto's closure is
; built and backpatched first (SETCDR ph_onto's cdr -> closure_onto), then
; length's closure is built and backpatched the same way. Because closures
; capture new_env by reference (not by copy), length's body can call
; 'length-onto and find the now-backpatched closure, and length-onto's own
; body can find itself the same way M28's length did -- two independent
; ph_pair -> closure -> new_env -> ph_pair cycles sharing one frame.
;
; Unlike M28's single-symbol parameter, length-onto takes two parameters
; (values acc) -- exercises eval_core.inc's closure_nary binding loop
; (M22/M24) instead of the single-bare-symbol path, for the first time in
; a bootstrap demo.
;
; (length '(a b c)) => 3 (fixnum), this time via three tail calls to
; length-onto (each one replacing, not growing, the caller's stack depth)
; rather than three nested `(add 1 (length ...))` frames.
;
; STATUS: WIP, NOT YET RUN IN SIMULATION on this machine (no Python/
; assembler.py or iverilog/vvp available here -- same blocker noted in
; bootstrap_length_demo.asm). Hand-traced against eval_core.inc's dispatch
; but unverified. Run the regression below before trusting it:
;   python assembler.py bootstrap_length_onto_demo.asm
;   iverilog -g2012 -I fpga/rtl -o tb.vvp fpga/rtl/lisp_word.sv fpga/rtl/heap.sv \
;     fpga/rtl/lisp_data_unit.sv fpga/rtl/registers.sv fpga/rtl/instruction_decoder.sv \
;     fpga/rtl/control.sv fpga/rtl/uart.sv fpga/rtl/bootloader.sv fpga/rtl/lisp_machine.sv \
;     fpga/sim/tb_bootstrap_length_onto.sv
;   vvp tb.vvp

.include "fpga/asm/constants.inc"

; --- NIL (only for use as list terminator while building; R11's own
;     init is redone from scratch just before the top-level eval call,
;     since R6 gets repurposed for test-list data below) ---
LOADSYM R1, 900
LOADSYM R2, 901
EQ R6, R1, R2             ; R6 = NIL

; --- base_env: 'cdr, 'add, 'atom bound to their hardware primitives ---
LOADI R1, PRIM_CDR
MAKEPRIM R1, R1
LOADSYM R2, 910              ; 'cdr
CONS R2, R2, R1
CONS R7, R2, R6                ; env0 = (pair_cdr)

LOADI R1, PRIM_ADD
MAKEPRIM R1, R1
LOADSYM R2, 911                 ; 'add
CONS R2, R2, R1
CONS R7, R2, R7                   ; env1 = (pair_add . env0)

LOADI R1, PRIM_ATOM
MAKEPRIM R1, R1
LOADSYM R2, 912                    ; 'atom
CONS R2, R2, R1
CONS R7, R2, R7                      ; base_env = (pair_atom . env1)

; --- letrec: two placeholders, both extending the same frame, before
;     either closure is built ---
LOADSYM R0, 914                        ; 'length-onto
CONS R8, R0, R6                          ; ph_onto = (length-onto . NIL)   [R8 kept live until its SETCDR]
CONS R7, R8, R7                            ; env += ph_onto

LOADSYM R0, 913                            ; 'length
CONS R9, R0, R6                              ; ph_length = (length . NIL)   [R9 kept live until its SETCDR]
CONS R7, R9, R7                                ; new_env = (ph_length . (ph_onto . base_env))   [R7 kept live: both closures' captured env]

; ============================================================
; closure_onto: (lambda (values acc) (cond ((atom values) acc)
;                                           (t (length-onto (cdr values) (add acc 1)))))
; ============================================================

; --- params_onto = (values acc) ---
LOADSYM R0, 921                                  ; 'values   [R0 kept live through this closure's build]
LOADSYM R10, 922                                   ; 'acc   [R10 kept live through this closure's build]
CONS R1, R10, R6                                     ; (acc)
CONS R1, R0, R1                                        ; params_onto = (values acc)   [R1 kept live]

; --- test1 = (atom values) ---
CONS R2, R0, R6                                          ; (values)
LOADSYM R3, 912                                            ; 'atom
CONS R2, R3, R2                                              ; test1 = (atom values)   [R2 kept live]

; --- clause1 = (test1 acc) -- value1 is the bare symbol 'acc ---
CONS R3, R10, R6                                              ; (acc)
CONS R2, R2, R3                                                ; clause1 = (test1 (acc)) = (test1 value1)   [R2 kept live]

; --- test2 = TRUE ---
EQ R4, R0, R0                                                  ; [R4 kept live]

; --- value2 = (length-onto (cdr values) (add acc 1)) ---
LOADSYM R3, 910                                                ; 'cdr
CONS R5, R0, R6                                                ; (values)
CONS R5, R3, R5                                                  ; cdr_expr = (cdr values)   [R5 kept live]

LOADI R3, 1
CONS R12, R3, R6                                                  ; (1)
CONS R12, R10, R12                                                  ; (acc 1)
LOADSYM R3, 911                                                       ; 'add
CONS R12, R3, R12                                                       ; add_expr = (add acc 1)   [R12 kept live]

CONS R13, R12, R6                                                        ; (add_expr)
CONS R13, R5, R13                                                          ; (cdr_expr add_expr)
LOADSYM R3, 914                                                              ; 'length-onto
CONS R13, R3, R13                                                              ; value2 = (length-onto cdr_expr add_expr)   [R13 kept live]

; --- clause2 = (test2 value2) ---
CONS R14, R13, R6                                                                ; (value2)
CONS R14, R4, R14                                                                  ; clause2 = (test2 value2)   [R14 kept live]

; --- clauses = (clause1 clause2); body_onto = (cond clause1 clause2) ---
CONS R14, R14, R6                                                                    ; (clause2)
CONS R14, R2, R14                                                                      ; (clause1 clause2)
LOADSYM R3, SYM_COND
CONS R14, R3, R14                                                                        ; body_onto = (cond clause1 clause2)   [R14 kept live]

; --- closure_onto = (params_onto . (body_onto . new_env)); backpatch ph_onto ---
CONS R15, R14, R7                                                                          ; rest = (body_onto . new_env)
CONS R15, R1, R15                                                                            ; closure_onto = (params_onto . rest)
SETCDR R0, R8, R15                                                                            ; ph_onto's cdr: NIL -> closure_onto

; ============================================================
; closure_length: (lambda (values) (length-onto values 0))
; ============================================================

LOADSYM R0, 921                ; params = 'values (bare symbol, single param -- same name as
                                ; length-onto's first param, but each closure captures its own
                                ; scope, so this does NOT alias length-onto's 'values binding)

LOADSYM R2, 914                  ; 'length-onto
LOADI R3, 0
CONS R4, R3, R6                    ; (0)
CONS R4, R0, R4                      ; (values 0)
CONS R4, R2, R4                        ; body_length = (length-onto values 0)   [R4 kept live]

; --- closure_length = (params . (body_length . new_env)); backpatch ph_length ---
CONS R5, R4, R7                          ; rest = (body_length . new_env)
CONS R5, R0, R5                            ; closure_length = (values . rest)
SETCDR R1, R9, R5                            ; ph_length's cdr: NIL -> closure_length

; --- test data: (a b c) --- (R6/NIL's job as list terminator is done; safe to reuse)
LOADSYM R1, 930
LOADSYM R2, 931
LOADSYM R3, 932
CONS R6, R3, R6              ; (c)
CONS R6, R2, R6              ; (b c)
CONS R6, R1, R6              ; (a b c)

; --- wrap in (quote (a b c)): call arguments are evaluated, so the bare list
;     would itself be eval'd as code (apply 'a to (b c)) -- see
;     bootstrap_length_demo.asm's header for the full postmortem of this
;     exact mistake in M28's first version. ---
LOADSYM R2, 900
LOADSYM R3, 901
EQ R2, R2, R3                  ; fresh NIL
CONS R2, R6, R2                  ; ((a b c))
LOADSYM R1, SYM_QUOTE
CONS R6, R1, R2                    ; q_list = (quote (a b c))

; --- expr = (length (quote (a b c))) ---
LOADSYM R1, 913
LOADSYM R2, 900
LOADSYM R3, 901
EQ R2, R2, R3                  ; fresh NIL for the args-list tail
CONS R2, R6, R2                  ; ((quote (a b c)))
CONS R3, R1, R2                    ; expr = (length (quote (a b c)))
MOV R4, R7                           ; env = new_env (both 'length and 'length-onto now resolve
                                      ; via their backpatched placeholders)

; --- re-derive NIL fresh for the software call stack init: R6 has been
;     repurposed as test-list data above, so this can't reuse it ---
LOADSYM R10, 900
LOADSYM R12, 901
EQ R11, R10, R12                       ; R11 = NIL (software call stack, untouched until eval runs)

CALL R5, eval

HALT                       ; R9 should hold FIXNUM 3

.include "fpga/asm/eval_core.inc"
