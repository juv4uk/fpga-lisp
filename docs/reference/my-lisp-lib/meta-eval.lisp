; Metacircular evaluator: my-eval interprets my-lisp source as Lisp data.
;
; Contract 6.0 ownership boundary:
; the finite Canon 0+7 surface-name set is resolved before the metacircular
; lexical environment and cannot be used by language binders. Callable Canon
; spellings resolve to first-class `(primitive identity)` values; quote/cond
; remain syntax-only. Ordinary non-Canon primitives such as +, -, *, <, =, >
; still live in the metacircular environment model and remain shadowable.
;
; The actual primitive operation is still supplied by the native substrate;
; this evaluator owns name resolution, Canon-first lookup, ordinary lexical
; shadowing, application shape, macro expansion, closure environments, chained
; comparison policy, shared top-level definition-frame visibility, self-recursive
; and dependency-aware finite mutually recursive top-level function binding,
; variadic/dotted lambda parameter binding, and named failure observations for
; unresolved names, non-callable values, lambda/macro arity mismatch, invalid
; lambda-list structure, and reserved Canon binding attempts.
;
; This remains an explicit self-hosting witness, not the always-loaded runtime.
; Full named-error parity is still a known gap and must not be claimed as
; complete self-hosting.

(00001001 my-primitive
  (00001000 (name)
    (00100111 (00000001 primitive) name)))

(00001001 my-error
  (00001000 (kind detail)
    (00100111 (00000001 error) kind detail)))

; Internal evaluator outcomes carry provenance that interpreted Lisp data cannot
; forge. The tag is a native closure identity, not a symbol or list shape that
; a program could reproduce with quote/cons. Public my-eval/my-apply unwrap the
; envelope, so the observable interface stays unchanged.
(00001001 my-result-ok-token
  (00001000 (value) value))

(00001001 my-result-fail-token
  (00001000 (value) value))

(00001001 my-result-ok
  (00001000 (value)
    (00000100 my-result-ok-token value)))

(00001001 my-result-fail
  (00001000 (error)
    (00000100 my-result-fail-token error)))

(00001001 my-result-fail?
  (00001000 (result)
    (00000111
      ((00000010 result) () (00000001 ()))
      ((00000010 result) (1) (00000001 ()))
      (t (00000011 (00000101 result) my-result-fail-token)))))

(00001001 my-result-value
  (00001000 (result)
    (00000110 result)))

; Surface spellings are not owned here. The generated projection loaded before
; this evaluator maps every admitted runtime spelling to the numeric semantic ID
; from lib/surface/semantic-registry.lisp. This file owns only the mapping from
; those opaque IDs to evaluator mechanisms.
(00001001 my-semantic-id?
  (00001000 (name semantic-id)
    (00000111
      ((00100010 name semantic-id) t)
      (t (00100010 (my-semantic-id-for-surface name) semantic-id)))))

(00001001 my-canon-identity
  (00001000 (name)
    (10011100 ((semantic-id (00000111
                         ((00100010 name 00000001) 00000001)
                         ((00100010 name 00000010) 00000010)
                         ((00100010 name 00000011) 00000011)
                         ((00100010 name 00000100) 00000100)
                         ((00100010 name 00000101) 00000101)
                         ((00100010 name 00000110) 00000110)
                         ((00100010 name 00000111) 00000111)
                         (t (my-semantic-id-for-surface name)))))
      (00000111
        ((00100010 semantic-id 00000001) (00000001 quote))
        ((00100010 semantic-id 00000010) (00000001 atom))
        ((00100010 semantic-id 00000011) (00000001 eq))
        ((00100010 semantic-id 00000100) (00000001 cons))
        ((00100010 semantic-id 00000101) (00000001 car))
        ((00100010 semantic-id 00000110) (00000001 cdr))
        ((00100010 semantic-id 00000111) (00000001 cond))
        (t (00000001 ()))))))

(00001001 my-lambda-name?
  (00001000 (name)
    (my-semantic-id? name 00001000)))

(00001001 my-define-name?
  (00001000 (name)
    (my-semantic-id? name 00001001)))

(00001001 my-defmacro-name?
  (00001000 (name)
    (my-semantic-id? name 00001010)))

(00001001 my-def-compat-name?
  (00001000 (name)
    (my-semantic-id? name 00001011)))

(00001001 my-definition-name?
  (00001000 (name)
    (00000111
      ((my-define-name? name) t)
      ((my-def-compat-name? name) t)
      (t (00000001 ())))))

(00001001 my-canon-name?
  (00001000 (name)
    (00000111
      ((my-canon-identity name) t)
      (t (00000001 ())))))

(00001001 my-canon-callable-identity?
  (00001000 (identity-ref)
    (00000111
      ((00000011 identity-ref (00000001 atom)) t)
      ((00000011 identity-ref (00000001 eq)) t)
      ((00000011 identity-ref (00000001 cons)) t)
      ((00000011 identity-ref (00000001 car)) t)
      ((00000011 identity-ref (00000001 cdr)) t)
      (t (00000001 ())))))

(00001001 my-canon-quote-name?
  (00001000 (name)
    (00000011 (my-canon-identity name) (00000001 quote))))

(00001001 my-canon-cond-name?
  (00001000 (name)
    (00000011 (my-canon-identity name) (00000001 cond))))

(00001001 my-canon-binding-error
  (00001000 (name)
    (my-error
      (00000001 invalid-form)
      (00100111 (00000001 canonical-name-immutable) name))))

; Root primitive meanings are represented as values. Canon is handled first.
; Ordinary non-Canon boundary spellings are resolved to exact SENS identities
; here; the primitive value carried by the evaluator never uses the human
; spelling as its identity.
(00001001 my-default-binding
  (00001000 (name)
    (10011100 ((identity-ref (my-canon-identity name)))
      (00000111
        ((my-canon-callable-identity? identity-ref) (my-primitive identity-ref))
        ((my-canon-name? name) (my-canon-binding-error name))
        ((my-semantic-id? name 00001100) (my-primitive 00001100))
        ((my-semantic-id? name 00001101) (my-primitive 00001101))
        ((my-semantic-id? name 00001110) (my-primitive 00001110))
        ((my-semantic-id? name 00011010) (my-primitive 00011010))
        ((my-semantic-id? name 00011100) (my-primitive 00011100))
        ((my-semantic-id? name 00011011) (my-primitive 00011011))
        ((my-semantic-id? name 01001100)
         (my-primitive 01001100))
        ((my-semantic-id? name 01000011)
         (my-primitive 01000011))
        (t name)))))

