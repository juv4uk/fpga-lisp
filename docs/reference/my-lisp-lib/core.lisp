
; my-lisp bootstrap library: derived behavior belongs in the language itself.
; Bootstrap-бібліотека my-lisp: похідна поведінка належить самій мові.
; my-lisp-Bootstrap-Bibliothek: Abgeleitetes Verhalten gehört in die Sprache selbst.

(00001001 identity (00001000 (value) value))

; Lisp-owned binary format descriptor for the canonical 8-bit bit syntax.
; The reader treats the following source forms as binary data until the next
; top-level source is read; decimal integers remain ordinary decimal values.
(00001001 binary
  (00001000 (width)
    (00100111 (00000001 binary) width)))

; `list` used to be a Rust special form (`evaluate_list_func`) — moved here
; 2026-08-09 once variadic lambda parameters existed to express it: a bare
; symbol as the parameter list binds every argument, evaluated left to
; right, as one list. This is pure sugar over `cons`/`'()`, exactly the
; kind of thing G4/G5 (docs/language-core-axioms.md) say belongs in the
; language itself once the core can already express it, not bolted onto
; the host. Kept first in this file (not wherever it happens to be used)
; because `let`/`let*` below build their expansion with it.
; `list` раніше був спеціальною формою Rust (`evaluate_list_func`) —
; перенесено сюди 2026-08-09, щойно з'явились варіативні параметри lambda,
; якими його можна виразити: голий символ як список параметрів зв'язує
; кожен аргумент, обчислений зліва направо, в один список. Це чистий цукор
; над `cons`/`'()` — саме те, що G4/G5 (docs/language-core-axioms.md)
; кажуть має належати самій мові, щойно ядро вже може це виразити, не
; хосту. Лишено першим у файлі (не там, де випадково використовується),
; бо `let`/`let*` нижче будують свою розгортку через нього.
(00001001 list (00001000 args args))

; and/or — раніше були відсутні і в цьому файлі, і як Rust-білтіни
; (перевірено: обидва grep дають нуль збігів), тож кожен, хто підключав
; my-lisp, мусив бутстрапити власні (знайдено живцем 2026-08-27 у
; chess-lisp-zero/lib/chess.lisp). Макроси, не функції — інакше "and"/"or"
; втратили б коротке замикання, обчислюючи всі аргументи наперед. Мусять
; бути variadic (rest-параметр як голий символ, як `list` вище), не
; фіксованої арності — саме так їх і використовує реальний код, що вже
; існує. Порожній `(and)` -> t, порожній `(or)` -> () — той самий вибір,
; що й у Common Lisp/Scheme, узгоджений з G8 (нейтральний елемент
; логічного "і"/"або"). Перевірено живцем: коротке замикання (другий
; аргумент дійсно не обчислюється), варіативність на 3+ аргументах,
; передача самого значення, не лише t/() (напр. (and t 42) -> 42).
(00001010 and rest
  (00000111
    ((00000010 rest) () t)
    ((00000010 rest) (1) t)
    ((00000010 (00000110 rest)) () (00000101 rest))
    ((00000010 (00000110 rest)) (1) (00000101 rest))
    (t
     ; Build the short-circuit cond AST from the primitive tree substrate.
     ; AND remains Lisp-owned; generic macro frontends need no private LIST
     ; semantic just to execute this law.
     (00000100 (00000001 00000111)
           (00000100 (00000100 (00000101 rest)
                       (00000100 (00000100 (00000001 and) (00000110 rest))
                             (00000001 ())))
                 (00000100 (00000100 t
                             (00000100 (00000001 ())
                                   (00000001 ())))
                       (00000001 ())))))))

(00001010 or rest
  (00000111
    ((00000010 rest) () (00000001 ()))
    ((00000010 rest) (1) (00000001 ()))
    ((00000010 (00000110 rest)) () (00000101 rest))
    ((00000010 (00000110 rest)) (1) (00000101 rest))
    (t
     ; Same primitive constructor discipline as AND above: preserve lazy
     ; short-circuit expansion without importing LIST into compiler authority.
     (00000100 (00000001 00000111)
           (00000100 (00000100 (00000101 rest)
                       (00000100 t (00000001 ())))
                 (00000100 (00000100 t
                             (00000100 (00000100 (00000001 or) (00000110 rest))
                                   (00000001 ())))
                       (00000001 ())))))))

