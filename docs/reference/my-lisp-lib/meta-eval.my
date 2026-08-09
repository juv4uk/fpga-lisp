; A metacircular evaluator: my-eval interprets my-lisp source (read as data,
; e.g. via `read`) using only my-lisp's own primitives. Primitives —
; car/cdr/cons/atom/eq/arithmetic — are dispatched to directly, not
; reimplemented, exactly like McCarthy's own 1960 eval/apply: his eval
; called car/cdr/cons/atom/eq as given, it didn't redefine them.
;
; Environments here are plain association lists of (symbol . value) pairs,
; not the host's real Environment — my-lisp has no way to reach that from
; inside the language. `env-lookup`'s "not found" case returns the atom
; itself rather than erroring: this is what makes numbers/strings/`t`
; self-evaluate without a symbol?/numberp? primitive. It works because `eq`
; only requires both operands be atoms, not the same type — comparing a
; number against an alist's symbol keys always safely returns false, never
; a crash, so lookup falls through to "not found -> return as-is" for any
; non-symbol atom, and for any symbol that genuinely isn't bound.
;
; This is a demonstration, not part of the always-loaded bootstrap library:
; lib/core.my never depends on it, and nothing here changes what any other
; my-lisp program can do. Load it deliberately (see docs/quote-tutorial.md).
;
; Not McCarthy-complete: single-arity `atom`/`eq`/`car`/`cdr`/`cons` and
; two-argument `+`/`-`/`*` only (the real primitives are variadic where it
; matters, like `+`); no `defmacro`, `def`, `list`, or comparison operators
; inside interpreted programs. Deliberately minimal, easy to extend the
; same way for anyone who wants to.
;
; Метациркулярний evaluator: my-eval інтерпретує my-lisp-код (прочитаний як
; дані, напр. через `read`), використовуючи лише власні примітиви my-lisp.
; Примітиви — car/cdr/cons/atom/eq/арифметика — диспетчеризуються напряму,
; не переписуються заново, точно як власний eval/apply Маккарті 1960 року:
; його eval викликав car/cdr/cons/atom/eq як дані, не перевизначав їх.
;
; Середовища тут — звичайні асоціативні списки пар (символ . значення), не
; справжній Environment хоста — my-lisp не має способу дістатись до нього
; зсередини мови. Випадок "не знайдено" в `env-lookup` повертає сам атом,
; а не помилку: саме це змушує числа/рядки/`t` самообчислюватись без
; примітиву symbol?/numberp?. Працює це тому, що `eq` вимагає лише, щоб обидва
; операнди були атомами, не одного типу — порівняння числа з символьними
; ключами asoc-списку завжди безпечно повертає false, ніколи не падає, тож
; lookup провалюється до "не знайдено -> повернути як є" для будь-якого
; несимвольного атома, і для будь-якого символу, що справді не зв'язаний.
;
; Це демонстрація, не частина завжди завантажуваної bootstrap-бібліотеки:
; lib/core.my ніколи від нього не залежить, і ніщо тут не змінює те, що може
; будь-яка інша my-lisp-програма. Завантажувати навмисно (див.
; docs/quote-tutorial.md).
;
; Не McCarthy-повний: лише одноарністні `atom`/`eq`/`car`/`cdr`/`cons` і
; двоаргументні `+`/`-`/`*` (справжні примітиви варіативні там, де це
; важливо, напр. `+`); немає `list` чи операторів порівняння всередині
; інтерпретованих програм. Навмисно мінімальний, легко розширити так само
; тому, хто захоче.
;
; `def`/`defmacro` (2026-08-09): `my-eval` сам (вирази) лишається чистою
; функцією `(expr, env) -> value` — `def` не вписується в цю форму, бо йому
; треба *повернути новий env*, не лише значення. Тому `def`/`defmacro`
; обробляються окремим рівнем — `my-eval-top-form`/`my-eval-program` — який
; існує лише для послідовності верхньорівневих форм (як `lib/core.my`), не
; всередині виразу. Середовище тут — незмінний asoc-список (`cons`), тож
; `def` не *мутує* фрейм (на відміну від справжнього `def` у хост-мові,
; `environment.rs:70`) — він створює новий, розширений env і повертає його,
; `my-eval-program` явно протягує цей env до наступної форми. Чесна межа:
; рекурсивний **верхньорівневий** `def` (функція, що викликає саму себе за
; іменем) НЕ підтримується — замикання захоплює env *до* власного
; зв'язування, тож рекурсивний виклик усередині тіла не знайде себе. Це
; окрема, більша задача (потрібна якась форма відкладеного/само-посилального
; зв'язування), навмисно не вирішена тут, а не прихована.
;
; Metazirkulärer Evaluator: my-eval interpretiert my-lisp-Quellcode
; (gelesen als Daten, z. B. via `read`) nur mit my-lisps eigenen Primitiven.
; Primitive — car/cdr/cons/atom/eq/Arithmetik — werden direkt dispatcht,
; nicht neu implementiert, genau wie McCarthys eigenes eval/apply von 1960:
; sein eval rief car/cdr/cons/atom/eq als gegeben auf, ohne sie neu zu
; definieren.
;
; Umgebungen sind hier gewöhnliche Assoziationslisten aus (Symbol . Wert)
; -Paaren, nicht die echte Environment des Hosts — my-lisp hat keine
; Möglichkeit, diese aus der Sprache heraus zu erreichen. Der
; "nicht gefunden"-Fall von `env-lookup` gibt das Atom selbst zurück statt
; einen Fehler auszulösen: das lässt Zahlen/Zeichenketten/`t` ohne ein
; symbol?/numberp?-Primitiv selbstauswerten. Das funktioniert, weil `eq`
; nur verlangt, dass beide Operanden Atome sind, nicht denselben Typ — der
; Vergleich einer Zahl mit den Symbol-Schlüsseln einer Alist liefert immer
; sicher false, nie einen Absturz, sodass die Suche für jedes
; Nicht-Symbol-Atom und für jedes tatsächlich ungebundene Symbol auf
; "nicht gefunden -> unverändert zurückgeben" durchfällt.
;
; Dies ist eine Demonstration, kein Teil der stets geladenen
; Bootstrap-Bibliothek: lib/core.my hängt nie davon ab, und nichts hier
; ändert, was ein anderes my-lisp-Programm kann. Bewusst laden (siehe
; docs/quote-tutorial.md).
;
; Nicht McCarthy-vollständig: nur einstellige `atom`/`eq`/`car`/`cdr`/`cons`
; und zweistellige `+`/`-`/`*` (die echten Primitive sind variadisch, wo es
; zählt, wie `+`); kein `defmacro`, `def`, `list` oder Vergleichsoperatoren
; innerhalb interpretierter Programme. Bewusst minimal, für jeden auf
; dieselbe Weise erweiterbar, der das möchte.

; `(atom (car expr))` guards the keyword dispatch below: `eq` requires both
; operands be atoms, and a call whose head is itself a list — like
; `((lambda (x) x) 5)` — has a non-atom `(car expr)`, which would make
; `(eq (car expr) 'quote)` a Type error instead of just falling through to
; application. Checking `atom` first, before any `eq` against a keyword
; symbol, keeps that case a plain (if redundant-looking) application.
; `(atom (car expr))` захищає диспетчеризацію ключових слів нижче: `eq`
; вимагає, щоб обидва операнди були атомами, а виклик, чия голова сама є
; списком — як `((lambda (x) x) 5)` — має неатомарний `(car expr)`, що
; зробило б `(eq (car expr) 'quote)` помилкою типу замість простого
; провалу до застосування. Перевірка `atom` спершу, до будь-якого `eq` з
; ключовим символом, лишає цей випадок звичайним (хай і на вигляд
; надлишковим) застосуванням.
; `(atom (car expr))` schützt die Schlüsselwort-Dispatch unten: `eq`
; verlangt, dass beide Operanden Atome sind, und ein Aufruf, dessen Kopf
; selbst eine Liste ist — wie `((lambda (x) x) 5)` — hat ein
; nicht-atomares `(car expr)`, was `(eq (car expr) 'quote)` zu einem
; Typfehler machen würde statt einfach zur Anwendung durchzufallen. Zuerst
; `atom` zu prüfen, vor jedem `eq` gegen ein Schlüsselwort-Symbol, hält
; diesen Fall eine gewöhnliche (wenn auch redundant wirkende) Anwendung.
(def my-eval
  (lambda (expr env)
    (cond
      ((atom expr) (env-lookup expr env))
      ((atom (car expr))
       (cond
         ((eq (car expr) 'quote) (second expr))
         ((eq (car expr) 'cond) (my-eval-cond (cdr expr) env))
         ((eq (car expr) 'lambda) (list 'closure (second expr) (cdr (cdr expr)) env))
         ((eq (car expr) 'atom) (atom (my-eval (second expr) env)))
         ((eq (car expr) 'eq) (eq (my-eval (second expr) env) (my-eval (third expr) env)))
         ((eq (car expr) 'car) (car (my-eval (second expr) env)))
         ((eq (car expr) 'cdr) (cdr (my-eval (second expr) env)))
         ((eq (car expr) 'cons) (cons (my-eval (second expr) env) (my-eval (third expr) env)))
         ((eq (car expr) '+) (+ (my-eval (second expr) env) (my-eval (third expr) env)))
         ((eq (car expr) '-) (- (my-eval (second expr) env) (my-eval (third expr) env)))
         ((eq (car expr) '*) (* (my-eval (second expr) env) (my-eval (third expr) env)))
         ((my-macro? (env-lookup (car expr) env))
          (my-eval (my-apply (env-lookup (car expr) env) (cdr expr)) env))
         (t (my-apply (my-eval (car expr) env) (my-eval-list (cdr expr) env)))))
      (t (my-apply (my-eval (car expr) env) (my-eval-list (cdr expr) env))))))

; A macro call's args are passed to `my-apply` unevaluated (`(cdr expr)`
; directly, not `my-eval-list`'d) — the macro body builds an expansion from
; the raw argument forms, then `my-eval` runs *that* expansion once more,
; the same two-step shape (expand, then evaluate the result) real
; `defmacro` uses in the host language.
; Аргументи виклику макроса передаються `my-apply` неоцінені (`(cdr expr)`
; напряму, не через `my-eval-list`) — тіло макроса будує розгортку із сирих
; форм аргументів, тоді `my-eval` виконує *цю розгортку* ще раз — та сама
; двокрокова форма (розгорнути, тоді обчислити результат), яку справжній
; `defmacro` використовує в хост-мові.
(def my-macro?
  (lambda (value)
    (cond
      ((atom value) '())
      (t (eq (car value) 'macro)))))

(def my-eval-cond
  (lambda (clauses env)
    (cond
      ((atom clauses) '())
      ((my-eval (car (car clauses)) env) (my-eval (second (car clauses)) env))
      (t (my-eval-cond (cdr clauses) env)))))

(def my-eval-list
  (lambda (exprs env)
    (cond
      ((atom exprs) '())
      (t (cons (my-eval (car exprs) env) (my-eval-list (cdr exprs) env))))))

(def bind-params
  (lambda (params args env)
    (cond
      ((atom params) env)
      (t (cons (cons (car params) (car args))
               (bind-params (cdr params) (cdr args) env))))))

(def my-eval-body
  (lambda (body env)
    (cond
      ((atom (cdr body)) (my-eval (car body) env))
      (t ((lambda () (my-eval (car body) env) (my-eval-body (cdr body) env)))))))

(def my-apply
  (lambda (fn args)
    (cond
      ((eq (car fn) 'closure)
       (my-eval-body (third fn) (bind-params (second fn) args (car (cdr (cdr (cdr fn)))))))
      ((eq (car fn) 'macro)
       (my-eval-body (third fn) (bind-params (second fn) args (car (cdr (cdr (cdr fn)))))))
      (t (list 'not-callable fn)))))

(def env-lookup
  (lambda (name env)
    (cond
      ((atom env) name)
      ((eq (car (car env)) name) (cdr (car env)))
      (t (env-lookup name (cdr env))))))

; Top-level form sequencing — `def`/`defmacro` live here, not in `my-eval`
; itself (see the file-header note). `my-eval-top-form` returns
; `(new-env . value)`; `def`/`defmacro` extend `env` by consing a new
; binding onto the front (same shadowing rule as a real alist environment —
; the newest binding for a name wins), everything else evaluates normally
; and passes `env` through unchanged.
; Послідовність верхньорівневих форм — `def`/`defmacro` живуть тут, не в
; самому `my-eval` (див. примітку на початку файлу). `my-eval-top-form`
; повертає `(новий-env . значення)`; `def`/`defmacro` розширюють `env`,
; додаючи нове зв'язування спереду (те саме правило затінення, що й у
; справжньому asoc-середовищі — найновіше зв'язування для імені перемагає),
; усе інше обчислюється звично й передає `env` без змін.
(def my-eval-top-form
  (lambda (form env)
    (cond
      ((atom form) (cons env (my-eval form env)))
      ((eq (car form) 'def)
       (let ((value (my-eval (third form) env)))
         (cons (cons (cons (second form) value) env) value)))
      ((eq (car form) 'defmacro)
       (let ((macro-val (list 'macro (third form) (cdr (cdr (cdr form))) env)))
         (cons (cons (cons (second form) macro-val) env) macro-val)))
      (t (cons env (my-eval form env))))))

(def my-eval-program
  (lambda (forms env)
    (let ((result (my-eval-top-form (car forms) env)))
      (cond
        ((atom (cdr forms)) result)
        (t (my-eval-program (cdr forms) (car result)))))))
