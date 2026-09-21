; fpga/canon/gen-primitive-table.lisp
;
; #19 FPGA-SID8-1
;
; Mechanical consumer of two different authorities:
;   - my-lisp owns the exact Canon SID and its presentation surfaces;
;   - fpga-lisp owns the local PRIM_* execution mechanism IDs.
;
; This script joins those facts. It does not mint a language identity and it
; never derives one from a decimal number, local primitive ID, opcode, or
; surface spelling.
;
; Run from the fpga-lisp repository root with a sibling ../my-lisp checkout:
;
;   my-lisp fpga/canon/gen-primitive-table.lisp
;
; Required inputs:
;   ../my-lisp/lib/surface/semantic-registry.lisp
;   fpga/canon/execution-spec.lisp
;   fpga/asm/constants.inc
;
; The execution spec begins with (binary 8), so pre-#1098 readers still parse
; each exact eight-bit Canon spelling as a SID. Current my-lisp readers reserve
; the same eight-bit spellings directly.

(def registry-path "../my-lisp/lib/surface/semantic-registry.lisp")
(def constants-path "fpga/asm/constants.inc")
(def spec-path "fpga/canon/execution-spec.lisp")

(def fail-closed
  (lambda (msg)
    (eval (string->symbol (string-append "FPGA-SID8-FAIL-CLOSED: " msg)))))

; ----- small explicit relation helpers: no generic truthiness -----

(def identity-same-state
  (lambda (left right)
    (cond
      ((eq left right) (identity-relation same) (quote yes))
      ((eq left right) (identity-relation distinct) (quote no)))))

(def structural-same-state
  (lambda (left right)
    (cond
      ((equal? left right) (structural-relation same) (quote yes))
      ((equal? left right) (structural-relation distinct) (quote no)))))