; gensym — my-lisp's defmacro is unhygienic by default (no automatic
; protection against accidental variable capture; verified live
; 2026-08-27, see docs/macro-hygiene-2026-08-27.md's own capture demo).
; This is the "fresh name" tool a macro author reaches for when a name
; must NOT be visible/capturable at the call site -- built entirely
; from existing primitives, zero new Rust code, zero new language
; machinery: mono-ns (monotonic, real-time-independent counter) makes
; each call's suffix distinct, write-to-string/string-append/
; string->symbol assemble it into a real symbol. Requires an explicit
; prefix (no default-prefix convenience yet -- G5: earn that later if
; a real caller needs it, don't build it speculatively now).
(00001001 gensym
  (00001000 (prefix)
    (01000011 (00111010 prefix (01001100 (01011010))))))

(00001001 pair
  (00001000 (left right)
    (00000100 left (00000100 right (00000001 ())))))

(00001001 second
  (00001000 (values)
    (00000101 (00000110 values))))

(00001001 third
  (00001000 (values)
    (00000101 (00000110 (00000110 values)))))

(00001001 fourth
  (00001000 (values)
    (00000101 (00000110 (00000110 (00000110 values))))))

; cadddr — the classical car/cdr-composition name for the exact same
; operation fourth already performs; kept as an alias (same closure
; object, not a second definition) since real callers already spell it
; this way (lib/reason.lisp had its own local (def cadddr ...) before
; this, character-for-character identical to fourth's body).
; cadddr — класична car/cdr-композиційна назва для тієї самої операції,
; що вже виконує fourth; лишено як псевдонім (той самий об'єкт-closure,
; не друге визначення), бо реальні виклики вже пишуть саме так
; (lib/reason.lisp мав власний локальний (def cadddr ...) до цього,
; посимвольно ідентичний тілу fourth).
(00001001 cadddr fourth)

; fifth — same single-parameter primitive-chain pattern as second/third/
; fourth, one step deeper. Found duplicated in two places at once:
; lib/narrate.lisp's own local (def fifth ...), character-for-character
; identical, and lib/persistent-map.lisp's node-right, same operation
; spelled out by hand rather than named.
; fifth — той самий однопараметричний ланцюжок примітивів, що й
; second/third/fourth, ще на крок глибший. Знайдено дубльованим одразу
; у двох місцях: власний локальний (def fifth ...) у lib/narrate.lisp,
; посимвольно ідентичний, і node-right у lib/persistent-map.lisp — та
; сама операція, виписана вручну замість названа.
(00001001 fifth
  (00001000 (values)
    (00000101 (00000110 (00000110 (00000110 (00000110 values)))))))

(00001001 caar
  (00001000 (values)
    (00000101 (00000101 values))))

(00001001 cadr
  (00001000 (values)
    (00000101 (00000110 values))))

(00001001 cddr
  (00001000 (values)
    (00000110 (00000110 values))))

; length/map/filter build their result via a tail-recursive `-onto`
; accumulator, same shape as reverse/reverse-onto below, instead of consing
; after the recursive call returns (the way append naively would if it
; didn't reuse reverse/reverse-onto) — that non-tail shape grows the Rust
; call stack one frame per element, same risk `crates/my-lisp/tests/stack_safety.rs`
; exists to catch for the language's own tail calls. map/filter accumulate
; in reverse order, so they call `reverse` once at the end to undo that;
; length doesn't build a list at all, so it just returns its accumulator.
; length/map/filter будують результат через хвостово-рекурсивний
; `-onto`-акумулятор, тієї самої форми, що й reverse/reverse-onto нижче,
; замість консити після повернення з рекурсивного виклику (як append робив
; би наївно, якби не перевикористовував reverse/reverse-onto) — та
; не-хвостова форма ростить Rust call stack на один фрейм на елемент, той
; самий ризик, який `crates/my-lisp/tests/stack_safety.rs` існує, щоб
; ловити для власних хвостових викликів мови. map/filter накопичують у
; зворотному порядку, тож викликають `reverse` раз наприкінці, щоб це
; скасувати; length взагалі не будує список, тож просто повертає свій
; акумулятор.
; length/map/filter bauen ihr Ergebnis über einen endrekursiven
; `-onto`-Akkumulator auf, derselben Form wie reverse/reverse-onto unten,
; statt nach der Rückkehr des rekursiven Aufrufs zu konsen (wie append es
; naiv täte, würde es nicht reverse/reverse-onto wiederverwenden) — diese
; Nicht-Tail-Form lässt den Rust-Call-Stack um einen Frame pro Element
; wachsen, dasselbe Risiko, das `crates/my-lisp/tests/stack_safety.rs` für
; die eigenen Tail Calls der Sprache abfängt. map/filter akkumulieren in
; umgekehrter Reihenfolge und rufen daher am Ende einmal `reverse` auf, um
; das rückgängig zu machen; length baut gar keine Liste, sondern gibt
; einfach seinen Akkumulator zurück.
(00001001 length-onto
  (00001000 (values acc)
    (00000111
      ((00000010 values) () acc)
      ((00000010 values) (0)
       (length-onto (00000110 values) (00001100 acc 1))))))


(00001001 length
  (00001000 (values)
    (length-onto values 0)))

; D5:10101 REVERSE-ONTO: canonical ratified surface owns the exact-domain
; binding. The historical English spelling below is compatibility-only.
(00001001 зворот-до
  (00001000 (values acc)
    (00000111
      ((00000010 values) () acc)
      ((00000010 values) (0)
       (зворот-до (00000110 values) (00000100 (00000101 values) acc))))))

(00001001 reverse-onto зворот-до)

(00001001 reverse
  (00001000 (values)
    (зворот-до values (00000001 ()))))

; (reverse-onto (reverse left) right): reversing left first and then
; consing it back onto right, one element at a time, rebuilds
; left ++ right in the correct order — two tail-recursive passes instead
; of one non-tail pass, trading a little work for a Rust-stack-safe append.
; (reverse-onto (reverse left) right): спершу розвертаємо left, а тоді
; консимо його назад на right по елементу — відбудовує left ++ right у
; правильному порядку — два хвостово-рекурсивні проходи замість одного
; не-хвостового, невелика доплата роботою заради append, безпечного для
; Rust-стека.
; (reverse-onto (reverse left) right): left zuerst umkehren und dann
; Element für Element wieder auf right konsen, baut left ++ right in
; korrekter Reihenfolge wieder auf — zwei endrekursive Durchläufe statt
; eines Nicht-Tail-Durchlaufs, ein kleiner Mehraufwand für ein
; Rust-Stack-sicheres append.
(00001001 append
  (00001000 (left right)
    (зворот-до (00101010 left) right)))

(00001001 map-onto
  (00001000 (f values acc)
    (00000111
      ((00000010 values) () (00101010 acc))
      ((00000010 values) (1) (00000001 ()))
      ((00000010 values) (0)
       (map-onto f (00000110 values) (00000100 (f (00000101 values)) acc))))))

(00001001 map
  (00001000 (f values)
    (map-onto f values (00000001 ()))))

(00001001 filter-onto
  (00001000 (predicate values acc)
    (00000111
      ((00000010 values) () (00101010 acc))
      ((00000010 values) (1) (00101010 acc))
      ((00000010 values) (0)
       (10011100 ((decision (predicate (00000101 values))))
         (00000111
           (decision
            (filter-onto predicate (00000110 values) (00000100 (00000101 values) acc)))
           ((00000010 predicate)
            (filter-onto predicate (00000110 values) acc))))))))

(00001001 filter
  (00001000 (predicate values)
    (filter-onto predicate values (00000001 ()))))

(00001001 reduce
  (00001000 (f acc values)
    (00000111
      ((00000010 values) () acc)
      ((00000010 values) (0)
       (00111001 f (f acc (00000101 values)) (00000110 values))))))

; `let` desugars to an immediately-invoked `lambda`: `(let ((x 1) (y 2)) body)`
; expands to `((lambda (x y) body) 1 2)` — the classic trick, same shape as
; the `unless` example in docs/quote-tutorial.md. Bindings are evaluated in
; the *outer* environment before the new lexical frame exists (so
; `(let ((x 1) (y x)) ...)` fails — `y`'s value expression can't see `x`
; yet), matching Scheme/Racket's parallel `let`. Exactly two arguments,
; `body` a single expression: `defmacro` uses the same fixed-arity
; parameter binding as `lambda` (see docs/language-core.md), so there is no
; variadic/rest-body support to lean on. For a sequence of expressions,
; wrap them the same way the rest of this codebase already does —
; `(let (...) ((lambda () expr1 expr2)))`.
; `let` розгортається в негайно викликану `lambda`: `(let ((x 1) (y 2))
; тіло)` розгортається в `((lambda (x y) тіло) 1 2)` — класичний прийом,
; тієї самої форми, що й приклад `unless` у docs/quote-tutorial.md.
; Bindings обчислюються в *зовнішньому* середовищі до того, як з'явиться
; новий лексичний фрейм (тож `(let ((x 1) (y x)) ...)` провалиться — вираз
; значення `y` ще не бачить `x`), як і паралельний `let` у Scheme/Racket.
; Рівно два аргументи, `body` — один вираз: `defmacro` використовує те
; саме зв'язування параметрів фіксованої арності, що й `lambda` (див.
; docs/language-core.md), тож немає variadic/rest-body, на яке можна
; спертись. Для послідовності виразів загортай так само, як і решта цього
; коду вже робить — `(let (...) ((lambda () вираз1 вираз2)))`.
; `let` entzuckert sich zu einem sofort aufgerufenen `lambda`:
; `(let ((x 1) (y 2)) rumpf)` wird zu `((lambda (x y) rumpf) 1 2)` — der
; klassische Trick, dieselbe Form wie das `unless`-Beispiel in
; docs/quote-tutorial.md. Bindings werden in der *äußeren* Umgebung
; ausgewertet, bevor der neue lexikalische Frame existiert (daher
; scheitert `(let ((x 1) (y x)) ...)` — der Wertausdruck von `y` sieht `x`
; noch nicht), passend zu Schemes/Rackets parallelem `let`. Genau zwei
; Argumente, `body` ein einzelner Ausdruck: `defmacro` nutzt dieselbe
; Parameterbindung fester Arität wie `lambda` (siehe docs/language-core.md),
; es gibt also kein variadisches/Rest-Body, auf das man sich stützen
; könnte. Für eine Folge von Ausdrücken genauso einpacken, wie es der
; Rest dieses Codes bereits tut — `(let (...) ((lambda () ausdruck1 ausdruck2)))`.
(00001010 let (bindings body)
  (00000100 (00100111 (00000001 00001000) (00110111 (00001000 (binding) (00000101 binding)) bindings) body)
        (00110111 (00001000 (binding) (00101111 binding)) bindings)))

; `let*` is `let` with sequential (not parallel) dependency: each binding's
; value expression can see every binding before it. Expands recursively —
; `(let* ((x 1) (y (+ x 1))) body)` becomes
; `(let ((x 1)) (let* ((y (+ x 1))) body))`, peeling one binding into its
; own nested `let` at a time until none are left, at which point `body`
; evaluates directly. Each expansion step is itself new code handed back to
; the evaluator, the same macro-expansion mechanism `unless` and `let`
; already use — `let*` calling `let*` is ordinary recursion, not a special
; case the evaluator needs to know about.
; `let*` — це `let` з послідовною (не паралельною) залежністю: вираз
; значення кожного binding бачить усі попередні. Розгортається
; рекурсивно — `(let* ((x 1) (y (+ x 1))) тіло)` стає
; `(let ((x 1)) (let* ((y (+ x 1))) тіло))`, знімаючи по одному binding у
; власний вкладений `let`, поки жодного не лишиться, і тоді `тіло`
; обчислюється напряму. Кожен крок розгортання сам є новим кодом,
; переданим назад evaluator'у, тим самим механізмом розгортання макросів,
; що вже використовують `unless` і `let` — виклик `let*` із `let*` —
; звичайна рекурсія, не особливий випадок, про який має знати evaluator.
; `let*` ist `let` mit sequenzieller (nicht paralleler) Abhängigkeit: der
; Wertausdruck jedes Bindings sieht alle vorherigen. Entfaltet sich
; rekursiv — `(let* ((x 1) (y (+ x 1))) rumpf)` wird zu
; `(let ((x 1)) (let* ((y (+ x 1))) rumpf))`, wobei jeweils ein Binding in
; ein eigenes verschachteltes `let` geschält wird, bis keines mehr übrig
; ist, woraufhin `rumpf` direkt ausgewertet wird. Jeder Entfaltungsschritt
; ist selbst neuer Code, der an den Evaluator zurückgegeben wird, derselbe
; Makro-Expansionsmechanismus, den `unless` und `let` bereits nutzen —
; `let*`, das `let*` aufruft, ist gewöhnliche Rekursion, kein Sonderfall,
; von dem der Evaluator wissen müsste.
; `eq` is deliberately atom-only per McCarthy's original primitive (see
; docs/language-core.md) — `(eq '(1 2) '(1 2))` errors rather than comparing
; structurally. `equal?` is the structural/deep-equality counterpart, built
; on top of `eq` and `atom` rather than replacing them. Its answer is the
; Core4 15-state scale (#1391): `(1)` — the same structure, `(0)` — different.
; Canonical three-part `cond` consumes the answer explicitly; a two-part
; clause selects only on a «yes» answer.
(00001001 equal?
  (00001000 (a b)
    (00000111
      ((00000010 a) ()
       (00000111
         ((00000010 b) ()
          (00000001 (1)))
         ((00000010 b) (1)
          (00000001 (0)))
         ((00000010 b) (0)
          (00000001 (0)))))
      ((00000010 a) (1)
       (00000111
         ((00000010 b) ()
          (00000001 (0)))
         ((00000010 b) (1)
          (00000111
            ((00000011 a b) (1)
             (00000001 (1)))
            ((00000011 a b) (0)
             (00000001 (0)))))
         ((00000010 b) (0)
          (00000001 (0)))))
      ((00000010 a) (0)
       (00000111
         ((00000010 b) ()
          (00000001 (0)))
         ((00000010 b) (1)
          (00000001 (0)))
         ((00000010 b) (0)
          (00000111
            ((00100010 (00000101 a) (00000101 b)) (1)
             (00100010 (00000110 a) (00000110 b)))
            ((00100010 (00000101 a) (00000101 b)) (0)
             (00000001 (0))))))))))

; Exact-Q uses 1 for YES and 0 for NO.  Structural and identity relations
; retain their own result domains, so predicate consumers normalize them here.
(00001001 truthy?
  (00001000 (value)
    (00000111
      ((00000010 value) () (00000001 ()))
      ((00000010 value) (1)
       (00000111
         ((00000011 value 0) (1) (00000001 ()))
         ((00000011 value 0) (0) t)))
      ((00000010 value) (0)
       (00000111
         ((00100010 value (00000001 (0))) (1) (00000001 ()))
         ((00100010 value (00000001 (0))) (1) (00000001 ()))
         ((00100010 value (00000001 (0))) (1) (00000001 ()))
         (t t t))))))

(00001001 not?
  (00001000 (value)
    (00000111
      ((truthy? value) t (00000001 ()))
      ((truthy? value) () t))))


; nth/member?/assoc (G5 test: already expressible via existing means?)
; — yes, same recursive-list-walk shape as length/reverse above.
; Surfaced from the fpga-lisp session's assembler.lisp (2026-08-10), which
; had independently reimplemented all three locally (as nth, contains?/
; any-eq?, and assoc-str) because lib/core.lisp didn't have them — real,
; evidenced duplication, not a speculative gap. A generalized assoc here
; also matches the shape lib/meta-eval.lisp's own env-lookup already hand-
; rolls for its specific (symbol . value) alist case.
; nth/member?/assoc (G5-тест: уже виразне через наявне?) — так, та сама
; форма рекурсивного обходу списку, що й length/reverse вище. Знахідка
; з сесії fpga-lisp, assembler.lisp (2026-08-10), яка незалежно
; перевинайшла всі три локально (як nth, contains?/any-eq? і assoc-str),
; бо lib/core.lisp їх не мав — реальне, доказове дублювання, не
; спекулятивна прогалина. Узагальнений assoc тут також збігається з
; формою, яку lib/meta-eval.lisp's власний env-lookup уже вручну пише для
; свого специфічного випадку asoc-списку (symbol . value).
(00001001 nth
  (00001000 (i lst)
    (00000111
      ((00000011 i 0) (1) (00000101 lst))
      ((00000011 i 0) (0)
       (00101011 (00001101 i 1) (00000110 lst))))))

(00001001 member?
  (00001000 (item lst)
    (00000111
      ((00000010 lst) () (00000001 ()))
      ((00000010 lst) (0)
       (00000111
         ((00100010 item (00000101 lst)) (1) t)
         ((00100010 item (00000101 lst)) (0)
          (00101100 item (00000110 lst))))))))

(00001001 assoc
  (00001000 (key alist)
    (00000111
      ((00000010 alist) () (00000001 ()))
      ((00000010 alist) (0)
       (00000111
         ((00100010 key (00000101 (00000101 alist))) (1) (00000101 alist))
         ((00100010 key (00000101 (00000101 alist))) (0)
          (00101101 key (00000110 alist))))))))


; D5:11110 PAIRLIS: Lisp-owned structural law. Canonical Ukrainian surface
; owns the exact-domain binding; English spelling is compatibility-only.
(00001001 спарувати
  (00001000 (keys values tail)
    (00000111
      ((00000010 keys) () tail)
      ((00000010 keys) (0)
       (00000100
         (00000100 (00000101 keys) (00000101 values))
         (спарувати (00000110 keys) (00000110 values) tail))))))

(00001001 pairlis спарувати)

(00001010 let* (bindings body)
  (00000111
    ((00000010 bindings) () body)
    ((00000010 bindings) (0)
     ; Build the recursive expansion from the primitive tree substrate only.
     ; This keeps let* semantics in Lisp while allowing generic macro
     ; frontends to execute the law without importing the higher-level list
     ; helper as host/compiler semantic authority.
     (00000100 (00000001 let)
           (00000100 (00000100 (00000101 bindings) (00000001 ()))
                 (00000100 (00000100 (00000001 let*)
                             (00000100 (00000110 bindings)
                                   (00000100 body (00000001 ()))))
                       (00000001 ())))))))

; string-length/string-empty?/string-prefix?/string-contains? (PLAN.md
; item 14, item 20's G5 audit test applied live) — none of these need a
; new Rust primitive: string-first/string-rest already expose a string
; one character at a time, and eq already compares Value::String by
; value, so "" is a real, checkable base case — the same shape as any
; other recursive list walk in this file, just walking a string instead
; of a pair chain. string-append (genuinely un-expressible this way,
; since nothing here can build a new combined string) stays in Rust —
; see its own comment in special_forms.rs for why.
;
; string-length/string-empty?/string-prefix?/string-contains? (PLAN.md,
; пункт 14, живо застосований тест G5 з пункту 20) — жодна з них не
; потребує нового Rust-примітива: string-first/string-rest уже дають
; рядок по одному символу, а eq вже порівнює Value::String за
; значенням, тож "" — реальний, перевірюваний базовий випадок — та сама
; форма, що й будь-який інший рекурсивний обхід списку в цьому файлі,
; лише по рядку, не по ланцюжку пар. string-append (справді невиразний
; так само — нічого тут не може побудувати новий об'єднаний рядок)
; лишається в Rust — див. власний коментар у special_forms.rs, чому.
(00001001 string-membership-helper
  (00001000 (value)
    (00000111
      ((00000010 value) ()
       (00000001 (class-membership string nonmember)))
      ((00000010 value) (1)
       (00000111
         ((00000011 (00111111 (01001100 value))
              (00111111 (01001100 "")))
          (1)
          (00000001 (class-membership string member)))
         ((00000011 (00111111 (01001100 value))
              (00111111 (01001100 "")))
          (0)
          (00000001 (class-membership string nonmember)))))
      ((00000010 value) (0)
       (00000001 (class-membership string nonmember))))))

(00001001 string-order-helper
  (00001000 (left right)
    (00000111
      ((00111100 left) (1)
       (00000111
         ((00111100 right) (1)
          (00000001 (text-order same)))
         ((00111100 right) (0)
          (00000001 (text-order before)))))
      ((00111100 left) (0)
       (00000001 (text-order after)))
      ((00000011 (00111111 left) (00111111 right))
       (1)
       (string-order-helper (01000000 left) (01000000 right)))
      ((00011010 (01000101 (00111111 left))
          (01000101 (00111111 right)))
       1
       (00000001 (text-order before)))
      ((00011010 (01000101 (00111111 left))
          (01000101 (00111111 right)))
       0
       (00000001 (text-order after))))))

(00001001 nonempty-string-membership-helper
  (00001000 (value)
    (00000111
      ((string-membership-helper value)
       (class-membership string member)
       (00000111
         ((00111100 value)
          (0)
          (00000001 (class-membership string nonempty-member)))
         ((00111100 value)
          (1)
          (00000001 (class-membership string member)))))
      ((string-membership-helper value)
       (class-membership string nonmember)
       (00000001 (class-membership string nonmember))))))

; string<? — лексикографічний порядок за кодовими точками, як `<` для &str
; у Rust (UTF-8 зберігає порядок кодових точок). Переведено з Rust у мову
; (власник, 2026-09-26): рядок розбирають лише примітиви string-first
; (00111111), string-rest (01000000) і string->codepoint (01000101). Не-рядок
; дає природну помилку Type від string-first; неправильна кількість
; аргументів — Arity від прив'язки лямбди.
(00001001 string<?
  (00001000 (a b)
    (00000111
      ; Порожній бік: інший перевіряється як рядок (string-append дає Type).
      ((00111100 b) (1)
       (00101111 (00100111 (00111010 a "") (00000001 ()))))
      ((00111100 a) (1)
       (00101111 (00100111 (00111010 b "") t)))
      ((00011010 (01000101 (00111111 a)) (01000101 (00111111 b))) 1 t)
      ((00000011 (00111111 a) (00111111 b)) (1)
       (00100101 (01000000 a) (01000000 b)))
      (t t (00000001 ())))))



; `symbol?` moved out of Rust after `write-to-string` made the distinction
; expressible without exceptions: among atoms, exactly a Symbol is identical
; to the Symbol reconstructed from its canonical text. The atom guard keeps
; primitive `eq` away from pairs. This works for arbitrary symbol names, not
; only reader-friendly identifiers, because `string->symbol` takes raw text.
; `symbol?` перенесено з Rust: серед атомів лише Symbol тотожний символу,
; відновленому з його канонічного тексту. `atom` не допускає пари до `eq`.
; `symbol?` wurde aus Rust verschoben: Unter Atomen ist nur ein Symbol mit dem
; aus seinem kanonischen Text rekonstruierten Symbol identisch; `atom` schützt `eq`.
(00001001 symbol?
  (00001000 (value)
    (00000111
      ((00000010 value) () (00000001 ()))
      ((00000010 value) (1)
       (00000111
         ((00000011 value (01000011 (01001100 value)))
          (1) t)
         (t t (00000001 ()))))
      ((00000010 value) (0) (00000001 ())))))


; quotient/mod (G5 test: already expressible via existing means?) — yes.
; Unlike bitwise operations (AND/OR/XOR/shift — no primitive exposes a
; number's binary representation at all, so those would genuinely need a
; new Rust primitive), integer division and remainder for non-negative
; integers fall straight out of arithmetic and comparison primitives
; already here — no new Rust code, same class of gap as string-length
; before it. Surfaced from the fpga-lisp session's assembler.lisp
; (2026-08-10), which flagged the *absence* of bitwise/mod but found it
; non-load-bearing for its own current needs; added here anyway since
; it's genuinely useful independent of that one caller and costs
; nothing new in Rust. Scope: non-negative `a`, positive `b` only — no
; attempt at negative-number semantics (floor vs. truncate division is
; a real, unresolved design choice for negatives, deliberately left
; open rather than guessed at).
;
; First version (same-day, since replaced) recursed via repeated
; subtraction — recursion depth equal to the *quotient itself*, not
; its digit count. Fine for small examples (17/5, 100/10) but a real
; correctness bug: `(number->string 9999999999999)` (below) needs
; `(quotient 9999999999999 10)` — a quotient near 10^12 — which blew
; the Rust host's stack outright. `my-lisp` has arbitrary-precision
; exact integers (`bignum.rs`); a division whose cost scales with the
; *value* rather than its *size* was never actually general-purpose.
; Fixed here via doubling (`largest-chunk`: find the largest `b * 2^k`
; that still fits `a`, subtract it, repeat) — the standard
; binary-long-division trick, recursion depth O(log(a/b)) in both
; `largest-chunk` and `quotient` itself, tested against a 13-digit
; dividend without incident.
; quotient/mod (G5-тест: уже виразне через наявне?) — так. На відміну
; від бітових операцій (AND/OR/XOR/зсув — жоден примітив узагалі не
; відкриває бінарне представлення числа, тож ті справді потребували б
; нового Rust-примітива), цілочисельне ділення й остача для
; невід'ємних чисел випливають напряму з наявних арифметичних і
; порівняльних примітивів — без нового Rust-коду, той самий клас
; прогалини, що й string-length раніше. Знахідка з сесії fpga-lisp,
; assembler.lisp (2026-08-10), яка позначила ВІДСУТНІСТЬ bitwise/mod, але
; визнала це не критичним для власних поточних потреб; додано тут усе
; одно, бо це реально корисне незалежно від того одного викликача й не
; коштує нічого нового в Rust. Обсяг: лише невід'ємне `a`, додатне `b`
; — без спроби вгадати семантику для від'ємних чисел.
;
; Перша версія (того самого дня, відтоді замінена) рекурсувала через
; повторюване віднімання — глибина рекурсії дорівнювала САМІЙ ЧАСТЦІ,
; не кількості її розрядів. Прийнятно для малих прикладів (17/5,
; 100/10), але справжній баг коректності: `(number->string
; 9999999999999)` (нижче) вимагав `(quotient 9999999999999 10)` —
; частку близько 10^12 — що переповнило Rust-стек хоста напряму.
; `my-lisp` має цілі числа довільної точності (`bignum.rs`); ділення,
; вартість якого масштабується зі ЗНАЧЕННЯМ, а не РОЗМІРОМ, ніколи не
; було справді загальноцільовим. Виправлено через подвоєння
; (`largest-chunk`: знайти найбільше `b * 2^k`, що вміщується в `a`,
; відняти, повторити) — стандартний трюк бінарного довгого ділення,
; глибина рекурсії O(log(a/b)) як у `largest-chunk`, так і в самому
; `quotient`, перевірено на 13-розрядному діленому без проблем.
(00001001 largest-chunk
  (00001000 (a b chunk mult)
    (00000111
      ((00011010 a (00001100 chunk chunk)) 1 (00000100 chunk mult))
      ((00011010 a (00001100 chunk chunk)) 0
       (00011001 a b (00001100 chunk chunk) (00001100 mult mult))))))

; `b = 0` used to hang forever: `largest-chunk` starts doubling from
; `chunk = b`, and `0 + 0 = 0` never grows, so its "does chunk still
; fit" check never flips — an infinite tail-recursive loop, not a
; crash, silent unless you're specifically watching for it. Found the
; same way as the earlier stack-overflow bug: tested an edge case the
; first version never considered. `/` (the Rust primitive) already
; fails named on division by zero (`ErrorKind::InvalidForm`) — routing
; through it here reuses that real, already-tested error instead of
; inventing a second, different one for the same condition.
; `b = 0` раніше зависав назавжди: `largest-chunk` починає подвоювати
; від `chunk = b`, а `0 + 0 = 0` ніколи не росте, тож перевірка "чи
; chunk усе ще вміщується" ніколи не переверталась — нескінченний
; хвостово-рекурсивний цикл, не крах, непомітний, якщо спеціально не
; шукати. `/` (Rust-примітив) уже провалюється названо на діленні на
; нуль (`ErrorKind::InvalidForm`) — маршрутизація через нього тут
; перевикористовує цю реальну, вже перевірену помилку замість
; вигадування другої, іншої для того самого стану.
(00001001 quotient
  (00001000 (a b)
    (00000111
      ((00000011 b 0) (1) (00001111 a b))
      ((00000011 b 0) (0)
       (00000111
         ((00011010 a b) 1 0)
         ((00011010 a b) 0
          (10011100 ((chunk+mult (00011001 a b b 1)))
            (00001100 (00000110 chunk+mult)
               (00010100 (00001101 a (00000101 chunk+mult)) b)))))))))

(00001001 mod
  (00001000 (a b)
    (00001101 a (00001110 b (00010100 a b)))))

; `<=` and `>=` stay Lisp-derived, but #216 now requires the derived
; operators to preserve the same exact-Q answer algebra as `<`, `>` and `=`:
; exact YES -> 1/1, exact NO -> 0/1, and any inexact operand -> Canon 0 `()`.
; Canonical three-part `cond` distinguishes exact NO (0) from no-answer `()`
; without routing either through generic truthiness.
(00001001 nondecreasing-from?
  (00001000 (current remaining)
    (00000111
      ((00000010 remaining) () 1)
      ((00011010 current (00000101 remaining)) 1
       (00011111 (00000101 remaining) (00000110 remaining)))
      ((00011100 current (00000101 remaining)) 1
       (00011111 (00000101 remaining) (00000110 remaining)))
      ((00011100 current (00000101 remaining)) 0 0))))

(00001001 nonincreasing-from?
  (00001000 (current remaining)
    (00000111
      ((00000010 remaining) () 1)
      ((00011011 current (00000101 remaining)) 1
       (00100000 (00000101 remaining) (00000110 remaining)))
      ((00011100 current (00000101 remaining)) 1
       (00100000 (00000101 remaining) (00000110 remaining)))
      ((00011100 current (00000101 remaining)) 0 0))))

(00001001 <=
  (00001000 (first . remaining)
    (00011111 first remaining)))

(00001001 >=
  (00001000 (first . remaining)
    (00100000 first remaining)))

; number->string (G5 test: already expressible via existing means?) —
; yes, now that quotient/mod exist. Surfaced from the fpga-lisp
; session's assembler.lisp, which had its own version built on a fixed
; DECIMAL-POWERS lookup table (limited to ~10 digits by construction —
; the table itself has a fixed length). This one recurses via
; quotient/mod instead, the same -onto accumulator shape as
; length-onto/reverse-onto above, so it has no digit-count ceiling of
; its own (bounded only by however large an exact integer this
; implementation can represent at all). Scope: non-negative integers
; only, same as quotient/mod themselves.
; number->string (G5-тест: уже виразне через наявне?) — так, тепер,
; коли є quotient/mod. Знахідка з сесії fpga-lisp, assembler.lisp, яка
; мала власну версію на фіксованій таблиці DECIMAL-POWERS (обмежена
; ~10 розрядами самою побудовою таблиці). Ця рекурсує через
; quotient/mod, та сама -onto-форма акумулятора, що й length-onto/
; reverse-onto вище, тож не має власної стелі розрядності. Обсяг:
; лише невід'ємні цілі, як і самі quotient/mod.
(00001001 digit->string
  ; Superseded by number->string's canonical delegation to write-to-string
  ; (FIX-NUMBER-TO-STRING-RATIONAL). Retained because racket/boot/core.lisp
  ; mirrors this file and fpga-lisp's assembler.lisp carries its own local
  ; variant — removal is a separate mirrored-surface decision, not a
  ; silent one.
  (00001000 (d)
    (00101011 d (00000001 ("0" "1" "2" "3" "4" "5" "6" "7" "8" "9")))))

(00001001 number->string-onto
  (00001000 (n acc)
    (00000111
      ((00000011 n 0) (1) acc)
      ((00000011 n 0) (0)
       (number->string-onto
         (00010100 n #d10)
         (00111010 (01000111 (00010011 n #d10)) acc))))))

(00001001 number->string
  (00001000 (n)
    ; Canonical serialization for every number (FIX-NUMBER-TO-STRING-
    ; RATIONAL, docs/BUG-number-to-string-rational.md): integers render
    ; as themselves, non-integer rationals render REDUCED exactly —
    ; "1/3", never a decimal approximation, per the same G6 law that
    ; makes 10/20 serialize as "1/2". The previous quotient/mod descent
    ; crashed on fractional digit indices ((nth 1/3 <digit-table>)) and
    ; its misleading error surfaced as an apparent memory corruption.
    ; Delegation, not re-implementation: write-to-string is already the
    ; contract-tested renderer (G6 fixtures), so this cannot drift from it.
    (01001100 n)))

; -> / ->> (thread-first / thread-last macros) — express transformation pipelines
; without deep nesting (PLAN.md item / clean-code policy).
; `(-> x (f y) g)` expands to `(g (f x y))`.
; `(->> x (f y) g)` expands to `(g (f y x))`.
; Both take advantage of the variadic lambda parameter support (a bare symbol `forms`
; binds the whole list of arguments) available since 2026-08-09.
;
; -> / ->> (макроси прокидання) — виражають пайплайни перетворень без
; глибокої вкладеності (політика clean-code).
; `(-> x (f y) g)` розгортається в `(g (f x y))`.
;
; -> / ->> (Threading-Makros) — drücken Transformations-Pipelines ohne tiefe
; Verschachtelung aus.
(00001010 -> forms
  (00000111
    ((00000010 forms) () (00000001 ()))
    ((00000010 forms) (0)
     (00000111
       ((00000010 (00000110 forms)) () (00000101 forms))
       ((00000010 (00000110 forms)) (0)
        (10011101 ((x (00000101 forms))
               (next (00000101 (00000110 forms)))
               (rest (00000110 (00000110 forms)))
               (step
                 (00000111
                   ((00000010 next) () (00100111 next x))
                   ((00000010 next) (1) (00100111 next x))
                   ((00000010 next) (0)
                    (00000100 (00000101 next) (00000100 x (00000110 next)))))))
          (00000111
            ((00000010 rest) () step)
            ((00000010 rest) (0)
             (00000100 (00000001 ->) (00000100 step rest))))))))))

(00001010 ->> forms
  (00000111
    ((00000010 forms) () (00000001 ()))
    ((00000010 forms) (0)
     (00000111
       ((00000010 (00000110 forms)) () (00000101 forms))
       ((00000010 (00000110 forms)) (0)
        (10011101 ((x (00000101 forms))
               (next (00000101 (00000110 forms)))
               (rest (00000110 (00000110 forms)))
               (step
                 (00000111
                   ((00000010 next) () (00100111 next x))
                   ((00000010 next) (1) (00100111 next x))
                   ((00000010 next) (0)
                    (00101001 next (00100111 x))))))
          (00000111
            ((00000010 rest) () step)
            ((00000010 rest) (0)
             (00000100 (00000001 ->>) (00000100 step rest))))))))))

;; ── Numeric library additions (M0, 2026-08-22) ─────────────────────
;; Додано для реальних задач (WSM-24 shape comparison): abs/min/max/
;; sqrt. Усе — бібліотечні функції над наявними примітивами; жодного
 ;; нового коду в Rust-ядрі (doctrine: library before core primitive).
;;
;; Конвенції:
;;   (abs x) / (min a b ...) / (max a b ...) — Rust builtins (builtins.rs);
;;   (min-list lst)/(max-list lst) — Rust builtins для списків;
;;   (sqrt x)         — Ньютон, 40 ітерацій; точний вхід дає раціональне
;;                      наближення, дробове — дробовий результат
;;                      (S1 inexact promotion). Відʼємний вхід → nil.

(00001001 sqrt-iter
  (00001000 (guess x n)
    (00000111
      ((00011100 n 0) 1 guess)
      ((00011100 n 0) 0
       (sqrt-iter (00001111 (00001100 guess (00001111 x guess)) 2) x (00001101 n 1))))))

;; integer sqrt: Newton on quotients — provably terminating
(00001001 isqrt
  (00001000 (n)
    (00000111
      ((00011010 n 2) 1 n)
      ((00011010 n 2) 0
       (isqrt-step n (00010100 n 2))))))

(00001001 isqrt-step
  (00001000 (n g)
    (10011100 ((next (00010100 (00001100 g (00010100 n g)) 2)))
      (00000111
        ((00011010 next g) 1 (isqrt-step n next))
        ((00011010 next g) 0 g)))))

(00001001 sqrt
  (00001000 (x)
    (00000111
      ((00011010 x 0) 1 (00000001 ()))
      ((00011100 x 0) 1 0)
      ((00011100 x (00010100 x 1)) 1
       (10011100 ((r (00010110 x)))
         (00000111
           ((00011100 (00001110 r r) x) t r)
           (t t (sqrt-iter (00001111 x 2) x 8)))))
      (t t (sqrt-iter (00001111 x 2.0) x 5)))))

; abs/min/max/min-list/max-list — migrated from Rust builtins.rs to
; lib/core.lisp (owner directive 2026-09-11: "Lisp owns meaning, Rust owns
; only irreducible mechanism" — these five touch no OS/host capability,
; just arithmetic comparison and cons-list traversal already expressible
; in the language itself, so keeping them in Rust was Rust-authority
; with no substrate reason, not a necessity). Real numeric semantic IDs
; already existed for all five in lib/surface/semantic-registry.lisp
; (abs=1004, min=1005, max=1006, min-list=1011, max-list=1012, some with
; real Sanskrit spellings already ratified) — the Rust implementation
; simply never consulted them (plain `define!`, not the registry-aware
; `define_peer_builtin` path other builtins use), a second real gap this
; migration closes alongside moving the implementation itself. First
; nearly overwrote these real entries with a duplicate 1147-1151 block
; before checking the registry directly — caught before committing, not
; after.
; Behavior verified identical to the removed Rust implementation via
; crates/my-lisp/tests/builtin_to_lisp_migration.rs before deletion, not
; assumed from reading the old Rust source.
; abs/min/max/min-list/max-list — perenesheni z Rust builtins.rs u
; lib/core.lisp (nastanova vlasnyka 2026-09-11: "Lisp volodiie sensom, Rust
; volodiie lyshe nezvidnym mekhanizmom") — ni odyn iz piaty ne torkaietsia
; OS/host-mozhlyvosti, lyshe aryfmetychne porivniannia ta obkhid cons-spysku,
; vzhe vyrazhuvani samoiu movoiu.
(00001001 abs
  (00001000 (x)
    (00000111
      ((00011010 x 0) 1 (00001101 0 x))
      ((00011010 x 0) 0 x))))

; Required first parameter (dotted lambda-list, same pattern as
; `<=`/`>=` above) keeps zero arguments an Arity error via the
; evaluator's own lambda-binding check -- matching the removed Rust
; builtin's explicit "min/max expects at least one argument" error --
; without this Lisp definition needing to raise a custom error itself.
(00001001 min
  (00001000 (first . rest)
    (00010111 (00000100 first rest))))

(00001001 max
  (00001000 (first . rest)
    (00011000 (00000100 first rest))))

; Two real bugs found live via oracle testing before this landed, not
; assumed from reading the removed Rust source:
; 1. `eq`, not `equal?`, requires both operands to be atoms and errors
;    on a non-empty list -- the first draft used `(eq items (quote ()))`
;    and crashed on every non-base recursive call.
; 2. `atom` is *not* a safe "is this the empty-list sentinel" check for
;    the RECURSIVE RESULT specifically: numbers are atoms too, so
;    `(atom rest-min)` was true both for the real empty-list case and
;    for an ordinary numeric answer, collapsing them and always taking
;    the base-case branch. `items` itself is safe to test with `atom`
;    (it's always a list or (), never itself a bare number), but the
;    accumulator must use structural `equal?` against `(quote ())`.
(00001001 min-list
  (00001000 (items)
    (00000111
      ((00000010 items) () (00000001 ()))
      ((00000010 items) (0)
       (10011100 ((rest-min (00010111 (00000110 items))))
         (00000111
           ((00100010 rest-min (00000001 ())) (1)
            (00000101 items))
           ((00100010 rest-min (00000001 ())) (0)
            (00000111
              ((00011010 (00000101 items) rest-min) 1 (00000101 items))
              ((00011010 (00000101 items) rest-min) 0 rest-min)))))))))

(00001001 max-list
  (00001000 (items)
    (00000111
      ((00000010 items) () (00000001 ()))
      ((00000010 items) (0)
       (10011100 ((rest-max (00011000 (00000110 items))))
         (00000111
           ((00100010 rest-max (00000001 ())) (1)
            (00000101 items))
           ((00100010 rest-max (00000001 ())) (0)
            (00000111
              ((00011011 (00000101 items) rest-max) 1 (00000101 items))
              ((00011011 (00000101 items) rest-max) 0 rest-max)))))))))

; #469 — post-core stable peer materialization.
;
; Numeric semantic ID remains the authority. This table is only the runtime
; projection needed by Lisp libraries loaded after the ordinary core bootstrap:
; a library names the numeric ID and the binding it just defined; peer spellings
; are never implemented as UK->EN or EN->UK aliases in that library.
;
; Keep only unique stable spellings from lib/surface/semantic-registry.lisp.
; Candidate spellings are deliberately absent and therefore cannot become
; executable merely by appearing in documentation.
(00001001 my-postcore-stable-peer-projection
  (00000001 (
    (1079 utc-now поточний-всч)
    (1080 utc-from-unix всч-із-юнікс)
    (1081 unix-time-observation->utc юнікс-спостереження-у-всч)
    (1082 milliseconds-from-nanoseconds мілісекунди-із-наносекунд)
    (1083 mono-ms монотонний-мс)
    (1084 timezone-name назва-часового-поясу)
    (1085 timezone-detect визначити-часовий-пояс)
    (1086 timezone-offset-seconds зміщення-часового-поясу-в-секундах)
    (1087 deadline-reached? дедлайн-досягнуто?)
    (1088 deadline-reached-at? дедлайн-досягнуто-на-момент?)
    (1089 elapsed-ns минуло-нс)
    (1090 deadline-from дедлайн-від)
    (1091 deadline-after-ns дедлайн-через-нс)
    (1092 internet-time-sync запитати-інтернет-час)
    (162 process-run запустити-процес)
    (163 tcp-read прочитати-текст-з-з'єднання-протоколу-керування-передаванням)
    (164 tcp-write записати-текст-у-з'єднання-протоколу-керування-передаванням)
    (165 tcp-listen слухати-порт-протоколу-керування-передаванням)
    (166 read-file прочитати-файл)
    (167 write-file записати-файл)
  )))

(00001001 my-postcore-peer-group
  (00001000 (semantic-id groups)
    (00000111
      ((00000010 groups) ()
       (00000001 ()))
      ((00000010 groups) (0)
       (10011100 ((group (00000101 groups)))
         (00000111
           ((00000011 semantic-id (00000101 group)) (1)
            group)
           ((00000011 semantic-id (00000101 group)) (0)
            (my-postcore-peer-group semantic-id (00000110 groups)))))))))

(00001001 my-postcore-binding-status
  (00001000 (surface bindings)
    (00000111
      ((00000010 bindings) ()
       (00000001 absent))
      ((00000010 bindings) (0)
       (10011100 ((binding (00000101 bindings)))
         (00000111
           ((00000011 (01000010 surface) (00000101 binding)) (1)
            (00000001 present))
           ((00000011 (01000010 surface) (00000101 binding)) (0)
            (my-postcore-binding-status surface (00000110 bindings)))))))))

(00001001 my-postcore-missing-peers
  (00001000 (source peers bindings)
    (00000111
      ((00000010 peers) ()
       (00000001 ()))
      ((00000010 peers) (0)
       (10011100 ((peer (00000101 peers)))
         (00000111
           ((00000011 source peer) (1)
            (my-postcore-missing-peers source (00000110 peers) bindings))
           ((00000011 source peer) (0)
            (00000111
              ((00000011 (my-postcore-binding-status peer bindings) (00000001 present))
               (1)
               (my-postcore-missing-peers source (00000110 peers) bindings))
              ((00000011 (my-postcore-binding-status peer bindings) (00000001 absent))
               (1)
               (00000100 peer
                     (my-postcore-missing-peers
                       source
                       (00000110 peers)
                       bindings)))))))))))

; Build one expression whose nested DEFINE forms all execute in the caller's
; environment. This is why materialization is a macro rather than a function:
; an ordinary function would define peers only in its temporary child frame.
(00001001 my-postcore-build-definitions
  (00001000 (source peers)
    (00000111
      ((00000010 peers) ()
       source)
      ((00000010 peers) (0)
       (00100111 (00000001 define)
             (00000101 peers)
             (my-postcore-build-definitions source (00000110 peers)))))))

(00001010 my-postcore-materialize-stable-peers args
  (10011101 ((semantic-id (00000101 args))
         (source (00101111 args))
         (group
           (my-postcore-peer-group
             semantic-id
             my-postcore-stable-peer-projection)))
    (00000111
      ((00000010 group) ()
       source)
      ((00000010 group) (0)
       (my-postcore-build-definitions
         source
         (my-postcore-missing-peers source (00000110 group) (01001110)))))))

; Ділення з остачою (Lisp 1.5 DIVIDE): повертає список (частка остача).
(00001001 divmod
  (00001000 (dividend divisor)
    (00100111 (00010100 dividend divisor) (00010011 dividend divisor))))

; McCarthy 1960, §3d: null, subst, sublis, maplist, apply — закон Core4, коди СЕНС.
(00001001 null?
  (00001000 (x)
    (00000111
      ((00000010 x) () t)
      ((00000010 x) (0) (00000001 ()))
      ((00000010 x) (1) (00000001 ())))))

(00001001 subst
  (00001000 (x y z)
    (00000111
      ((00000010 z) (0)
       (00000100 (10101100 x y (00000101 z)) (10101100 x y (00000110 z))))
      ((00000010 z) ()
       (00000111
         ((00000011 z y) (1) x)
         ((00000011 z y) (0) z)))
      ((00000010 z) (1)
       (00000111
         ((00000011 z y) (1) x)
         ((00000011 z y) (0) z))))))

(00001001 sublis-pair
  (00001000 (x z)
    (00000111
      ((00000010 x) () z)
      ((00000010 x) (0)
       (00000111
         ((00000011 (00000101 (00000101 x)) z) (1)
          (00000101 (00000110 (00000101 x))))
         ((00000011 (00000101 (00000101 x)) z) (0)
          (sublis-pair (00000110 x) z)))))))

(00001001 sublis
  (00001000 (x y)
    (00000111
      ((00000010 y) (0)
       (00000100 (10101101 x (00000101 y)) (10101101 x (00000110 y))))
      ((00000010 y) () (sublis-pair x y))
      ((00000010 y) (1) (sublis-pair x y)))))

(00001001 maplist
  (00001000 (x f)
    (00000111
      ((00000010 x) () (00000001 ()))
      ((00000010 x) (0)
       (00000100 (f x) (10101110 (00000110 x) f))))))

(00001001 apply-quote-args
  (00001000 (m)
    (00000111
      ((00000010 m) () (00000001 ()))
      ((00000010 m) (0)
       (00000100 (00000100 (00000001 00000001) (00000100 (00000101 m) (00000001 ())))
                 (apply-quote-args (00000110 m)))))))

(00001001 apply
  (00001000 (f args)
    (01001101 (00000100 f (apply-quote-args args)))))

; #1391: логіка відповідей Core4 — закон contracts/core4-predicate-answer-scale.lisp /3.
; Відповідь — список двійкових бітів: (1)…(1 1 1 1 1 1 1) «так»,
; (0)…(0 0 0 0 0 0 0) «ні», () «невідомо». Лінія істинності:
;   0 < 00 < … < 0000000 < () < 1111111 < … < 11 < 1
; Виконуваний свідок законів — experiments/core4-logic15-algebra.lisp.

; NOT: інвертувати кожен біт, ширина та сама; () лишається ().
(00001001 answer-not
  (00001000 (a)
    (00000111
      ((00000010 a) () (00000001 ()))
      ((00000010 a) (0)
       (00000100
         (00000111
           ((00000011 (00000101 a) 0) (1) 1)
           ((00000011 (00000101 a) 0) (0) 0))
         (10110001 (00000110 a)))))))

; AND: мінімум на лінії. «Ні» перемагає; з двох «ні» — коротше (сильніше);
; з двох «так» — довше (слабше); () поглинає «так».
; Для двох відповідей одного напряму крок іде по обох списках разом.
(00001001 answer-and
  (00001000 (a b)
    (00000111
      ((00000010 a) ()
       (00000111
         ((00000010 b) () (00000001 ()))
         ((00000010 b) (0)
          (00000111
            ((00000011 (00000101 b) 0) (1) b)
            ((00000011 (00000101 b) 0) (0) (00000001 ()))))))
      ((00000010 a) (0)
       (00000111
         ((00000010 b) ()
          (00000111
            ((00000011 (00000101 a) 0) (1) a)
            ((00000011 (00000101 a) 0) (0) (00000001 ()))))
         ((00000010 b) (0)
          (00000111
            ((00000011 (00000101 a) (00000101 b)) (0)
             (00000111
               ((00000011 (00000101 a) 0) (1) a)
               ((00000011 (00000101 a) 0) (0) b)))
            ((00000011 (00000101 a) (00000101 b)) (1)
             (00000111
               ((00000010 (00000110 a)) ()
                (00000111
                  ((00000011 (00000101 a) 0) (1) a)
                  ((00000011 (00000101 a) 0) (0) b)))
               ((00000010 (00000110 b)) ()
                (00000111
                  ((00000011 (00000101 b) 0) (1) b)
                  ((00000011 (00000101 b) 0) (0) a)))
               ((00000010 (00000110 b)) (0)
                (00000100 (00000101 a)
                          (10110010 (00000110 a) (00000110 b)))))))))))))

; OR: максимум на лінії = NOT(AND(NOT a, NOT b)).
(00001001 answer-or
  (00001000 (a b)
    (10110001 (10110010 (10110001 a) (10110001 b)))))

; Послаблення: дописати той самий біт; восьмий біт належить 256 функціям,
; тож із семи бітів шкала сходиться в ().
(00001001 answer-weaken
  (00001000 (a)
    (00000111
      ((00000010 a) () (00000001 ()))
      ((00000010 a) (0)
       (00000111
         ((00000011 (00101000 a) 7) (1) (00000001 ()))
         ((00000011 (00101000 a) 7) (0)
          (00000100 (00000101 a) a)))))))

; atom? відповіддю шкали: атом (1), пара (0), () — невідомо, бо () стоїть
; вище розрізнення атом/пара.
(00001001 answer-atom
  (00001000 (x)
    (00000111
      ((00000010 x) (1) (00000001 (1)))
      ((00000010 x) (0) (00000001 (0)))
      ((00000010 x) () (00000001 ())))))

; eq? відповіддю шкали: same (1), distinct (0). Область та сама, що в eq?: атоми.
(00001001 answer-eq
  (00001000 (a b)
    (00000111
      ((00000011 a b) (1) (00000001 (1)))
      ((00000011 a b) (0) (00000001 (0))))))
