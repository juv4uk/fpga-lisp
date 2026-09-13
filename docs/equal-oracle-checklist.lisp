; equal? reference checklist for M32 (bootstrap equal? on hardware).
; Source: my-lisp TCP oracle (strict sexpr), contract 1.0, 2026-08-11.
; Each line: expr -> expected. Hardware equal? must match these.
;
; ATOMS
(equal? (quote a) (quote a))                 -> t
(equal? (quote a) (quote b))                 -> ()
; NUMBERS (exactness matters!)
(equal? 1 1)                   -> t
(equal? 1 2)                   -> ()
(equal? 1 1/1)                 -> ()   ; exact integer != rational, same value
(equal? 1.0 1)                 -> ()   ; float != integer
; STRINGS
(equal? "ab" "ab")             -> t
(equal? "ab" "ac")             -> ()
(equal? "a" (quote a))                -> ()   ; string != symbol
; DOTTED PAIRS
(equal? (quote (1 . 2)) (quote (1 . 2)))     -> t
(equal? (quote (1 . 2)) (quote (1 . 3)))     -> ()
(equal? (quote (1 . 2)) (quote (1 2)))       -> ()   ; dotted pair != proper list, same spine
; PROPER LISTS
(equal? (quote (1 2)) (quote (1 2)))         -> t
(equal? (quote (1 2)) (quote (1 3)))         -> ()
(equal? (quote (1 2)) (quote (1 2 3)))       -> ()   ; length matters
(equal? (quote (a (b c))) (quote (a (b c)))) -> t    ; nested
(equal? (quote (a (b c))) (quote (a (b d)))) -> ()
(equal? (quote (a (b (c)))) (quote (a (b (d))))) -> () ; deep
; NIL
(equal? (quote ()) (quote ()))               -> t
(equal? (quote ()) (quote (())))             -> ()
(equal? (quote ()) (quote nil))              -> ()   ; NIL != symbol nil
; MIXED TYPES
(equal? (quote a) 1)                  -> ()
(equal? (quote (1 2)) (quote (1 . 2)))       -> ()   ; structure differs
; CLOSURES
(equal? (lambda (x) x) (lambda (x) x)) -> () ; identity, not structure (G1)
; BOOLEAN SYMBOLS
(equal? (quote t) (quote t))                 -> t
;
; CYCLES: out of scope -- the language cannot construct self-referential
; cons (no set-car!/set-cdr!/mutation primitives; verified unknown-symbol
; on the oracle). Hardware equal? need not handle cycles.