; ADR-009 shared definition frame.
;
; The metacircular environment remains finite Lisp data. A binding whose key is
; the non-symbol internal sentinel 0 stores the mutable-in-the-language-model
; top-level frame as an ordinary alist:
;
;   ((0 . ((latest . value) ...)) . lexical-outer-env)
;
; User binders are symbols, so the sentinel cannot collide with a legal source
; binding. Local lexical bindings are consed before this marker. At closure call
; time only the marker payload is refreshed from the caller; local captured
; bindings before it are preserved. This models shared frame identity without
; dynamic scope and without a cyclic host object.
(00001001 my-shared-frame-binding?
  (00001000 (binding)
    (00000111
      ((00000010 binding) () (00000001 ()))
      ((00000010 binding) (1) (00000001 ()))
      (t (00000011 (00000101 binding) 0)))))

(00001001 my-frame-bound?
  (00001000 (name frame)
    (00000111
      ((00000010 frame) () (00000001 ()))
      ((00000010 frame) (1) (00000001 ()))
      ((00000011 (00000101 (00000101 frame)) name) t)
      (t (my-frame-bound? name (00000110 frame))))))

(00001001 my-frame-lookup
  (00001000 (name frame)
    (00000111
      ((00000011 (00000101 (00000101 frame)) name) (00000110 (00000101 frame)))
      (t (my-frame-lookup name (00000110 frame))))))

(00001001 my-env-has-shared-frame?
  (00001000 (env-ref)
    (00000111
      ((00000010 env-ref) () (00000001 ()))
      ((00000010 env-ref) (1) (00000001 ()))
      ((my-shared-frame-binding? (00000101 env-ref)) t)
      (t (my-env-has-shared-frame? (00000110 env-ref))))))

(00001001 my-shared-frame-value
  (00001000 (env-ref)
    (00000111
      ((00000010 env-ref) () (00000001 ()))
      ((00000010 env-ref) (1) (00000001 ()))
      ((my-shared-frame-binding? (00000101 env-ref)) (00000110 (00000101 env-ref)))
      (t (my-shared-frame-value (00000110 env-ref))))))

(00001001 my-ensure-shared-frame
  (00001000 (env-ref)
    (00000111
      ((my-env-has-shared-frame? env-ref) env-ref)
      (t (00000100 (00000100 0 (00000001 ())) env-ref)))))

(00001001 my-replace-shared-frame
  (00001000 (env-ref frame)
    (00000111
      ((00000010 env-ref) () env-ref)
      ((00000010 env-ref) (1) env-ref)
      ((my-shared-frame-binding? (00000101 env-ref))
       (00000100 (00000100 0 frame) (00000110 env-ref)))
      (t
       (00000100 (00000101 env-ref)
             (my-replace-shared-frame (00000110 env-ref) frame))))))

(00001001 my-refresh-shared-frame
  (00001000 (captured-env caller-env)
    (00000111
      ((my-env-has-shared-frame? captured-env)
       (00000111
         ((my-env-has-shared-frame? caller-env)
          (my-replace-shared-frame
            captured-env
            (my-shared-frame-value caller-env)))
         (t captured-env)))
      (t captured-env))))

; Definitions update the shared marker when one is active. Outside
; my-eval-program this falls back to the historical plain-alist extension, so
; direct my-eval-top-form use remains compatible.
(00001001 my-env-define
  (00001000 (name value env-ref)
    (00000111
      ((00000010 env-ref) () (00000100 (00000100 name value) env-ref))
      ((00000010 env-ref) (1) (00000100 (00000100 name value) env-ref))
      ((my-shared-frame-binding? (00000101 env-ref))
       (00000100
         (00000100 0
               (00000100 (00000100 name value)
                     (00000110 (00000101 env-ref))))
         (00000110 env-ref)))
      (t
       (00000100 (00000101 env-ref)
             (my-env-define name value (00000110 env-ref)))))))

; Contract 6.0: Canon outranks the lexical alist even if a hostile/pre-existing
; environment contains the same text. Non-Canon names retain ordinary lookup.
(00001001 env-lookup
  (00001000 (name env-ref)
    (10011100 ((identity-ref (my-canon-identity name)))
      (00000111
        ((my-canon-callable-identity? identity-ref) (my-primitive identity-ref))
        ((my-canon-name? name) (my-canon-binding-error name))
        ((00000010 env-ref) () (my-default-binding name))
        ((00000010 env-ref) (1) (my-default-binding name))
        ((my-shared-frame-binding? (00000101 env-ref))
         (00000111
           ((my-frame-bound? name (00000110 (00000101 env-ref)))
            (my-frame-lookup name (00000110 (00000101 env-ref))))
           (t (env-lookup name (00000110 env-ref)))))
        ((00000011 (00000101 (00000101 env-ref)) name) (00000110 (00000101 env-ref)))
        (t (env-lookup name (00000110 env-ref)))))))

(00001001 env-bound?
  (00001000 (name env-ref)
    (00000111
      ((my-canon-name? name) t)
      ((00000010 env-ref) () (00000001 ()))
      ((00000010 env-ref) (1) (00000001 ()))
      ((my-shared-frame-binding? (00000101 env-ref))
       (00000111
         ((my-frame-bound? name (00000110 (00000101 env-ref))) t)
         (t (env-bound? name (00000110 env-ref)))))
      ((00000011 (00000101 (00000101 env-ref)) name) t)
      (t (env-bound? name (00000110 env-ref))))))

(00001001 my-primitive?
  (00001000 (value)
    (00000111
      ((00000010 value) () (00000001 ()))
      ((00000010 value) (1) (00000001 ()))
      (t (00000011 (00000101 value) (00000001 primitive))))))

; UnknownSymbol belongs to name resolution, not application. A symbol produced
; as a value (for example by quote) is not an unresolved lookup and therefore
; must later fail as not-callable/Type if placed in operator position.
;
; `symbol?` itself is language-owned in core.lisp, derived without a Rust builtin,
; so this distinction adds no primitive to the closed Canon.
(00001001 my-unresolved-name?
  (00001000 (name env-ref)
    (00000111
      ((00100011 name)
       (00000111
         ((00000011 name t) (00000001 ()))
         ((my-canon-name? name) (00000001 ()))
         ((env-bound? name env-ref) (00000001 ()))
         ((my-primitive? (my-default-binding name)) (00000001 ()))
         (t t)))
      (t (00000001 ())))))

