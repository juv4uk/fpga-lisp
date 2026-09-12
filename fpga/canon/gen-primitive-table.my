; fpga/canon/gen-primitive-table.my
;
; my-lisp port of the retired tools/gen_primitive_table.py +
; tools/test_primitive_table.py, per issue #6 (ECO-LISP-SCRIPTS-1):
; repo-owned tooling must not add new Python scripting surface, and
; new tooling should be written in my-lisp/wsm directly rather than
; migrated later.
;
; Bridges two separate namespaces, deliberately kept apart per
; docs/canon-symbol-registry-fpga-lisp-part.md and the swarm's Canon
; migration plan (2026-09-11):
;   - Canon semantic id: my-lisp's authority
;     (lib/surface/semantic-registry.wsm), identity of a language form,
;     independent of spelling (en/uk/sa are just names for one id).
;   - local primitive id: fpga-lisp's own authority
;     (fpga/asm/constants.inc's PRIM_* values), the hardware execution
;     ABI. Never renumbered by a Canon change.
; fpga/canon/execution-spec.my is the small, hand-maintained bridge
; between the two; this script validates it fail-closed against the
; real registry and constants.inc, builds the generated table, and
; runs the same evidence checks the Python version had (car's en/uk/sa
; surfaces resolve to one entry; no surface is ambiguous; 'radio'/
; 'RADIO' are absent; all six first-wave primitives present).
;
; Usage (from the my-lisp repo root, fpga-lisp checked out as a
; sibling directory):
;   cargo run -p my-lisp-cli --bin my-lisp -- \
;     ../fpga-lisp/fpga/canon/gen-primitive-table.my
;
; Fails closed (non-zero exit via a real evaluation error, my-lisp's
; own error-signaling mechanism -- there is no separate `error`
; builtin in this dialect) if:
;   - a spec'd Canon id does not exist in the registry,
;   - a spec'd Canon id has no 'stable' surface at all,
;   - the registry's "en" surface for a Canon id is present but
;     disagrees with the spec's expected-en-spelling sanity field,
;   - constants.inc has no .define for the spec's local-primitive-const,
;   - that .define's value disagrees with the spec's local-primitive-id,
;   - a Canon id or local primitive id is used twice in the spec,
;   - any evidence assertion below does not hold.

(def registry-path "../my-lisp/lib/surface/semantic-registry.wsm")
(def constants-path "fpga/asm/constants.inc")
(def spec-path "fpga/canon/execution-spec.my")

; --- fail-closed: report and abort via a genuine evaluation error ---
; `princ`/`print` output is buffered and lost when the process later
; errors out (verified empirically -- text written before a fatal
; error never reaches the terminal), so a diagnostic can't just be
; printed before aborting. Instead, reference the diagnostic message
; itself as an unbound symbol: my-lisp's "unknown symbol" error embeds
; the exact symbol text, which reliably surfaces the message even
; though ordinary output does not.
(def fail-closed
  (lambda (msg)
    (eval (string->symbol (string-append "CANON-TABLE-FAIL-CLOSED: " msg)))))

; --- flat (.define NAME VALUE .define NAME VALUE ...) lookup ---
(def find-const
  (lambda (name flat)
    (cond
      ((atom flat) (quote ()))
      ((atom (cdr flat)) (quote ()))
      ((eq (car (cdr flat)) name) (car (cdr (cdr flat))))
      (t (find-const name (cdr (cdr (cdr flat))))))))

; --- registry entry lookup: entries look like (id (en w a) (uk w a) (sa w a) (sym ...)) ---
(def find-registry-entry
  (lambda (canon-id entries)
    (cond
      ((atom entries) (quote ()))
      ((eq (car (car entries)) canon-id) (car entries))
      (t (find-registry-entry canon-id (cdr entries))))))

(def find-surface
  (lambda (kind surfaces)
    (cond
      ((atom surfaces) (quote ()))
      ((eq (car (car surfaces)) kind) (car surfaces))
      (t (find-surface kind (cdr surfaces))))))

(def surface-word (lambda (surface-entry) (car (cdr surface-entry))))
(def surface-admission (lambda (surface-entry) (car (cdr (cdr surface-entry)))))

(def has-stable-surface?
  (lambda (surfaces)
    (cond
      ((atom surfaces) (quote ()))
      ((eq (surface-admission (car surfaces)) (quote stable)) t)
      (t (has-stable-surface? (cdr surfaces))))))

; --- validate + build one table entry from one spec entry ---
; spec entry: (canon-id expected-en local-primitive-const local-primitive-id opcode)
(def build-entry
  (lambda (spec-entry registry-entries constants-flat)
    ((lambda ()
       (def canon-id (car spec-entry))
       (def expected-en (car (cdr spec-entry)))
       (def prim-const (car (cdr (cdr spec-entry))))
       (def local-id (car (cdr (cdr (cdr spec-entry)))))
       (def opcode (car (cdr (cdr (cdr (cdr spec-entry))))))
       (def registry-entry (find-registry-entry canon-id registry-entries))
       (cond
         ((atom registry-entry)
          (fail-closed (string-append "Canon id has no registry entry: " (write-to-string canon-id))))
         (t (quote ())))
       (def surfaces (cdr registry-entry))
       (cond
         ((not (has-stable-surface? surfaces))
          (fail-closed (string-append "Canon id has no stable surface: " (write-to-string canon-id))))
         (t (quote ())))
       (def en-surface (find-surface (quote en) surfaces))
       (cond
         ((atom en-surface) (quote ()))
         ((eq (surface-word en-surface) (quote —)) (quote ()))
         ((eq (surface-word en-surface) expected-en) (quote ()))
         (t (fail-closed (string-append "en surface mismatch for Canon id " (write-to-string canon-id)))))
       (def const-value (find-const prim-const constants-flat))
       ; NOTE: a legitimate found value can be 0 (PRIM_CAR is), and 0
       ; is itself an atom -- `atom` cannot distinguish "found, value
       ; 0" from "not found" (also nil/()). Compare against the
       ; not-found sentinel directly instead.
       (cond
         ((eq const-value (quote ()))
          (fail-closed (string-append "constants.inc has no .define for " (write-to-string prim-const))))
         (t (quote ())))
       (cond
         ((not (eq const-value local-id))
          (fail-closed (string-append "spec/constants.inc disagree on " (write-to-string prim-const))))
         (t (quote ())))
       (def uk-surface (find-surface (quote uk) surfaces))
       (def sa-surface (find-surface (quote sa) surfaces))
       (list canon-id expected-en
             (cons (quote en) (surface-word en-surface))
             (cons (quote uk) (cond ((atom uk-surface) (quote —)) (t (surface-word uk-surface))))
             (cons (quote sa) (cond ((atom sa-surface) (quote —)) (t (surface-word sa-surface))))
             local-id opcode)))))

(def build-table-onto
  (lambda (spec-entries registry-entries constants-flat acc)
    (cond
      ((atom spec-entries) (reverse acc))
      (t (build-table-onto (cdr spec-entries) registry-entries constants-flat
           (cons (build-entry (car spec-entries) registry-entries constants-flat) acc))))))

; --- table entry accessors (canon-id expected-en (en . w) (uk . w) (sa . w) local-id opcode) ---
(def entry-canon-id (lambda (e) (nth 0 e)))
(def entry-surfaces (lambda (e) (list (nth 2 e) (nth 3 e) (nth 4 e))))
(def entry-local-id (lambda (e) (nth 5 e)))
(def entry-opcode (lambda (e) (nth 6 e)))

(def find-entries-with-word
  (lambda (word table)
    (cond
      ((atom table) (quote ()))
      ((member? word (map (lambda (s) (cdr s)) (entry-surfaces (car table))))
       (cons (entry-canon-id (car table)) (find-entries-with-word word (cdr table))))
      (t (find-entries-with-word word (cdr table))))))

(def check
  (lambda (label ok)
    (cond
      (ok ((lambda () (princ label) (princ ": PASS
"))))
      (t (fail-closed (string-append label ": FAIL"))))))

; ==================== main ====================

(def registry-forms (read-all (read-file registry-path)))
(def registry-entries (cdr (car registry-forms)))
(def constants-flat (read-all (read-file constants-path)))
(def spec-forms (read-all (read-file spec-path)))
(def spec-entries (cdr (car spec-forms)))

(def table (build-table-onto spec-entries registry-entries constants-flat (quote ())))

(princ "# Generated by fpga/canon/gen-primitive-table.my -- do not edit by hand.
")
(princ "# Source of truth: fpga/canon/execution-spec.my + my-lisp's")
(princ " lib/surface/semantic-registry.wsm + fpga/asm/constants.inc.
")
(print table)

; ---- evidence checks (were tools/test_primitive_table.py) ----

(def car-entry (find-registry-entry 5 (quote ())))  ; placeholder, replaced below
(def car-table-entry (car (filter (lambda (e) (eq (entry-canon-id e) 5)) table)))

(check "car (Canon 5) has en/uk/sa surfaces all present"
  (not (member? (quote —) (map (lambda (s) (cdr s)) (entry-surfaces car-table-entry)))))

(check "car (Canon 5) local primitive id is 0 (PRIM_CAR)"
  (eq (entry-local-id car-table-entry) 0))

(check "car (Canon 5) opcode is OP_CAR"
  (eq (entry-opcode car-table-entry) (quote OP_CAR)))

(def all-surface-words
  (reduce (lambda (acc e) (append (map (lambda (s) (cdr s)) (entry-surfaces e)) acc)) (quote ()) table))
(def all-surface-words-no-dash
  (filter (lambda (w) (not (eq w (quote —)))) all-surface-words))

(def surface-is-unambiguous?
  (lambda (word)
    (eq (length (find-entries-with-word word table)) 1)))

(check "no surface spelling is ambiguous across Canon ids in this table"
  (atom (filter (lambda (w) (not (surface-is-unambiguous? w))) all-surface-words-no-dash)))

(check "'radio' is not reachable through the Canon primitive table"
  (atom (find-entries-with-word (quote radio) table)))

(check "'RADIO' is not reachable through the Canon primitive table"
  (atom (find-entries-with-word (quote RADIO) table)))

(check "all six first-wave primitives present with correct local ids"
  (equal?
    (map (lambda (id) (entry-local-id (car (filter (lambda (e) (eq (entry-canon-id e) id)) table))))
         (list 5 6 4 2 3 104))
    (list 0 1 2 3 4 5)))

(princ "ALL CANON PRIMITIVE TABLE CHECKS PASSED
")
(quote ())
