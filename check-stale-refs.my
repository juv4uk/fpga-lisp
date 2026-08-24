; Self-hosted counterpart of check_stale_refs.py.
; Machine-readable contract forms are authoritative; prose is only checked
; for claims that explicitly mention a contract version.

(load "docs/reference/my-lisp-lib/core.my")

(def find-field
  (lambda (name tree)
    (cond
      ((atom tree) ())
      ((atom (car tree))
       (cond
         ((eq (car tree) name) (cdr tree))
         (t (find-field name (cdr tree)))))
      (t (let ((inside (find-field name (car tree))))
           (cond (inside inside) (t (find-field name (cdr tree)))))))))

(def read-field
  (lambda (path name)
    (find-field name (read-all (read-file path)))))

(def version-text
  (lambda (major minor)
    (string-append (number->string major)
      (string-append "." (number->string minor)))))

(def split-lines-onto
  (lambda (s cur acc)
    (cond
      ((string-empty? s) (cons cur acc))
      ((eq (string-first s) "\n")
       (split-lines-onto (string-rest s) "" (cons cur acc)))
      (t (split-lines-onto (string-rest s)
           (string-append cur (string-first s)) acc)))))

(def split-lines
  (lambda (s) (reverse (split-lines-onto s "" (quote ())))))

(def check-prose-onto
  (lambda (lines marker expected path)
    (cond
      ((atom lines) t)
      ((string-contains? marker (car lines))
       (cond
         ((string-contains? "version" (car lines))
          (let ((matches (string-contains? expected (car lines))))
            (let ((_ (cond
                       (matches
                        (print (string-append "OK: "
                                 (string-append path
                                   (string-append " claim matches " expected)))))
                       (t (print (string-append "DRIFT: "
                                  (string-append path
                                    (string-append " claim disagrees with " expected))))))))
              (let ((rest (check-prose-onto (cdr lines) marker expected path)))
                (cond (matches rest) (t (quote ())))))))
         (t (check-prose-onto (cdr lines) marker expected path))))
      (t (check-prose-onto (cdr lines) marker expected path)))))

(def check-prose
  (lambda (path marker expected)
    (check-prose-onto (split-lines (read-file path)) marker expected path)))

(def fail-stale
  (lambda (ok message)
    (cond
      (ok t)
      (t (let ((_ (print message)))
           ; Deliberately raise the contract's named arithmetic failure so a
           ; stale reference cannot be mistaken for a successful run.
           (quotient 1 0))))))

; Contract 1.1 stores (version . (1 1)); language-contract stores
; (major . 3) and (minor . 0). The two checks intentionally remain separate.
(let ((isa (read-field "isa-contract.my" (string->symbol "version"))))
  (cond
    ((atom isa) (print "MISSING: isa-contract.my version"))
    (t (let ((expected (version-text (car isa) (second isa))))
           (let ((readme (check-prose "README.md" "isa-contract.my`, version" expected)))
           (let ((agents (check-prose "AGENTS.md" "isa-contract.my`, version" expected)))
             (cond (readme (fail-stale agents "stale isa contract reference"))
                   (t (fail-stale () "stale isa contract reference")))))))))
(let ((language (read-all (read-file "../my-lisp/language-contract.my"))))
  (let ((major (find-field (string->symbol "major") language)))
    (let ((minor (find-field (string->symbol "minor") language)))
      (let ((expected (version-text major minor)))
        (let ((readme (check-prose "README.md" "Language contract version" expected)))
          (let ((agents (check-prose "AGENTS.md" "Language contract version" expected)))
            (cond (readme (fail-stale agents "stale language contract reference"))
                  (t (fail-stale () "stale language contract reference")))))))))
(quote ())