(00001001 my-macro?
  (00001000 (value)
    (00000111
      ((00000010 value) () (00000001 ()))
      ((00000010 value) (1) (00000001 ()))
      (t (00000011 (00000101 value) (00000001 macro))))))

(00001001 my-closure?
  (00001000 (value)
    (00000111
      ((00000010 value) () (00000001 ()))
      ((00000010 value) (1) (00000001 ()))
      (t (00000011 (00000101 value) (00000001 closure))))))

; A recursive closure is finite Lisp data. It does not require a cyclic host
; Environment. At call time my-apply reconstructs the one self-binding that
; the function needs. Contract 6 guarantees that this name is never Canon.
;
; Shape:
;   (recursive-closure name params body captured-env)
(00001001 my-recursive-closure?
  (00001000 (value)
    (00000111
      ((00000010 value) () (00000001 ()))
      ((00000010 value) (1) (00000001 ()))
      (t (00000011 (00000101 value) (00000001 recursive-closure))))))

; A mutually-recursive group is also finite Lisp data. Every member stores the
; same raw group and captured outer environment; my-apply reconstructs the
; group's bindings at call time rather than relying on a cyclic host object.
;
; Shape:
;   (recursive-group-closure name params body group captured-env)
(00001001 my-group-closure?
  (00001000 (value)
    (00000111
      ((00000010 value) () (00000001 ()))
      ((00000010 value) (1) (00000001 ()))
      (t (00000011 (00000101 value) (00000001 recursive-group-closure))))))

(00001001 my-lambda-form?
  (00001000 (form)
    (00000111
      ((00000010 form) () (00000001 ()))
      ((00000010 form) (1) (00000001 ()))
      ((00000010 (00000101 form)) () (my-lambda-name? (00000101 form)))
      ((00000010 (00000101 form)) (1) (my-lambda-name? (00000101 form)))
      (t (00000001 ())))))

(00001001 my-lambda-def-form?
  (00001000 (form)
    (00000111
      ((00000010 form) () (00000001 ()))
      ((00000010 form) (1) (00000001 ()))
      ((my-definition-name? (00000101 form))
       (00000111
         ((my-canon-name? (00101111 form)) (00000001 ()))
         (t (my-lambda-form? (00110000 form)))))
      (t (00000001 ())))))

(00001001 my-fourth
  (00001000 (values)
    (00000101 (00000110 (00000110 (00000110 values))))))

(00001001 my-fifth
  (00001000 (values)
    (00000101 (00000110 (00000110 (00000110 (00000110 values)))))))

(00001001 my-sixth
  (00001000 (values)
    (00000101 (00000110 (00000110 (00000110 (00000110 (00000110 values))))))))

(00001001 my-compare-two
  (00001000 (operator left right)
    (00000111
      ((00000011 operator 00011010) (00011010 left right))
      ((00000011 operator 00011100) (00011100 left right))
      ((00000011 operator 00011011) (00011011 left right))
      (t (00000001 ())))))

; Chained comparison semantics are Lisp-owned: values arrive already
; evaluated, adjacent pairs are compared left-to-right, and evaluation stops
; at the first false pair.
; NOTE: my-compare-two returns exact-Q 1/0, not t/(). Since 0 is truthy
; in my-lisp (only Nil and Bool(false) are falsy), we MUST use a 3-part
; clause matching the exact-Q YES result (1) — not a 2-part clause.
(00001001 my-compare-chain
  (00001000 (operator values)
    (00000111
      ((00000010 (00000110 values)) () t)
      ((00000010 (00000110 values)) (1) t)
      ((00000011 (my-compare-two operator (00000101 values) (00101111 values)) 1)
       (my-compare-chain operator (00000110 values)))
      (t (00000001 ())))))

; Primitive *identity* is a Lisp value. This function is the narrow bridge
; from that identity to the admitted native operation mechanism.
(00001001 my-apply-primitive
  (00001000 (name args)
    (00000111
      ((00000011 name (00000001 atom)) (00000010 (00000101 args)))
      ((00000011 name (00000001 eq))   (00000011 (00000101 args) (00101111 args)))
      ((00000011 name (00000001 car))  (00000101 (00000101 args)))
      ((00000011 name (00000001 cdr))  (00000110 (00000101 args)))
      ((00000011 name (00000001 cons)) (00000100 (00000101 args) (00101111 args)))
      ((00000011 name 00001100) (00001100 (00000101 args) (00101111 args)))
      ((00000011 name 00001101) (00001101 (00000101 args) (00101111 args)))
      ((00000011 name 00001110) (00001110 (00000101 args) (00101111 args)))
      ((00000011 name 00011010) (my-compare-chain 00011010 args))
      ((00000011 name 00011100) (my-compare-chain 00011100 args))
      ((00000011 name 00011011) (my-compare-chain 00011011 args))
      ((00000011 name 01001100)
       (01001100 (00000101 args)))
      ((00000011 name 01000011)
       (01000011 (00000101 args)))
      (t (00100111 (00000001 unknown-primitive) name)))))

; Lambda-list arity is derivable from Lisp list structure itself:
;   (x y)        -> exact 2
;   (x y . rest) -> at least 2
;   args         -> at least 0
; No host metadata is required.
(00001001 my-fixed-param-count
  (00001000 (params)
    (00000111
      ((00000010 params) () 0)
      ((00000010 params) (1) 0)
      (t (00001100 1 (my-fixed-param-count (00000110 params)))))))

(00001001 my-rest-param?
  (00001000 (params)
    (00000111
      ((00000010 params) () (00000111
         ((00000011 params (00000001 ())) (00000001 ()))
         (t t)))
      ((00000010 params) (1) (00000111
         ((00000011 params (00000001 ())) (00000001 ()))
         (t t)))
      (t (my-rest-param? (00000110 params))))))

(00001001 my-arity-ok?
  (00001000 (params args)
    (10011100 ((fixed (my-fixed-param-count params))
          (received (00101000 args)))
      (00000111
        ((my-rest-param? params)
         (00000111
           ((00011010 received fixed) 1 (00000001 ()))
           ((00011010 received fixed) 0 t)))
        (t
         (00000111
           ((00011100 received fixed) 1 t)
           ((00011100 received fixed) 0 (00000001 ()))))))))

