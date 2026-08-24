; gen-symbol-table.my v0.1 — pure transformation, McCarthy primitives only.
; Python does file I/O; this transforms extracted LOADSYM (id . name) pairs.

(def cadr  (lambda (x) (car (cdr x))))
(def caddr (lambda (x) (car (cdr (cdr x)))))
(def nullq (lambda (x) (atom x)))

; ---- add-entry: alist insert with last-wins conflict resolution ----
(def add-entry (lambda (table id name)
  (cond ((nullq table) (cons (cons id name) ()))
        ((eq (car (car table)) id)
         (cond ((eq (cdr (car table)) name) table)
               (t (cons (cons id name) (cdr table)))))
        (t (cons (car table) (add-entry (cdr table) id name))))))

(def build-table (lambda (pairs)
  (cond ((nullq pairs) ())
        (t (add-entry (build-table (cdr pairs))
                       (car (car pairs))
                       (cdr (car pairs)))))))

; ---- demo ----
(def demo-input
  (cons (cons 50 (quote quote))
  (cons (cons 80 (quote cond))
  (cons (cons 900 (quote first))
  (cons (cons 901 (quote second))
  (cons (cons 902 (quote third))
        ()))))))

(build-table demo-input)