(def check-state
  (lambda (label state)
    (cond
      ((eq state (quote yes)) (identity-relation same)
       ((lambda ()
          (princ label)
          (princ ": PASS
"))))
      ((eq state (quote yes)) (identity-relation distinct)
       (fail-closed (string-append label ": FAIL"))))))

; ----- flat .define NAME VALUE lookup -----

(def find-const
  (lambda (name flat)
    (cond
      ((atom flat) (structural-kind empty-list) (quote ()))
      ((atom flat) (structural-kind pair)
       (cond
         ((eq (second flat) name) (identity-relation same) (third flat))
         ((eq (second flat) name) (identity-relation distinct)
          (find-const name (cdr (cdr (cdr flat))))))))))

; ----- current upstream registry shape -----
;
; (binary 8)
; (00000101 (en car) (ук перше) (укр перше) (sa ādi) (sym :п))
;
; The binary spelling is identity. Surfaces are presentation only.

(def find-registry-entry
  (lambda (canon-sid entries)
    (cond
      ((atom entries) (structural-kind empty-list) (quote ()))
      ((atom entries) (structural-kind atom) (quote ()))
      ((atom entries) (structural-kind pair)
       (let ((entry (car entries)))
         (cond
           ((eq (car entry) canon-sid) (identity-relation same) entry)
           ((eq (car entry) canon-sid) (identity-relation distinct)
            (find-registry-entry canon-sid (cdr entries)))))))))

(def find-surface-row
  (lambda (namespace surfaces)
    (cond
      ((atom surfaces) (structural-kind empty-list) (quote ()))
      ((atom surfaces) (structural-kind atom) (quote ()))
      ((atom surfaces) (structural-kind pair)
       (let ((surface (car surfaces)))
         (cond
           ((eq (car surface) namespace) (identity-relation same) surface)
           ((eq (car surface) namespace) (identity-relation distinct)
            (find-surface-row namespace (cdr surfaces)))))))))

(def surface-word
  (lambda (surface-row)
    (cond
      ((atom surface-row) (structural-kind empty-list) (quote ()))
      ((atom surface-row) (structural-kind atom) (quote ()))
      ((atom surface-row) (structural-kind pair) (second surface-row)))))

(def presented-word
  (lambda (namespace surfaces)
    (let ((word (surface-word (find-surface-row namespace surfaces))))
      (cond
        ((atom word) (structural-kind empty-list) (quote —))
        ((atom word) (structural-kind atom) word)
        ((atom word) (structural-kind pair) word)))))

(def surfaces-have-word-state
  (lambda (expected surfaces)
    (cond
      ((atom surfaces) (structural-kind empty-list) (quote no))
      ((atom surfaces) (structural-kind atom) (quote no))
      ((atom surfaces) (structural-kind pair)
       (let ((candidate (surface-word (car surfaces))))
         (cond
           ((equal? candidate expected) (structural-relation same) (quote yes))
           ((equal? candidate expected) (structural-relation distinct)
            (surfaces-have-word-state expected (cdr surfaces)))))))))

; ----- generated table entry -----
;
; (canon-sid expected-surface
;   (en . word) (ук . word) (sa . word)
;   local-primitive-id opcode)

(def entry-canon-sid (lambda (entry) (nth 0 entry)))
(def entry-local-id (lambda (entry) (nth 5 entry)))
(def entry-opcode (lambda (entry) (nth 6 entry)))

(def table-has-sid-state
  (lambda (canon-sid table)
    (cond
      ((atom table) (structural-kind empty-list) (quote no))
      ((atom table) (structural-kind atom) (quote no))
      ((atom table) (structural-kind pair)
       (cond
         ((eq (entry-canon-sid (car table)) canon-sid)
          (identity-relation same)
          (quote yes))
         ((eq (entry-canon-sid (car table)) canon-sid)
          (identity-relation distinct)
          (table-has-sid-state canon-sid (cdr table))))))))

(def table-has-local-id-state
  (lambda (local-id table)
    (cond
      ((atom table) (structural-kind empty-list) (quote no))
      ((atom table) (structural-kind atom) (quote no))
      ((atom table) (structural-kind pair)
       (cond
         ((eq (entry-local-id (car table)) local-id)
          (identity-relation same)
          (quote yes))
         ((eq (entry-local-id (car table)) local-id)
          (identity-relation distinct)
          (table-has-local-id-state local-id (cdr table))))))))

(def build-entry
  (lambda (spec-entry registry-entries constants-flat)
    ((lambda ()
       (def canon-sid (nth 0 spec-entry))
       (def expected-surface (nth 1 spec-entry))
       (def primitive-const (nth 2 spec-entry))
       (def local-id (nth 3 spec-entry))
       (def opcode (nth 4 spec-entry))
       (def registry-entry (find-registry-entry canon-sid registry-entries))

       (cond
         ((atom registry-entry) (structural-kind empty-list)
          (fail-closed
            (string-append
              "Canon SID absent upstream: "
              (write-to-string canon-sid))))
         ((atom registry-entry) (structural-kind pair) (quote ())))

       (def surfaces (cdr registry-entry))

       ; The hint is allowed to live in any presentation namespace.
       ; It proves that the spec points at the intended upstream row without
       ; making the spelling itself the identity.
       (cond
         ((eq (surfaces-have-word-state expected-surface surfaces) (quote yes))
          (identity-relation same)
          (quote ()))
         ((eq (surfaces-have-word-state expected-surface surfaces) (quote yes))
          (identity-relation distinct)
          (fail-closed
            (string-append
              "expected surface absent for Canon SID "
              (write-to-string canon-sid)))))

       (def const-value (find-const primitive-const constants-flat))
       (cond
         ((eq const-value (quote ())) (identity-relation same)
          (fail-closed
            (string-append
              "constants.inc has no "
              (write-to-string primitive-const))))
         ((eq const-value (quote ())) (identity-relation distinct) (quote ())))

       (cond
         ((eq const-value local-id) (identity-relation same) (quote ()))
         ((eq const-value local-id) (identity-relation distinct)
          (fail-closed
            (string-append
              "local primitive id drift for "
              (write-to-string primitive-const)))))

       (list
         canon-sid
         expected-surface
         (cons (quote en) (presented-word (quote en) surfaces))
         (cons (quote ук) (presented-word (quote ук) surfaces))
         (cons (quote sa) (presented-word (quote sa) surfaces))
         local-id
         opcode)))))

(def build-table-onto
  (lambda (spec-entries registry-entries constants-flat acc)
    (cond
      ((atom spec-entries) (structural-kind empty-list) (reverse acc))
      ((atom spec-entries) (structural-kind atom)
       (fail-closed "malformed FPGA execution spec"))
      ((atom spec-entries) (structural-kind pair)
       (let ((entry (build-entry (car spec-entries) registry-entries constants-flat)))
         (let ((canon-sid (entry-canon-sid entry))
               (local-id (entry-local-id entry)))
           (cond
             ((eq (table-has-sid-state canon-sid acc) (quote yes))
              (identity-relation same)
              (fail-closed
                (string-append
                  "duplicate Canon SID "
                  (write-to-string canon-sid))))
             ((eq (table-has-sid-state canon-sid acc) (quote yes))
              (identity-relation distinct)
              (cond
                ((eq (table-has-local-id-state local-id acc) (quote yes))
                 (identity-relation same)
                 (fail-closed
                   (string-append
                     "duplicate local primitive id "
                     (write-to-string local-id))))
                ((eq (table-has-local-id-state local-id acc) (quote yes))
                 (identity-relation distinct)
                 (build-table-onto
                   (cdr spec-entries)
                   registry-entries
                   constants-flat
                   (cons entry acc))))))))))))

; ----- load the three inputs -----

(def registry-forms (read-all (read-file registry-path)))
(def registry-form (car registry-forms))

(check-state
  "upstream registry declares exact binary width 8"
  (structural-same-state (car registry-form) (quote (binary 8))))

(def registry-entries (cdr registry-form))
(def constants-flat (read-all (read-file constants-path)))
(def spec-forms (read-all (read-file spec-path)))

(check-state
  "FPGA execution spec declares exact binary width 8"
  (structural-same-state (car spec-forms) (quote (binary 8))))

(def spec-form (second spec-forms))

(check-state
  "FPGA execution spec has expected root"
  (identity-same-state
    (car spec-form)
    (quote fpga-primitive-execution-spec)))

(def spec-entries (cdr spec-form))
(def table
  (build-table-onto
    spec-entries
    registry-entries
    constants-flat
    (quote ())))

; The local mechanism sequence is independent of Canon SID spelling.
(check-state
  "first-wave local primitive mechanism ids remain 0..5"
  (structural-same-state
    (map entry-local-id table)
    (list 0 1 2 3 4 5)))

(princ "# Generated by fpga/canon/gen-primitive-table.lisp -- do not edit by hand.
")
(princ "# Canon identity authority: ../my-lisp/lib/surface/semantic-registry.lisp
")
(princ "# FPGA mechanism authority: fpga/asm/constants.inc
")
(print table)
(princ "ALL FPGA SID8 PROJECTION CHECKS PASSED
")

(quote ())