(00001001 my-arity-detail
  (00001000 (params args)
    (10011100 ((fixed (my-fixed-param-count params))
          (received (00101000 args)))
      (00100111
        (00000001 expected)
        (00000111
          ((my-rest-param? params) (00100111 (00000001 at-least) fixed))
          (t (00100111 (00000001 exact) fixed)))
        (00000001 received)
        received))))

(00001001 my-arity-error
  (00001000 (params args)
    (my-error (00000001 arity) (my-arity-detail params args))))

; Lambda-list validation is syntax semantics, not application semantics.
; Contract 6 adds reserved-Canon rejection to the existing structural checks.
(00001001 my-symbol-member?
  (00001000 (name names)
    (00000111
      ((00000010 names) () (00000001 ()))
      ((00000010 names) (1) (00000001 ()))
      ((00000011 name (00000101 names)) t)
      (t (my-symbol-member? name (00000110 names))))))

(00001001 my-lambda-list-error-pairs
  (00001000 (params seen)
    (00000111
      ((00000010 params) () (00000111
         ((00000011 params (00000001 ())) (00000001 ()))
         ((00100011 params)
          (00000111
            ((my-canon-name? params)
             (00100111 (00000001 canonical-parameter) params))
            ((my-symbol-member? params seen)
             (00100111 (00000001 duplicate-parameter) params))
            (t (00000001 ()))))
         (t (00100111 (00000001 invalid-rest) params))))
      ((00000010 params) (1) (00000111
         ((00000011 params (00000001 ())) (00000001 ()))
         ((00100011 params)
          (00000111
            ((my-canon-name? params)
             (00100111 (00000001 canonical-parameter) params))
            ((my-symbol-member? params seen)
             (00100111 (00000001 duplicate-parameter) params))
            (t (00000001 ()))))
         (t (00100111 (00000001 invalid-rest) params))))
      ((00100011 (00000101 params))
       (00000111
         ((my-canon-name? (00000101 params))
          (00100111 (00000001 canonical-parameter) (00000101 params)))
         ((my-symbol-member? (00000101 params) seen)
          (00100111 (00000001 duplicate-parameter) (00000101 params)))
         (t
          (my-lambda-list-error-pairs
            (00000110 params)
            (00000100 (00000101 params) seen)))))
      (t (00100111 (00000001 non-symbol-parameter) (00000101 params))))))

(00001001 my-lambda-list-error
  (00001000 (params)
    (00000111
      ((00000010 params) () (00000111
         ((00000011 params (00000001 ())) (00000001 ()))
         ((00100011 params)
          (00000111
            ((my-canon-name? params)
             (00100111 (00000001 canonical-parameter) params))
            (t (00000001 ()))))
         (t (00100111 (00000001 invalid-parameters) params))))
      ((00000010 params) (1) (00000111
         ((00000011 params (00000001 ())) (00000001 ()))
         ((00100011 params)
          (00000111
            ((my-canon-name? params)
             (00100111 (00000001 canonical-parameter) params))
            (t (00000001 ()))))
         (t (00100111 (00000001 invalid-parameters) params))))
      (t (my-lambda-list-error-pairs params (00000001 ()))))))

(00001001 my-lambda-invalid-form
  (00001000 (problem)
    (my-error
      (00000001 invalid-form)
      (00000100 (00000001 lambda-parameters) problem))))

(00001001 my-make-closure
  (00001000 (params body env-ref)
    (10011100 ((problem (my-lambda-list-error params)))
      (00000111
        ((00000010 problem) () (00100111 (00000001 closure) params body env-ref))
        ((00000010 problem) (1) (00100111 (00000001 closure) params body env-ref))
        (t (my-lambda-invalid-form problem))))))

; Return the first malformed lambda-list in a top-level recursive group.
; Canon-named definitions never enter a recursive group; my-lambda-def-form?
; routes them to the ordinary top-form rejection path first.
(00001001 my-lambda-def-group-error
  (00001000 (forms)
    (00000111
      ((00000010 forms) () (00000001 ()))
      ((00000010 forms) (1) (00000001 ()))
      (t
       (10011100 ((problem
               (my-lambda-list-error (00101111 (00110000 (00000101 forms))))))
         (00000111
           ((00000010 problem) () (my-lambda-def-group-error (00000110 forms)))
           ((00000010 problem) (1) (my-lambda-def-group-error (00000110 forms)))
           (t problem)))))))

; Parameter binding owns only the successful path. Arity and Canon-name
; validity are checked before this function is entered.
(00001001 bind-params
  (00001000 (params args env-ref)
    (00000111
      ((00000010 params) () (00000111
         ((00000011 params (00000001 ())) env-ref)
         (t (00000100 (00000100 params args) env-ref))))
      ((00000010 params) (1) (00000111
         ((00000011 params (00000001 ())) env-ref)
         (t (00000100 (00000100 params args) env-ref))))
      (t (00000100 (00000100 (00000101 params) (00000101 args))
               (bind-params (00000110 params) (00000110 args) env-ref))))))

(00001001 my-eval-list-result
  (00001000 (exprs env-ref)
    (00000111
      ((00000010 exprs) () (my-result-ok (00000001 ())))
      ((00000010 exprs) (1) (my-result-ok (00000001 ())))
      (t
       (10011100 ((head-result (my-eval-result (00000101 exprs) env-ref)))
         (00000111
           ((my-result-fail? head-result) head-result)
           (t
            (10011100 ((tail-result (my-eval-list-result (00000110 exprs) env-ref)))
              (00000111
                ((my-result-fail? tail-result) tail-result)
                (t
                 (my-result-ok
                   (00000100
                     (my-result-value head-result)
                     (my-result-value tail-result)))))))))))))

(00001001 my-eval-list
  (00001000 (exprs env-ref)
    (my-result-value (my-eval-list-result exprs env-ref))))

(00001001 my-eval-body-result
  (00001000 (body env-ref)
    (00000111
      ((00000010 (00000110 body)) () (my-eval-result (00000101 body) env-ref))
      ((00000010 (00000110 body)) (1) (my-eval-result (00000101 body) env-ref))
      (t
       (10011100 ((first-result (my-eval-result (00000101 body) env-ref)))
         (00000111
           ((my-result-fail? first-result) first-result)
           (t (my-eval-body-result (00000110 body) env-ref))))))))

(00001001 my-eval-body
  (00001000 (body env-ref)
    (my-result-value (my-eval-body-result body env-ref))))

