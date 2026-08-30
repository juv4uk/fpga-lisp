# Wire error-kind ↔ contract vocabulary mapping

Resolves finding F2 of docs/conformance-adversarial-report-2026-08-23.md
(fpga-lisp side). The semantic oracle (:9999, owned by my-lisp) reports
kebab-case kinds on the wire; contract fixtures use Rust Debug names.
Third-party implementations must map through this table.

| Wire kind (oracle)     | Contract fixture name | Meaning |
|------------------------|-----------------------|---------|
| `arity-error`          | `Arity`               | wrong argument count |
| `type-error`           | `Type`                | operand type mismatch |
| `invalid-form`         | `InvalidForm`         | malformed expression structure |
| `numeric-overflow`     | `NumericOverflow`     | bignum/rational range |
| `division-by-zero`     | `DivisionByZero`      | exact arithmetic received a zero divisor |
| `parse-error`          | `Parse`               | reader or decoder rejected malformed input |
| `unknown-symbol`       | `UnknownSymbol`       | unbound symbol |

Upstream unification tracked in my-lisp; if oracle vocabulary changes,
refresh this table and re-run adversarial fixtures.

The canonical fixture copy is an upstream reference and gap-accounting input.
Its contract 3.0 pin does not claim that fpga-lisp hardware implements every
3.0 error category; backend support must be stated and evidenced separately.

---

# Відображення мережевих типів помилок на словник контракту (Ukrainian)

Вирішує знахідку F2 з `docs/conformance-adversarial-report-2026-08-23.md` 
(з боку `fpga-lisp`). Семантичний оракул (:9999, що належить `my-lisp`) 
повідомляє по мережі типи помилок у форматі kebab-case; фікстури контракту 
використовують імена формату Rust Debug. Сторонні реалізації повинні 
перетворювати (мапити) їх через цю таблицю.

| Мережевий тип (оракул) | Назва у фікстурі контракту | Значення |
|------------------------|----------------------------|----------|
| `arity-error`          | `Arity`                    | неправильна кількість аргументів |
| `type-error`           | `Type`                     | невідповідність типів операндів |
| `invalid-form`         | `InvalidForm`              | неправильна структура виразу |
| `numeric-overflow`     | `NumericOverflow`          | діапазон bignum/раціональних чисел |
| `division-by-zero`     | `DivisionByZero`           | точна арифметика отримала дільник нуль |
| `parse-error`          | `Parse`                    | парсер відхилив неправильний ввід |
| `unknown-symbol`       | `UnknownSymbol`            | незв'язаний (unbound) символ |

Уніфікація апстріму (upstream) відстежується в `my-lisp`; якщо словник 
оракула зміниться, необхідно оновити цю таблицю та повторно запустити 
змагальні (adversarial) фікстури.

Канонічна копія фікстури є апстрім-посиланням (upstream reference) та входом 
для обліку прогалин (gap-accounting). Її прив'язка до контракту версії 3.0 
не стверджує, що апаратне забезпечення `fpga-lisp` реалізує кожну категорію 
помилок 3.0; підтримка бекендом має бути заявлена і доведена окремо.