(00001001 my-cond-has-migration-clause?
  (00001000 (clauses)
    (00000111
      ((00000010 clauses) () (00000001 ()))
      ((00000010 clauses) (1) (00000001 ()))
      ((00000010 (00000101 clauses)) () (my-cond-has-migration-clause? (00000110 clauses)))
      ((00000010 (00000101 clauses)) (1) (my-cond-has-migration-clause? (00000110 clauses)))
      ((00000011 (00101000 (00000101 clauses)) 2) (1) t)
      ((00000011 (00101000 (00000101 clauses)) 2) (0)
       (my-cond-has-migration-clause? (00000110 clauses))))))

(00001001 my-eval-cond-result-mode
  (00001000 (clauses env-ref migration-compatibility?)
    (00000111
      ((00000010 clauses) () (00000111
         (migration-compatibility? (my-result-ok (00000001 ())))
         (t
          (my-result-fail
            (my-error (00000001 unsatisfied-conditional) (00000001 cond))))))
      ((00000010 clauses) (1) (00000111
         (migration-compatibility? (my-result-ok (00000001 ())))
         (t
          (my-result-fail
            (my-error (00000001 unsatisfied-conditional) (00000001 cond))))))
      (t
       (10011100 ((clause (00000101 clauses)))
         (00000111
           ; #217 canonical path: evaluate only the query. The expected result
           ; is already Lisp data in the interpreted program and must never be
           ; executed as code. Match it structurally, then evaluate the branch.
           ((00000011 (00101000 clause) 3) (1)
            (10011100 ((test-result (my-eval-result (00000101 clause) env-ref)))
              (00000111
                ((my-result-fail? test-result) test-result)
                ((00100010 (my-result-value test-result) (00101111 clause))
                 (1)
                 (my-eval-result (00110000 clause) env-ref))
                ((00100010 (my-result-value test-result) (00101111 clause))
                 (0)
                 (my-eval-cond-result-mode
                   (00000110 clauses) env-ref migration-compatibility?)))))
           ; Historical two-part clauses remain migration-only, mirroring the
           ; native evaluator until their callers are moved to explicit result
           ; matching. This path intentionally retains old truthiness.
           ((00000011 (00101000 clause) 2) (1)
            (10011100 ((test-result (my-eval-result (00000101 clause) env-ref)))
              (00000111
                ((my-result-fail? test-result) test-result)
                ((my-result-value test-result)
                 (my-eval-result (00101111 clause) env-ref))
                (t
                 (my-eval-cond-result-mode
                   (00000110 clauses) env-ref migration-compatibility?)))))
           (t
            (my-result-fail
              (my-error
                (00000001 invalid-form)
                (00100111 (00000001 cond-clause) clause))))))))))

(00001001 my-eval-cond-result
  (00001000 (clauses env-ref)
    (my-eval-cond-result-mode
      clauses env-ref (my-cond-has-migration-clause? clauses))))

(00001001 my-eval-cond
  (00001000 (clauses env-ref)
    (my-result-value (my-eval-cond-result clauses env-ref))))

(00001001 my-take-lambda-def-group
  (00001000 (forms)
    (00000111
      ((00000010 forms) () (00000001 ()))
      ((00000010 forms) (1) (00000001 ()))
      ((my-lambda-def-form? (00000101 forms))
       (00000100 (00000101 forms)
             (my-take-lambda-def-group (00000110 forms))))
      (t (00000001 ())))))

(00001001 my-drop-lambda-def-group
  (00001000 (forms)
    (00000111
      ((00000010 forms) () (00000001 ()))
      ((00000010 forms) (1) (00000001 ()))
      ((my-lambda-def-form? (00000101 forms))
       (my-drop-lambda-def-group (00000110 forms)))
      (t forms))))

(00001001 my-group-closure-from-def
  (00001000 (form group captured-env)
    (10011100 ((lambda-form (00110000 form)))
      (00100111 (00000001 recursive-group-closure)
            (00101111 form)
            (00101111 lambda-form)
            (00000110 (00000110 lambda-form))
            group
            captured-env))))

; Application-time reconstruction keeps SCC members as lexical bindings around
; the refreshed shared frame. This retains finite group recursion.
(00001001 my-build-group-env-onto
  (00001000 (forms group captured-env out)
    (00000111
      ((00000010 forms) () out)
      ((00000010 forms) (1) out)
      (t
       (10011100 ((form (00000101 forms)))
         (my-build-group-env-onto
           (00000110 forms)
           group
           captured-env
           (00000100
             (00000100 (00101111 form)
                   (my-group-closure-from-def form group captured-env))
             out)))))))

(00001001 my-build-group-env
  (00001000 (group captured-env)
    (my-build-group-env-onto group group captured-env captured-env)))

; Program-time installation is different: SCC members are top-level definitions
; and therefore belong to the shared definition frame rather than to a lexical
; prefix that could become a stale snapshot for later closures.
(00001001 my-install-group-env-onto
  (00001000 (forms group captured-env out)
    (00000111
      ((00000010 forms) () out)
      ((00000010 forms) (1) out)
      (t
       (10011100 ((form (00000101 forms)))
         (my-install-group-env-onto
           (00000110 forms)
           group
           captured-env
           (my-env-define
             (00101111 form)
             (my-group-closure-from-def form group captured-env)
             out)))))))

(00001001 my-install-group-env
  (00001000 (group captured-env)
    (my-install-group-env-onto group group captured-env captured-env)))

; caller-env is optional only for compatibility with the old experimental
; meta-eval-mutual wrapper. Main my-eval always passes it. When present it is
; used solely to refresh the shared top-level marker in a captured environment.
; Internal application returns an outcome envelope. This keeps evaluator
; failures distinct from ordinary Lisp data whose printed shape happens to be
; `(error ...)`.
(00001001 my-apply-result
  (00001000 (fn args caller-env)
    (00000111
      ((00000010 fn) () (my-result-fail (my-error (00000001 not-callable) fn)))
      ((00000010 fn) (1) (my-result-fail (my-error (00000001 not-callable) fn)))
      ((my-primitive? fn)
       (my-result-ok (my-apply-primitive (00101111 fn) args)))
      ((my-closure? fn)
       (00000111
         ((my-arity-ok? (00101111 fn) args)
          (my-eval-body-result
            (00110000 fn)
            (bind-params
              (00101111 fn)
              args
              (my-refresh-shared-frame
                (my-fourth fn)
                caller-env))))
         (t
          (my-result-fail (my-arity-error (00101111 fn) args)))))
      ((my-recursive-closure? fn)
       (00000111
         ((my-arity-ok? (00110000 fn) args)
          (10011100 ((captured
                  (my-refresh-shared-frame
                    (my-fifth fn)
                    caller-env)))
            (10011100 ((self-env
                    (00000100 (00000100 (00101111 fn) fn)
                          captured)))
              (my-eval-body-result
                (my-fourth fn)
                (bind-params
                  (00110000 fn)
                  args
                  self-env)))))
         (t
          (my-result-fail (my-arity-error (00110000 fn) args)))))
      ((my-group-closure? fn)
       (00000111
         ((my-arity-ok? (00110000 fn) args)
          (10011100 ((captured
                  (my-refresh-shared-frame
                    (my-sixth fn)
                    caller-env)))
            (10011100 ((group-env
                    (my-build-group-env (my-fifth fn) captured)))
              (my-eval-body-result
                (my-fourth fn)
                (bind-params
                  (00110000 fn)
                  args
                  group-env)))))
         (t
          (my-result-fail (my-arity-error (00110000 fn) args)))))
      ((my-macro? fn)
       (00000111
         ((my-arity-ok? (00101111 fn) args)
          (my-eval-body-result
            (00110000 fn)
            (bind-params
              (00101111 fn)
              args
              (my-refresh-shared-frame
                (my-fourth fn)
                caller-env))))
         (t
          (my-result-fail (my-arity-error (00101111 fn) args)))))
      (t
       (my-result-fail (my-error (00000001 not-callable) fn))))))

(00001001 my-apply
  (00001000 (fn args . caller-env-rest)
    (10011100 ((caller-env
            (00000111
              ((00000010 caller-env-rest) () (00000001 ()))
              ((00000010 caller-env-rest) (1) (00000001 ()))
              (t (00000101 caller-env-rest)))))
      (my-result-value (my-apply-result fn args caller-env)))))

; Evaluate one ordinary application with explicit operator-first and
; left-to-right argument sequencing. Recursive evaluation stays inside the
; outcome channel until this application has produced a value or its first
; failure.
(00001001 my-eval-application-result
  (00001000 (expr env-ref)
    (10011100 ((fn-result (my-eval-result (00000101 expr) env-ref)))
      (00000111
        ((my-result-fail? fn-result) fn-result)
        (t
         (10011100 ((fn (my-result-value fn-result)))
           (00000111
             ((my-macro? fn)
              (00000111
                ((my-arity-ok? (00101111 fn) (00000110 expr))
                 (10011100 ((expansion-result
                         (my-apply-result fn (00000110 expr) env-ref)))
                   (00000111
                     ((my-result-fail? expansion-result) expansion-result)
                     (t
                      (my-eval-result
                        (my-result-value expansion-result)
                        env-ref)))))
                (t
                 (my-result-fail
                   (my-arity-error (00101111 fn) (00000110 expr))))))
             (t
              (10011100 ((args-result
                      (my-eval-list-result (00000110 expr) env-ref)))
                (00000111
                  ((my-result-fail? args-result) args-result)
                  (t
                   (my-apply-result
                     fn
                     (my-result-value args-result)
                     env-ref))))))))))))

(00001001 my-eval-result
  (00001000 (expr env-ref)
    (00000111
      ((00000010 expr) () (00000111
         ((my-unresolved-name? expr env-ref)
          (my-result-fail
            (my-error (00000001 unbound-symbol) expr)))
         (t
          (my-result-ok (env-lookup expr env-ref)))))
      ((00000010 expr) (1) (00000111
         ((my-unresolved-name? expr env-ref)
          (my-result-fail
            (my-error (00000001 unbound-symbol) expr)))
         (t
          (my-result-ok (env-lookup expr env-ref)))))
      ((00000010 (00000101 expr)) () (00000111
         ((my-canon-quote-name? (00000101 expr))
          (my-result-ok (00101111 expr)))
         ((my-canon-cond-name? (00000101 expr))
          (my-eval-cond-result (00000110 expr) env-ref))
         ((my-lambda-name? (00000101 expr))
          (10011100 ((problem (my-lambda-list-error (00101111 expr))))
            (00000111
              ((00000010 problem) () (my-result-ok
                 (my-make-closure
                   (00101111 expr)
                   (00000110 (00000110 expr))
                   env-ref)))
              ((00000010 problem) (1) (my-result-ok
                 (my-make-closure
                   (00101111 expr)
                   (00000110 (00000110 expr))
                   env-ref)))
              (t
               (my-result-fail
                 (my-lambda-invalid-form problem))))))
         (t
          (my-eval-application-result expr env-ref))))
      ((00000010 (00000101 expr)) (1) (00000111
         ((my-canon-quote-name? (00000101 expr))
          (my-result-ok (00101111 expr)))
         ((my-canon-cond-name? (00000101 expr))
          (my-eval-cond-result (00000110 expr) env-ref))
         ((my-lambda-name? (00000101 expr))
          (10011100 ((problem (my-lambda-list-error (00101111 expr))))
            (00000111
              ((00000010 problem) () (my-result-ok
                 (my-make-closure
                   (00101111 expr)
                   (00000110 (00000110 expr))
                   env-ref)))
              ((00000010 problem) (1) (my-result-ok
                 (my-make-closure
                   (00101111 expr)
                   (00000110 (00000110 expr))
                   env-ref)))
              (t
               (my-result-fail
                 (my-lambda-invalid-form problem))))))
         (t
          (my-eval-application-result expr env-ref))))
      (t
       (my-eval-application-result expr env-ref)))))

(00001001 my-eval
  (00001000 (expr env-ref)
    (my-result-value (my-eval-result expr env-ref))))

; Top-level sequencing. `def` and `defmacro` return `(new-env . value)` so
; the environment can be threaded explicitly to the next form. Under
; my-eval-program, my-env-define updates the ADR-009 shared definition frame;
; direct calls without a marker retain the historical plain-alist behavior.
;
; Contract 6 rejects Canon definition names before value construction.
(00001001 my-eval-top-form
  (00001000 (form env-ref)
    (00000111
      ((00000010 form) () (00000100 env-ref (my-eval form env-ref)))
      ((00000010 form) (1) (00000100 env-ref (my-eval form env-ref)))
      ((my-definition-name? (00000101 form))
       (00000111
         ((my-canon-name? (00101111 form))
          (00000100 env-ref (my-canon-binding-error (00101111 form))))
         (t
          (10011100 ((value-form (00110000 form)))
            (00000111
              ((my-lambda-form? value-form)
               (10011100 ((problem (my-lambda-list-error (00101111 value-form))))
                 (00000111
                   ((00000010 problem) () (10011100 ((value
                            (00100111 (00000001 recursive-closure)
                                  (00101111 form)
                                  (00101111 value-form)
                                  (00000110 (00000110 value-form))
                                  env-ref)))
                      (00000100
                        (my-env-define (00101111 form) value env-ref)
                        value)))
                   ((00000010 problem) (1) (10011100 ((value
                            (00100111 (00000001 recursive-closure)
                                  (00101111 form)
                                  (00101111 value-form)
                                  (00000110 (00000110 value-form))
                                  env-ref)))
                      (00000100
                        (my-env-define (00101111 form) value env-ref)
                        value)))
                   (t (00000100 env-ref (my-lambda-invalid-form problem))))))
              (t
               (10011100 ((value (my-eval value-form env-ref)))
                 (00000100
                   (my-env-define (00101111 form) value env-ref)
                   value))))))))
      ((my-defmacro-name? (00000101 form))
       (00000111
         ((my-canon-name? (00101111 form))
          (00000100 env-ref (my-canon-binding-error (00101111 form))))
         (t
          (10011100 ((macro-val
                  (00100111 (00000001 macro)
                        (00110000 form)
                        (00000110 (00000110 (00000110 form)))
                        env-ref)))
            (00000100
              (my-env-define (00101111 form) macro-val env-ref)
              macro-val)))))
      (t (00000100 env-ref (my-eval form env-ref))))))

; Dependency analysis for top-level lambda definitions stays in Lisp data.
; A graph entry is `(name dependencies)`, where dependencies are only free
; references to names from the same contiguous lambda-definition block.
(00001001 my-params-bind-name?
  (00001000 (name params)
    (00000111
      ((00000010 params) () (00000111
         ((00000011 params (00000001 ())) (00000001 ()))
         ((00000011 params name) t)
         (t (00000001 ()))))
      ((00000010 params) (1) (00000111
         ((00000011 params (00000001 ())) (00000001 ()))
         ((00000011 params name) t)
         (t (00000001 ()))))
      ((00000011 (00000101 params) name) t)
      (t (my-params-bind-name? name (00000110 params))))))

(00001001 my-forms-reference-name?
  (00001000 (forms name)
    (00000111
      ((00000010 forms) () (00000001 ()))
      ((00000010 forms) (1) (00000001 ()))
      ((my-form-references-name? (00000101 forms) name) t)
      (t (my-forms-reference-name? (00000110 forms) name)))))

(00001001 my-form-references-name?
  (00001000 (form name)
    (00000111
      ((00000010 form) () (00000111
         ((00100011 form) (00000011 form name))
         (t (00000001 ()))))
      ((00000010 form) (1) (00000111
         ((00100011 form) (00000011 form name))
         (t (00000001 ()))))
      ((00000010 (00000101 form)) () (00000111
         ; Quoted data is not a lexical dependency.
         ((my-canon-quote-name? (00000101 form)) (00000001 ()))
         ; A nested lambda can shadow a candidate top-level name.
         ((my-lambda-name? (00000101 form))
          (00000111
            ((my-params-bind-name? name (00101111 form)) (00000001 ()))
            (t (my-forms-reference-name? (00000110 (00000110 form)) name))))
         (t (my-forms-reference-name? form name))))
      ((00000010 (00000101 form)) (1) (00000111
         ; Quoted data is not a lexical dependency.
         ((my-canon-quote-name? (00000101 form)) (00000001 ()))
         ; A nested lambda can shadow a candidate top-level name.
         ((my-lambda-name? (00000101 form))
          (00000111
            ((my-params-bind-name? name (00101111 form)) (00000001 ()))
            (t (my-forms-reference-name? (00000110 (00000110 form)) name))))
         (t (my-forms-reference-name? form name))))
      (t (my-forms-reference-name? form name)))))

(00001001 my-lambda-def-references-name?
  (00001000 (form name)
    (10011100 ((lambda-form (00110000 form)))
      (00000111
        ((my-params-bind-name? name (00101111 lambda-form)) (00000001 ()))
        (t (my-forms-reference-name? (00000110 (00000110 lambda-form)) name))))))

(00001001 my-lambda-def-names
  (00001000 (forms)
    (00000111
      ((00000010 forms) () (00000001 ()))
      ((00000010 forms) (1) (00000001 ()))
      (t (00000100 (00101111 (00000101 forms))
               (my-lambda-def-names (00000110 forms)))))))

(00001001 my-def-dependencies
  (00001000 (form candidates)
    (00000111
      ((00000010 candidates) () (00000001 ()))
      ((00000010 candidates) (1) (00000001 ()))
      ((my-lambda-def-references-name? form (00000101 candidates))
       (00000100 (00000101 candidates)
             (my-def-dependencies form (00000110 candidates))))
      (t (my-def-dependencies form (00000110 candidates))))))

(00001001 my-build-dependency-graph-with-names
  (00001000 (forms names)
    (00000111
      ((00000010 forms) () (00000001 ()))
      ((00000010 forms) (1) (00000001 ()))
      (t
       (00000100
         (00100111
           (00101111 (00000101 forms))
           (my-def-dependencies (00000101 forms) names))
         (my-build-dependency-graph-with-names (00000110 forms) names))))))

(00001001 my-build-dependency-graph
  (00001000 (forms)
    (10011100 ((names (my-lambda-def-names forms)))
      (my-build-dependency-graph-with-names forms names))))

(00001001 my-graph-dependencies
  (00001000 (name graph)
    (00000111
      ((00000010 graph) () (00000001 ()))
      ((00000010 graph) (1) (00000001 ()))
      ((00000011 name (00000101 (00000101 graph))) (00101111 (00000101 graph)))
      (t (my-graph-dependencies name (00000110 graph))))))

(00001001 my-graph-dependencies-reach?
  (00001000 (dependencies target graph visited)
    (00000111
      ((00000010 dependencies) () (00000001 ()))
      ((00000010 dependencies) (1) (00000001 ()))
      ((00000011 (00000101 dependencies) target) t)
      ((my-symbol-member? (00000101 dependencies) visited)
       (my-graph-dependencies-reach?
         (00000110 dependencies) target graph visited))
      ((my-graph-reaches?
         (00000101 dependencies)
         target
         graph
         (00000100 (00000101 dependencies) visited))
       t)
      (t
       (my-graph-dependencies-reach?
         (00000110 dependencies) target graph visited)))))

(00001001 my-graph-reaches?
  (00001000 (from target graph visited)
    (my-graph-dependencies-reach?
      (my-graph-dependencies from graph)
      target
      graph
      (00000100 from visited))))

; The SCC containing `name` is the set of block names mutually reachable
; with it. `name` itself is always retained so an acyclic node is a singleton
; component; only components with 2+ members use recursive-group-closure.
(00001001 my-scc-names
  (00001000 (name candidates graph)
    (00000111
      ((00000010 candidates) () (00000001 ()))
      ((00000010 candidates) (1) (00000001 ()))
      ((00000011 name (00000101 candidates))
       (00000100 (00000101 candidates)
             (my-scc-names name (00000110 candidates) graph)))
      ((my-graph-reaches? name (00000101 candidates) graph (00000001 ()))
       (00000111
         ((my-graph-reaches? (00000101 candidates) name graph (00000001 ()))
          (00000100 (00000101 candidates)
                (my-scc-names name (00000110 candidates) graph)))
         (t (my-scc-names name (00000110 candidates) graph))))
      (t (my-scc-names name (00000110 candidates) graph)))))

(00001001 my-select-defs-by-names
  (00001000 (forms names)
    (00000111
      ((00000010 forms) () (00000001 ()))
      ((00000010 forms) (1) (00000001 ()))
      ((my-symbol-member? (00101111 (00000101 forms)) names)
       (00000100 (00000101 forms)
             (my-select-defs-by-names (00000110 forms) names)))
      (t (my-select-defs-by-names (00000110 forms) names)))))

(00001001 my-remove-defs-by-names
  (00001000 (forms names)
    (00000111
      ((00000010 forms) () (00000001 ()))
      ((00000010 forms) (1) (00000001 ()))
      ((my-symbol-member? (00101111 (00000101 forms)) names)
       (my-remove-defs-by-names (00000110 forms) names))
      (t
       (00000100 (00000101 forms)
             (my-remove-defs-by-names (00000110 forms) names))))))

(00001001 my-last-lambda-def-name
  (00001000 (forms)
    (00000111
      ((00000010 (00000110 forms)) () (00101111 (00000101 forms)))
      ((00000010 (00000110 forms)) (1) (00101111 (00000101 forms)))
      (t (my-last-lambda-def-name (00000110 forms))))))

(00001001 my-eval-lambda-components
  (00001000 (forms graph env-ref final-name)
    (00000111
      ((00000010 forms) () (00000100 env-ref (env-lookup final-name env-ref)))
      ((00000010 forms) (1) (00000100 env-ref (env-lookup final-name env-ref)))
      (t
       (10011100 ((name (00101111 (00000101 forms))))
         (10011100 ((component-names
                 (my-scc-names
                   name
                   (my-lambda-def-names forms)
                   graph)))
           (00000111
             ; A singleton stays on the ordinary top-level path. That path
             ; already gives self-recursive definitions a finite
             ; recursive-closure without falsely inventing a group.
             ((00000010 (00000110 component-names)) () (10011100 ((result (my-eval-top-form (00000101 forms) env-ref)))
                (my-eval-lambda-components
                  (00000110 forms)
                  graph
                  (00000101 result)
                  final-name)))
             ((00000010 (00000110 component-names)) (1) (10011100 ((result (my-eval-top-form (00000101 forms) env-ref)))
                (my-eval-lambda-components
                  (00000110 forms)
                  graph
                  (00000101 result)
                  final-name)))
             (t
              (10011100 ((component
                      (my-select-defs-by-names forms component-names)))
                (10011100 ((group-env (my-install-group-env component env-ref)))
                  (my-eval-lambda-components
                    (my-remove-defs-by-names forms component-names)
                    graph
                    group-env
                    final-name)))))))))))

(00001001 my-eval-lambda-block
  (00001000 (forms env-ref)
    (10011100 ((graph (my-build-dependency-graph forms))
          (final-name (my-last-lambda-def-name forms)))
      (my-eval-lambda-components forms graph env-ref final-name))))

; `my-eval-program` validates each contiguous top-level non-Canon
; lambda-definition block, builds its explicit dependency graph, and gives
; recursive-group-closure only to real multi-member strongly-connected
; components. Independent or one-way-dependent definitions stay on the
; ordinary singleton path. This prevents adjacency itself from inventing
; recursion while keeping finite Lisp data for genuine mutual recursion.
;
; For every non-empty program ADR-009 installs one finite shared-frame marker.
; Recursive calls reuse that same marker. An empty form list remains a valid
; no-op program and preserves the supplied environment exactly, so TASK-001's
; empty-program witness is unchanged.
(00001001 my-eval-program
  (00001000 (forms env-ref)
    (00000111
      ((00000010 forms) () (00000100 env-ref (00000001 ())))
      ((00000010 forms) (1) (00000100 env-ref (00000001 ())))
      (t
       (10011100 ((program-env (my-ensure-shared-frame env-ref)))
         (00000111
           ((my-lambda-def-form? (00000101 forms))
            (10011100 ((block (my-take-lambda-def-group forms)))
              (10011100 ((problem (my-lambda-def-group-error block)))
                (00000111
                  ((00000010 problem) () (10011100 ((rest (my-drop-lambda-def-group forms)))
                     (10011100 ((block-result
                             (my-eval-lambda-block block program-env)))
                       (00000111
                         ((00000010 rest) () block-result)
                         ((00000010 rest) (1) block-result)
                         (t
                          (my-eval-program
                            rest
                            (00000101 block-result)))))))
                  ((00000010 problem) (1) (10011100 ((rest (my-drop-lambda-def-group forms)))
                     (10011100 ((block-result
                             (my-eval-lambda-block block program-env)))
                       (00000111
                         ((00000010 rest) () block-result)
                         ((00000010 rest) (1) block-result)
                         (t
                          (my-eval-program
                            rest
                            (00000101 block-result)))))))
                  (t
                   (00000100
                     program-env
                     (my-lambda-invalid-form problem)))))))
           (t
            (10011100 ((result (my-eval-top-form (00000101 forms) program-env)))
              (00000111
                ((00000010 (00000110 forms)) () result)
                ((00000010 (00000110 forms)) (1) result)
                (t
                 (my-eval-program
                   (00000110 forms)
                   (00000101 result))))))))))))