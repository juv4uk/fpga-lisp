# my-lisp machine — план розвитку

Мета: FPGA напряму представляє Lisp-об'єкти, виконує базові Lisp-операції
в апаратурі, і зрештою здатна виконувати власний evaluator, написаний
самим Lisp-ом.

```
Lisp-об'єкти
     ↓
tagged words
     ↓
апаратні CAR/CDR/CONS/EQ/ATOM
     ↓
керування виконанням
     ↓
lambda / environment
     ↓
eval
     ↓
Lisp виконує Lisp
```

Кінцева точка першого великого етапу — не швидкість і не повний `my-lisp`,
а:

```lisp
(eval '(car (cons 'a 'b)) env)
=> a
```

де `eval` написаний самим Lisp-ом, а FPGA забезпечує лише фундаментальні
механізми.

## Принципи (конституція машини)

1. Основним об'єктом машини є Lisp value, а не byte.
2. Кожне value має tag.
3. CONS є апаратним об'єктом.
4. CAR/CDR/CONS/ATOM/EQ є апаратними операціями.
5. Lisp-функції зберігаються як Lisp-структури.
6. Середовище є Lisp-структурою.
7. Мова повинна мати можливість реалізувати eval сама.
8. FPGA не повинна знати про Markdown/Mermaid/LaTeX.
9. Вищі можливості my-lisp будуються над мінімальним ядром.

## Машинне слово

32-бітне слово: 4 біти tag + 28 біт value.

```
31                       28 27                       0
+--------------------------+--------------------------+
|          TAG             |          VALUE           |
+--------------------------+--------------------------+
       4 біти                    28 бітів
```

16 можливих типів, у першій версії реалізовано лише:

```
FIXNUM
CONS
SYMBOL
NIL
TRUE
```

Решта (FUNCTION, ENV, CHAR, STRING, RATIONAL, ...) — пізніше.

## Lisp heap

Одна cons-комірка = CAR (32 біт) + CDR (32 біт), як дві паралельні RAM:

```
CAR_RAM[address]
CDR_RAM[address]
```

`(car x)` → `CAR_RAM[payload(x)]`, `(cdr x)` → `CDR_RAM[payload(x)]`.

## Апаратний CONS

Без garbage collector. Один регістр `HP` (heap pointer), bump allocator:

```
CAR_RAM[HP] = A
CDR_RAM[HP] = B
RESULT = CONS_TAG | HP
HP = HP + 1
```

Якщо heap закінчився — `HEAP_FULL`, машина зупиняється. GC — значно пізніше.

## П'ять базових Lisp-операцій

`CONS`, `CAR`, `CDR`, `ATOM`, `EQ` — можна визначити без evaluator.
Модуль: `lisp_data_unit.sv`.

- `CAR`/`CDR`: якщо `TAG == CONS` — читати з RAM, інакше `TYPE_ERROR`.
- `ATOM`: `RESULT = (TAG != CONS)`.
- `EQ`: повне порівняння 32-бітних слів.
- `CONS`: апаратне виділення комірки.

## Мінімальна керуюча машина

ISA — лише спосіб керувати апаратними примітивами (на відміну від
RISC-V, де `cons`/`car`/`cdr` — програмні абстракції, тут вони фізичні
операції процесора):

```
NOP, LOADI, LOADSYM, MOV, CONS, CAR, CDR, ATOM, EQ, JMP, JF, HALT, OUT, IN, ADD, SUB
```

## Регістри

`R0`–`R7` (32 біти), плюс `PC`, `HP`, `SP`, `ENV`, `VAL`. Прозорість
важливіша за елегантність на цьому етапі.

## Перша програма (milestone 0.01)

```
R1 = SYMBOL A
R2 = SYMBOL B
CONS R1 R2 -> R3
CAR R3 -> R4
HALT
```

Результат: `R4 = SYMBOL A`, тобто FPGA фізично виконала
`(car (cons 'a 'b))`.

## UART — вікно всередину машини

Спочатку не REPL, а діагностичний протокол:

```
> dump r4
SYMBOL 00000001

> heap 0
CAR: SYMBOL A
CDR: SYMBOL B

> hp
00000001
```

Опційно — окремий monitor-інструмент на ПК (реєстри, heap, PC, поточна
інструкція, теги).

## Символи

Interned symbols, без зберігання рядків у `LispWord`:

```
SYMBOL #0 -> NIL
SYMBOL #1 -> T
SYMBOL #2 -> A
SYMBOL #3 -> B
SYMBOL #4 -> CAR
```

На FPGA — лише `TAG_SYMBOL | symbol_id`. Таблиця імен існує на ПК; FPGA
не зобов'язана знати, що `#4` друкується як `"CAR"`.

## Списки

`(a b c)` у heap:

```
0: CAR=A  CDR=1
1: CAR=B  CDR=2
2: CAR=C  CDR=NIL
```

Значення списку — `CONS_PTR 0`. Корисний інструмент розробки —
heap-візуалізатор.

## `quote`

На апаратному рівні майже нічого не робить — не обчислювати `a`,
повернути сам об'єкт. Семантика виникає на рівні evaluator, не hardware.

## Середовище

Association list, без спеціального апаратного типу `ENV`:

```lisp
((x . 10) (y . 20) (z . 30))
```

`(lookup 'x env)` пишеться самим Lisp-ом.

## Перші функції, написані Lisp-ом

Щойно з'являється виклик Lisp-коду — виносимо функціональність із
hardware:

```lisp
(defun null? (x) (eq x nil))
(defun second (x) (car (cdr x)))
```

FPGA знає лише `CAR`, `CDR`, `EQ`, `CONS` — і це головний тест
правильної архітектури.

## `cond` і керування виконанням

Не окремий hardware-блок `COND`, а мінімальний механізм `TEST`/`BRANCH`.
Семантику `cond` реалізує evaluator.

## `lambda`

Функція — Lisp-структура (closure): `(parameters body environment)`.
FPGA не має спеціального формату closure — можливо, лише tagged
pointer.

## Власний evaluator

```lisp
(eval expr env)

atom?
    symbol -> lookup
    number -> itself

list?
    quote -> quoted value
    cond  -> evaluate clauses
    lambda ...
    otherwise -> application
```

Спочатку частково в hardware/microcode, потім поступово переписати
Lisp-ом до:

```lisp
(defun eval (expr env) ...)
```

Коли FPGA виконує цей Lisp-код — це вже Lisp Machine.

## Bootstrap

FPGA має лише primitive layer: `CONS/CAR/CDR/ATOM/EQ`, пам'ять,
branching, механізм функцій, цілі числа, I/O. Після старту завантажується
`boot.my`, де: `null?, not, and, or, list, append, assoc, lookup, eval,
apply, ...`. Машина добудовує сама себе після старту.

## Числа

Спочатку `FIXNUM` (signed 28-bit: -134217728…+134217727), потім
`BIGNUM`/`RATIONAL` як Lisp-подібні структури в heap (bignum — масив
limbs; rational — `numerator`/`denominator` як integer/bignum), а не
величезний комбінаторний блок.

## Garbage Collector

Довго — ніяк: `reset → heap порожній`, `CONS → HP++`, `heap full → stop`.
Далі: mark-and-sweep. Пізніше: incremental/generational/hardware-assisted
GC (v2/v3) — тут FPGA дає цікаві можливості (апаратна перевірка
tag/pointer).

**Підтверджено, не лише запланено (2026-08-10, після M26/SETCDR): це має бути
trace-based (mark-and-sweep), а не reference counting, і вибір НЕ довільний.**
my-lisp сама використовує refcounting (`Rc`, `value.rs`'s `impl Drop`), а не
tracing GC — і це працює ТАМ, бо середовище до SETCDR ніколи не мало мутації:
cons-структури лише будуються вперед, ніколи не переприв'язуються заднім
числом, тож цикл посилань фізично не міг виникнути. `SETCDR` (M26) змінює це
рівняння: letrec-подібний bootstrap-механізм (placeholder-комірка
`(name . NIL)`, розширення середовища через неї, побудова closure з цим
середовищем як captured env, тоді `SETCDR` дозаписує placeholder на реальну
closure) **гарантовано** створює цикл — `placeholder → closure → captured_env
→ placeholder` — це не крайній випадок, а сама умова, за якою тіло closure
взагалі може знайти себе через `lookup`. Reference counting **принципово** не
звільняє цикли (A і B тримають одне одного живими назавжди, навіть коли
ззовні ніхто на них не посилається) — тому будь-яка майбутня апаратна
реклаッм-схема для fpga-lisp мусить бути tracing (mark-and-sweep чи новіше),
ніколи refcounting, з моменту, як SETCDR існує в ISA. Сьогодні це не активна
проблема (bump allocator нічого не звільняє незалежно від досяжності), але
рішення "trace-based, не refcounting" тепер фіксоване, не відкрите питання
для GC-мілстоуна (крок 26).

## Пам'ять поза FPGA

Перша Lisp-машина повністю живе у внутрішній FPGA RAM (навіть кілька
тисяч cons-комірок достатньо для bootstrap). Пізніше:

```
FPGA BRAM → cache/young heap → external SDRAM/PSRAM
```

## `my-lisp` ↔ FPGA

Коли hardware стабільний:

```
             my-lisp
                │
         reader / compiler
                │
       Lisp Machine Image
                │
             UART/USB
                │
        ┌───────────────┐
        │     FPGA      │
        │ Lisp CPU      │
        │ Lisp Heap     │
        │ Lisp Runtime  │
        └───────────────┘
```

Rust — інструмент розробника, не runtime.

## Майбутній REPL

```
> (cons 'a 'b)
(a . b)

> (def factorial (lambda (n) ...))
> (factorial 10)
3628800
```

## `reason.my`

Коли базовий Lisp стабільний — перенести `unify.my`/`reason.my` без
спеціальної логічної апаратури. Пізніше можна дослідити апаратний
`UNIFY hardware unit`.

## Не прив'язувати Markdown/Mermaid/LaTeX до hardware

FPGA повинна знати: symbols, lists, trees, relations, numbers, functions.
`my-lisp` перетворює `Markdown → Lisp tree`, `Mermaid → Lisp graph`,
`LaTeX → Lisp expression` — фундамент лишається чистим.

## Цільова структура репозиторію

```
fpga/
├── rtl/
│   ├── lisp_machine.sv
│   ├── lisp_word.sv
│   ├── lisp_alu.sv
│   ├── lisp_data_unit.sv
│   ├── heap.sv
│   ├── registers.sv
│   ├── control.sv
│   ├── instruction_decoder.sv
│   └── uart.sv
├── sim/
│   ├── tb_heap.sv
│   ├── tb_cons.sv
│   ├── tb_car_cdr.sv
│   └── tb_machine.sv
└── boot/
    ├── boot.mem
    └── boot.my

docs/
├── lisp-machine.md        (принципи, коротко)
├── lisp-machine-plan.md   (цей файл)
├── architecture.md
├── tagged-word.md
├── memory.md
└── isa.md
```

## Практичний roadmap (без стрибків через сходинки)

1. Tagged `LispWord`.
2. BRAM heap.
3. `CONS`.
4. `CAR`.
5. `CDR`.
6. `ATOM`.
7. `EQ`.
8. Регістри.
9. Control unit.
10. Маленька ISA.
11. `(car (cons 'a 'b))`.
12. UART/debug monitor.
13. Списки.
14. Symbol table.
15. Branching.
16. Function calls.
17. Environment.
18. `lambda`.
19. `cond`.
20. evaluator.
21. evaluator, написаний Lisp.
22. bootstrap `core.my`.
23. integers.
24. recursion.
25. rational/bignum.
26. GC.
27. повноцінний REPL.
28. `my-lisp` conformance.
29. `unify.my`.
30. `reason.my`.

Наступна велика сходинка не починається, доки попередня не має тесту:

```
M01 TAG        PASS
M02 HEAP       PASS
M03 CONS       PASS
M04 CAR/CDR    PASS
M05 ATOM/EQ    PASS
M06 LIST       PASS
M07 CONTROL    PASS
...
```

## Milestone 0.01

```lisp
(car (cons 'a 'b))
```

FPGA фізично: виділяє cons-cell у BRAM, записує A в CAR і B у CDR,
читає CAR і отримує A. Далі:

```lisp
(cdr (cons 'a 'b)) => b
(atom 'a) => t
(atom (cons 'a 'b)) => nil
(eq 'a 'a) => t
```

Після цих чотирьох тестів — git tag `lisp-machine-v0.01`.

## Поточний стан проєкту відносно плану

- ✅ Tagged word ([lisp_word.sv](../fpga/rtl/lisp_word.sv)): FIXNUM/CONS/SYMBOL/NIL/TRUE.
- ✅ Heap + bump allocator ([heap.sv](../fpga/rtl/heap.sv), [lisp_data_unit.sv](../fpga/rtl/lisp_data_unit.sv)).
- ✅ CONS/CAR/CDR/EQ/ATOM реалізовані ([control.sv](../fpga/rtl/control.sv)).
- ✅ Control unit + мінімальна ISA ([control.sv](../fpga/rtl/control.sv), [instruction_decoder.sv](../fpga/rtl/instruction_decoder.sv)).
- ✅ `LOADSYM` — окремий опкод для завантаження символів з тегом.
- ✅ `(car (cons 'a 'b))` проходить у симуляції (`tb_machine.sv`, MILESTONE 0.03) і прошито на плату.
- ✅ M05 (`ATOM`/`EQ`) проходить у симуляції ([tb_atom_eq.sv](../fpga/sim/tb_atom_eq.sv)) і прошито на плату.
- ✅ UART-monitor (крок 12): після `HALT` машина переходить у режим команд — бінарний протокол `REG <idx>` / `HEAP <lo> <hi>` / `HP` читає регістри, heap і heap-pointer через UART ([control.sv](../fpga/rtl/control.sv), [lisp_data_unit.sv](../fpga/rtl/lisp_data_unit.sv) `cmd_peek`). M08 у [tb_monitor.sv](../fpga/sim/tb_monitor.sv) — PASS. Навмисно бінарний, а не текстовий: за тим самим принципом, що й interned symbols (Етап 9) — FPGA не повинна знати ASCII/hex-парсинг, це відповідальність PC-інструменту.
- ❌ Немає окремих тестів `tb_heap.sv`/`tb_car_cdr.sv` (M01/M02/M04) — покриття є лише через `tb_cons.sv` і `tb_machine.sv`.
- ❌ Немає git tag `lisp-machine-v0.01` / `v0.02` — усі базові примітиви (CONS/CAR/CDR/ATOM/EQ) вже готові й перевірені, час тегувати.
- ✅ Branching (M07 CONTROL): `JMP`/`JF` перевірені циклом (countdown) — [tb_control.sv](../fpga/sim/tb_control.sv), PASS. ISA 1.0 додатково фіксує G8-семантику: `JF` переходить лише для `NIL`, а fixnum `0` є truthy — [tb_jf_truthiness.sv](../fpga/sim/tb_jf_truthiness.sv).
- ✅ Списки (M06 LIST): 3-елементний список `(radio antenna signal)` побудований через ланцюжок `CONS` і пройдений `CAR`/`CDR` до `NIL` — [tb_list.sv](../fpga/sim/tb_list.sv), PASS.
- ❌ Symbol table на ПК (interned names ще не мають друку в жодному host-інструменті).
- ✅ Function calls (M09 CALL/RET): опкодний простір повністю зайнятий (16/16), тож `CALL`/`RET` перевикористовують `OP_JMP` за принципом RISC-V JAL/JALR — `rd≠0,rs1=0` пише адресу повернення в `rd` і стрибає (CALL), `rd=0,rs1≠0` стрибає за адресою з `rs1` (RET). [tb_call.sv](../fpga/sim/tb_call.sv), PASS. Апаратного call-стеку немає — глибина вкладених викликів обмежена кількістю вільних регістрів для link-адрес.
- ✅ Environment (M10): `((x . 10) (y . 20))` побудовано як alist через `CONS` (без окремого апаратного типу ENV — точно за планом), і рукописна підпрограма `lookup` (CAR/CDR/EQ-цикл + CALL/RET) знаходить значення за ключем. [tb_env.sv](../fpga/sim/tb_env.sv), PASS. `lookup` поки написана вручну асемблером, не самою Lisp (бо ще немає читача/eval) — це наступний розрив.
- ✅ `lambda` (M11): closure представлений як `(params . (body . env))` — чиста CONS-структура, без апаратного типу. "Виклик" будує нове середовище (`(param . arg) . env`) і `lookup` підтверджує прив'язку параметра. [tb_lambda.sv](../fpga/sim/tb_lambda.sv), PASS. Тіло (`body`) — лише символ-заглушка, не виконується (для цього потрібен `eval`, наступний крок).
- ❌ `cond` / evaluator — не почато. Розбито на під-кроки нижче.

### Розбивка eval (M12–M15)

`eval` — надто великий крок, щоб робити одразу. Опкодний простір зайнятий
на 100%, тож `eval` буде asm-підпрограмою поверх наявних примітивів
(CONS/CAR/CDR/EQ/ATOM/CALL/RET), а не новою інструкцією. Без reader —
вираз (`expr`) і надалі вручну закодований у heap через asm, як ми
робили з closures в M11.

- **M12 eval-atom**: `eval(expr, env)` лише для атомів — символ шукається
  в `env` через наявний `lookup` (M10), не-символ (fixnum/nil/true)
  повертається як є. Це перший реальний виклик `eval` як підпрограми.
- **M13 eval-quote**: розпізнати форму `(quote x)` — якщо `car(expr)`
  дорівнює символу `'quote` (через `EQ`), повернути `car(cdr(expr))`
  без обчислення. Перший test на `atom?`/`cons?`-розгалуження всередині
  `eval` (диспетчеризація по формі виразу).
- **M14 eval-cond**: розпізнати `(cond (t1 v1) (t2 v2) ...)` — ітерація
  по клаузах, `eval` тесту, якщо truthy — `eval` і повернути відповідне
  значення. Перший цикл всередині `eval` (не лише прямий dispatch).
- **M15 eval-apply**: аплікація `(f arg1 arg2 ...)` де `f` — closure з
  M11 — обчислити аргументи, зв'язати параметри (`extend-env` з M11),
  рекурсивно викликати `eval` тіла в новому середовищі. Тут `eval`
  вперше викликає сам себе через `CALL`/`RET` — перевірка того, що
  наш call-механізм витримує рекурсію без апаратного call-стеку.

- ✅ **M12 eval-atom готовий**: символ → `lookup` в `env`, fixnum → self-evaluating. Знадобився новий "безкоштовний" режим: `GETTAG rd,rs1` — той самий опкод, що й `MOV` (поле `rs2`, яке `MOV` ігнорував, тепер = 1 означає "дай тег `rs1` як fixnum"), бо опкодний простір зайнятий на 100%, а без інспекції тегу `eval` не міг би розрізнити символ від fixnum. [tb_eval_atom.sv](../fpga/sim/tb_eval_atom.sv), PASS. `eval` і `lookup` навмисно використовують неперетинні набори регістрів (R3-R9 vs R0-R2/R12-R15) — без апаратного call-стеку це єдиний спосіб уникнути затирання стану при вкладеному виклику.

- ✅ **M13 eval-quote готовий**: `eval` тепер розгалужується через `ATOM` (символ/fixnum vs cons), а для cons-виразів перевіряє `car(expr) == 'quote` (через `EQ`) і повертає `car(cdr(expr))` без обчислення — інші форми поки падають у безпечний `NIL`. [tb_eval_quote.sv](../fpga/sim/tb_eval_quote.sv), PASS. Це буквально перша фікстура `conformance.my`: `(quote radio) => radio`.

- ✅ **M14 eval-cond готовий**: `eval` розпізнає `(cond (t1 v1) (t2 v2) ...)` й ітерує клаузи. Це перша справжня **самореференція** — `eval` рекурсивно викликає сам себе (для `test` і для `value` кожної клаузи), а фіксований регістровий фрейм цього не витримує (рекурсивний виклик перезаписує ті самі регістри). Розв'язання: програмний call-стек із звичайних `CONS`-комірок — `R11` як вказівник вершини стеку, `push(v)`: `R11=CONS(v,R11)`, `pop`: `v=CAR(R11); R11=CDR(R11)`. Усе, що рекурсивний виклик міг би затерти (власна адреса повернення, курсор клауз, поточна клауза), заштовхується перед викликом і виштовхується після — сама купа стає відсутнім апаратним call-стеком. [tb_eval_cond.sv](../fpga/sim/tb_eval_cond.sv), PASS. Відтворює `(cond (() 'wrong) (t 'right)) => right` з `conformance.my` (значення клаузи — `(quote right)`, а не голий символ, бо голий символ `eval` шукав би як змінну — саме так, як реально працює reader-макрос `'x`).

- ✅ **M15 eval-apply готовий — перший великий етап плану закрито**: `eval` тепер обробляє аплікацію `(f arg)`, де `f` обчислюється до closure з M11: `eval(operator)`, `eval(arg)` (обидва рекурсивно), зв'язування параметра через розширення захопленого середовища closure, і рекурсивний `eval(body, new_env)` — третій рекурсивний виклик у цьому мільстоуні, той самий CONS-стек з M14. Тест: `(identity 42)` де `identity` — closure-тотожність `(n . (n . NIL))`, зв'язана в зовнішньому середовищі — проходить усі чотири шляхи `eval` в одному виразі (self-eval, lookup оператора, lookup параметра всередині виклику, аплікація). [tb_eval_apply.sv](../fpga/sim/tb_eval_apply.sv), PASS.
  - Підтримується лише один фіксований параметр (як у M11's closure). Аплікація примітивів (`car`/`cons` як функції всередині виразу, а не апаратні опкоди) не реалізована — буквальний `(eval '(car (cons 'a 'b)) env) => a` з Етапу 1 плану вимагав би або базового середовища з примітивами-як-closures, або окремого механізму диспетчеризації "примітивна процедура vs closure" в `eval`. Це залишається за межами M15, природний наступний крок.

- ✅ **M16 eval-primitive-apply готовий — буквальна мета Етапу 1 досягнута**: додано тег `TAG_PRIMITIVE=5` і два нових режими `MOV` (`MAKEPRIM`: fixnum→PRIMITIVE зі збереженням value; `GETVAL`: будь-який тег→fixnum зі збереженням value) — та сама техніка, що й `GETTAG`. Базове середовище тепер може зв'язувати `'car`/`'cons` з PRIMITIVE-маркерами замість closures; `eval`'s `try_apply` перевіряє тег обчисленого оператора і при `TAG_PRIMITIVE` диспетчерить напряму на апаратні `CAR`/`CONS` замість очікування структури closure. [tb_eval_primitive.sv](../fpga/sim/tb_eval_primitive.sv) (190 інструкцій, читається напряму з `.bin` через `$fread`, а не вручну переноситься в hex) підтверджує: **`(eval '(car (cons 'a 'b)) env) => a`** — точно та кінцева точка, яку Етап 1 документа ставив за мету.
  - Знайдений і виправлений баг: жадібне видобування другого аргументу (`arg2_expr = car(args_rest)`) падало в вічне очікування, коли викликана функція мала лише ОДИН аргумент (`args_rest = NIL`, а `CAR(NIL)` — апаратна помилка типу без відновлення). Виправлено перевіркою через `ATOM` перед видобуванням.

- ✅ **M17 error recovery готовий**: тип-помилка `CAR`/`CDR`/`CONS` (наприклад, `CAR` не-CONS) раніше викликала вічне очікування в `ST_WAIT_LDU` (`ldu_error` встановлювався, але `ldu_valid` ніколи не приходив) — це двічі коштувало часу на відладку під час розробки `eval` (M12, M16). Тепер `ST_WAIT_LDU` при `ldu_error` переходить у `ST_HALT` замість вічного очікування, а нова команда монітора `0x04` (`ERR`) повертає `{err_flag, err_pc}` — можна діагностувати, а не просто зависати. Стан-машину розширено з 4 до 5 біт (`logic [4:0]`) — це суто внутрішнє кодування станів, ISA не займає жодного нового опкоду. [tb_error_recovery.sv](../fpga/sim/tb_error_recovery.sv), PASS.

- ✅ **M18 eval-all-primitives готовий**: розширює диспетчеризацію примітивів M16 (`car`,`cons`) на решту трьох апаратних операцій — `cdr`,`atom`,`eq`. Разом M16+M18 роблять усі п'ять апаратних примітивів викликаними з `eval` як звичайні процедури в базовому середовищі. Тест: `(eq (atom (cdr (quote (a . b)))) (atom (quote c))) => TRUE`. [tb_eval_all_primitives.sv](../fpga/sim/tb_eval_all_primitives.sv), PASS.
  - Реальне апаратне обмеження виявлено по дорозі: перша версія (усі 5 примітивів в одній програмі) дала 266 інструкцій — **більше за 256-слівну `imem`** (і 255-байтний ліміт довжини завантажувача). Довелось звузити M18 до трьох примітивів, яких бракувало після M16, і будувати тестову пару `(a . b)` напряму апаратним `CONS` замість виклику `cons` як процедури. Це перше реальне зіткнення з лімітом розміру програми — вартий згадки орієнтир на майбутнє.

- ✅ **imem розширено 256→4096 слів (PC 8→12 біт)**: M18 наочно показав межу в 256 слів (тест ледь не переріс її). `control.sv` (`pc`, цілі `JMP`/`JF`/`CALL`/`RET` через `imm[11:0]`), `lisp_machine.sv` (`imem[0:4095]`), `bootloader.sv` (довжина програми тепер 2 байти little-endian, до 4095 інструкцій) — усі оновлені. `assembler.py` без змін (immediate вже 16-біт), `upload.py`/`monitor.py` — ліміт 255→4095 і 2-байтний префікс довжини. Обрано 12, а не 16/32 біт: BRAM-бюджет плати — 56 блоків по 16 Кбіт; heap уже займає 16 блоків, imem на 256 слів — 1 блок. Розрахунок з реальних чисел синтезу: 4096 слів → 8 блоків (разом 24/56=43%, підтверджено `impl/pnr/project.rpt.txt`); 16-бітний PC (65536 слів) сам по собі вимагав би 128 блоків — більше, ніж уся плата має. Усі 16 тестбенчів (протокол довжини оновлено на 2 байти) — PASS.

- ✅ **Перевірено на реальному залізі**: `(eval '(car (cons 'a 'b)) env) => a` (M16) підтверджено фактичним запуском на платі через `monitor.py`, не лише в симуляції. По дорозі виправлено три окремі проблеми, які раніше маскувалися тим, що всі перевірки робились лише в симуляції:
  1. **Відсутнє обмеження таймінгу** — жодного `.sdc`-файлу не було, синтезатор ніколи не перевіряв timing closure на 50 МГц (попередження `TA1132` ігнорувалось з першого дня). Додано [fpga/synth/lisp_machine.sdc](../fpga/synth/lisp_machine.sdc); зараз `Fmax=64.6 МГц`, `TNS=0` — запас є.
  2. **Застарілі байти в буфері `pyserial`** — `reset_input_buffer()` не завжди спрацьовує одразу через затримку драйвера ОС ([pyserial#344](https://github.com/pyserial/pyserial/issues/344)), тож перший запит монітора "з'їдав" сміттєвий байт і зсував усі наступні 4-байтні відповіді. Виправлено в `monitor.py` — коротка пауза перед скидом буфера.
  3. **Ненадійна фізична кнопка Reset** — між двома послідовними запусками `monitor.py` bootloader іноді не скидається, і другий upload "проковтується" моніторним циклом попереднього запуску (замість завантаження нової програми зчитуються старі регістри). Найнадійніший обхід — перепрошити SRAM (гарантований апаратний скид через GSR) між незалежними тестовими сесіями, а не покладатись на кнопку.

- ✅ **M19 — перший bootstrap готовий**: `null?` — перша функція, буквально перенесена з `docs/reference/my-lisp-lib/core.my` (`(defun null? (x) (eq x nil))`) — представлена як closure (M11), чиє тіло викликає апаратний примітив `eq` (M16/M18), застосована (M15) до `NIL` і до `(quote a)`. Нічого нового в залізі чи в `eval` — перше корисне навантаження, зібране повністю з уже перевірених частин. [tb_bootstrap_nullp.sv](../fpga/sim/tb_bootstrap_nullp.sv), PASS.
  - Знайдений і виправлений баг **у самому тестбенчі** (не в RTL!): результат `test1` тимчасово клали в `R8`, а потім `test2` (окремий, повноцінний виклик `eval`) використав `R8` як звичайний скретч-регістр і затер його ще до фінальної перевірки. Той самий урок, що й раніше з `outer_env` (M12-15) — тепер застосований і до **власного результату виклику**: будь-яке значення, яке має пережити ще один top-level виклик `eval`, обов'язково йде через `push`/`pop` на стеку `R11`, бо жоден регістр інакше не гарантовано вцілів.

- ✅ **M20 — друга bootstrap-функція**: `second` з `core.my` (`(lambda (values) (car (cdr values)))`) — інший патерн композиції, ніж M19's `null?`: тіло closure ланцюжком викликає ДВА примітиви (`car` над результатом `cdr`), а не один примітив напряму над параметром. Застосовано до `(quote (x y z))` → `y`. [tb_bootstrap_second.sv](../fpga/sim/tb_bootstrap_second.sv), PASS.

- ✅ **M21 — третя bootstrap-функція**: `not` з `core.my` (`(cond (value '()) (t t))`) — перше тіло closure, побудоване з `cond` (спецформа), а не аплікації примітиву; captured env може бути `NIL`, бо тілу нічого шукати. `t` вбудований напряму як літерал `TRUE`, а не через символьний lookup — той самий підхід, що й з `NIL`-літералами раніше. `(not NIL) => TRUE`, `(not (quote a)) => NIL`. [tb_bootstrap_not.sv](../fpga/sim/tb_bootstrap_not.sv), PASS.

- ✅ **M22 — двопараметричні closures**: подолано межу з розділу 9.3 незалежного огляду — `pair` з `core.my` (`(lambda (left right) (cons left (cons right '())))`) стала першою **двоаргументною** closure. `params` тепер або одиничний символ (як M11-M21), або 2-елементний список `(param1 param2)`, розрізнювані через `ATOM(params)`. `do_closure_apply` отримав другу гілку: обчислює ОБИДВА жадібно видобуті вирази аргументів (та сама схема з `try_apply`, що вже обслуговує `cons`/`eq`) і зв'язує обидва параметри через дворазове розширення захопленого середовища. `(pair 'a 'b) => (a b)` (список, не dotted pair!). [tb_bootstrap_pair.sv](../fpga/sim/tb_bootstrap_pair.sv), PASS.
  - Знайдений і виправлений баг **у побудові тестових даних** (не в новій логіці `do_closure_apply`): список `params` спершу зібрався у зворотному порядку (`(right left)` замість `(left right)`) через класичну помилку "CONS напряму дає reversed order" — та сама пастка, що вже траплялась з символьними списками раніше.
  - N-арні (3+) closures лишаються поза межами: поточна схема "жадібно видобути 2 вирази" в `try_apply` капітулює на третьому аргументі; для довільної арності знадобиться список аргументів довільної довжини й цикл зв'язування, а не фіксована пара `arg1_expr`/`arg2_expr`.

- ✅ **M23 — `caar`**: той самий патерн композиції, що й M20's `second` (два ланцюжкові виклики примітиву), але обидва — `car` замість `car`+`cdr`. `(caar '((x y) z)) => x`. [tb_bootstrap_caar.sv](../fpga/sim/tb_bootstrap_caar.sv), PASS.

- ✅ **Технічний борг: `.include`/`.define` в асемблері**. Кожен bootstrap-тест дублював ~150-200 рядків `eval`+`lookup` і винаходив свої числові ID для `'quote`/`'cond` — саме та причина двох знайдених багів (M19, M22). `assembler.py` тепер підтримує `.include "path"` (рекурсивне вбудовування файлів) і `.define NAME VALUE` (іменована константа без прив'язки до PC-адреси). [fpga/asm/constants.inc](../fpga/asm/constants.inc) централізує `SYM_QUOTE`/`SYM_COND`/`PRIM_*`; [fpga/asm/eval_core.inc](../fpga/asm/eval_core.inc) — канонічна версія `eval`+`lookup` (найповніша, з M22: усі 5 примітивів + 1/2-параметричні closures). `bootstrap_caar_demo.asm` і `bootstrap_second_demo.asm` переписані на `.include` (58-66 рядків замість ~180-230) і досі проходять ті самі тестбенчі — підтверджена регресія.

- ✅ **M24 — N-арні closures**: усунуто обмеження, зазначене наприкінці M22 — `try_apply` більше не видобуває жадібно до двох аргументів заздалегідь; замість цього зберігає весь необчислений список аргументів (`args = cdr(expr)`) через `R11`-стек, поки обчислюється оператор, і лише **потім**, знаючи, чи оператор — примітив (капіталізовано на двох операндах в апаратурі) чи closure, вирішує, скільки аргументів видобути. `do_closure_apply` отримав справжній цикл зв'язування (`closure_nary`/`nary_loop`/`nary_bind`/`nary_done`), що йде по `params` і `args` одночасно, розширюючи акумулююче середовище на кожній парі — жодного жорсткого ліміту на кількість параметрів. Однопараметрична гілка (голий символ, `M11`) лишилась незмінною; `pair` з M22 (2 параметри) тепер проходить через цей самий загальний цикл, а не окрему `closure_2arg`-гілку. Новий тест `bootstrap_triple_demo.asm`: `(lambda (a b c) (cons a (cons b c)))` застосована до `('x 'y 'z)` → `(x y . z)` — перше реальне підтвердження N>2. [tb_bootstrap_triple.sv](../fpga/sim/tb_bootstrap_triple.sv), PASS; `tb_bootstrap_caar.sv` (M23), `tb_bootstrap_second.sv` (M20), `tb_bootstrap_pair.sv` (M22) — усі перевірені на регресію, PASS.
  - Знайдений і виправлений баг: після переписування `try_apply`/`do_closure_apply` в кожній гілці диспетчеризації примітиву (`car`/`cdr`/`atom`/`eq`/`cons`) лишився зайвий `CAR R10,R11 / CDR R11,R11` — залишок старого дизайну, де `arg2_expr` заштовхувався в стек ще ДО виклику `eval` над оператором. У новому дизайні `arg2_expr` видобувається з уже збереженого `args`-списку в звичайний регістр `R8` вже ПІСЛЯ того, як оператор обчислено — стек тут узагалі не потрібен. Зайвий `pop` крав чужий елемент зі стеку, ламаючи все, що йшло після нього. Ще один приклад того самого правила, що й M19/M22, але в новому вигляді: небезпечний не лише *відсутній* push/pop, а й **застарілий**, що лишився від попередньої версії коду.

- ✅ **M25 — `third`**: той самий однопараметричний ланцюжок примітивів, що й M20's `second`/M23's `caar`, ще на крок глибший — `cdr`, потім `cdr` знову, потім `car`. `(third '(w x y z)) => x` (третій елемент, нульова індексація). [tb_bootstrap_third.sv](../fpga/sim/tb_bootstrap_third.sv), PASS.

- ✅ **M26 — `SETCDR`**: внутрішня, лише для bootstrap, можливість мутувати cdr наявної cons-комірки на місці — єдиний свідомий виняток з "heap ніколи не мутується після виділення `CONS`". Реалізовано як `ATOM` з `rs2 != 0` (opcode-простір зайнятий на 100%, той самий прийом, що й `GETTAG`/`MAKEPRIM`/`GETVAL`). [tb_setcdr.sv](../fpga/sim/tb_setcdr.sv), PASS. Підтверджений наслідок для GC: див. розділ "Garbage Collector" нижче — з моменту існування `SETCDR` цикли посилань стають можливими, тож майбутній GC мусить бути trace-based, ніколи refcounting.

- ✅ **M27 — апаратний `ADD` як callable-примітив**: той самий патерн, що й M16/M18 для `car`/`cdr`/`cons`/`atom`/`eq` — передумова для будь-якої самореференційної функції `core.my`, що використовує `+`. `(plus 3 4) => 7`. [tb_bootstrap_add.sv](../fpga/sim/tb_bootstrap_add.sv), PASS.

- ✅ **M28 — `letrec`-механізм самореференційної рекурсії закритий, підтверджено реальним прогоном (2026-08-11)**: тимчасова ретракція нижче (2026-08-11, раніше цього ж дня) виявилась хибною тривогою — сам `letrec`/`SETCDR`-механізм працює коректно з першого разу; реальний баг, знайдений тим прогоном, був у ТЕСТОВОМУ КОДІ demo-файлу, не в еval-машині. `bootstrap_length_demo.asm` передавав тестові дані `(a b c)` як аргумент виклику `(length (a b c))` БЕЗ `(quote ...)` — а аргументи виклику функції завжди обчислюються (`do_closure_apply`'s bare-symbol шлях робить `CALL R5, eval` на кожному arg-виразі), тож `(a b c)` намагалось застосувати символ `'a` як оператора. Необмежений `lookup` тихо доходив до `NIL`, `CAR` на `NIL` — LDU type-error, halt зі сміттєвими значеннями в регістрах (звідси спостережений `R9 = symbol 'lst`). Усі попередні bootstrap-демо (`bootstrap_second_demo.asm`, `bootstrap_pair_demo.asm`, `bootstrap_triple_demo.asm`) коректно обгортають літеральні тестові списки в `(quote ...)` — саме цієї обгортки бракувало тут. Виправлено обгортанням у `(quote (a b c))`; повторний прогін: `R9 = TAG:FIXNUM VAL:3`, `M28 PASSED`. [tb_bootstrap_length.sv](../fpga/sim/tb_bootstrap_length.sv), [bootstrap_length_demo.asm](../bootstrap_length_demo.asm).
  - Урок про процес: "верифіковано вручну трасуванням регістрів" ≠ "верифіковано реальним прогоном" — саме розбіжність між цими двома вперше й виявила баг, коли нарешті стало можливо прогнати справжній `iverilog`. Ручний трейс легко пропускає помилки саме такого класу (пропущений `quote`), бо семантично "виглядає правильно" при побіжному читанні asm-коментарів.
  - Оригінальний запис нижче (для історії) лишається чинним по суті механізму: розв'язує архітектурну межу, знайдену після M25 (нижче — оригінальна нотатка, для історії) — механізм. Placeholder-пара `(name . NIL)` розширює нову env-рамку (`new_env`), closure будується з `new_env` як captured env, тоді `SETCDR` (M26) дозаписує placeholder на реальну closure — свідомо створюючи цикл `ph_pair -> closure -> new_env -> ph_pair`, завдяки якому тіло closure знаходить **саме себе** через звичайний `lookup`, без жодних змін у самому `eval`/`lookup`. [tb_bootstrap_length.sv](../fpga/sim/tb_bootstrap_length.sv), [bootstrap_length_demo.asm](../bootstrap_length_demo.asm).
  - **Звірено з my-lisp (2026-08-11) і виявлено розбіжність**: `length` у цьому прикладі — `(cond ((atom lst) 0) (t (add 1 (length (cdr lst)))))`, НЕ хвостово-рекурсивна форма. Канонічний `length` у `lib/core.my` — взаємно рекурсивна пара через акумулятор (`length` викликає `length-onto`, яка викликає **сама себе** хвостово): `(def length-onto (lambda (values acc) (cond ((atom values) acc) (t (length-onto (cdr values) (+ acc 1))))))`, `(def length (lambda (values) (length-onto values 0)))`. Обидві форми дають однаковий результат для коротких списків (`(length '(radio antenna signal)) => 3`, підтверджено проти `tests/fixtures/conformance.my` fixture #37), але канонічна форма не нарощує глибину call-стеку з довжиною списку, а спрощена — нарощує. **M28 доводить сам механізм `letrec`, не повну відповідність `core.my`** — bootstrap канонічної взаємно-рекурсивної хвостової форми (два letrec-зв'язані closures, що посилаються одна на одну) лишається наступним кроком, ще не зробленим.
  - Truthy-семантика ISA 1.0 відповідає my-lisp G8: лише `NIL` — falsy, усе інше truthy, включно з fixnum `0`. Окремий RTL gate — [tb_jf_truthiness.sv](../fpga/sim/tb_jf_truthiness.sv).
  - Оригінальна нотатка про межу (для історії): перегляд решти `core.my` для наступних кандидатів bootstrap (`list`, `length`, `reverse`, `append`, `map`, `filter`, `reduce`) показав, що майже всі вони або variadic, або рекурсивно викликають самі себе за іменем — а `eval` цього не витримувала: closure захоплює `env` у момент створення, і без мутації немає способу тілу знайти самого себе. Розв'язано саме через `SETCDR`, а не через окремий "global env"-регістр — обидва варіанти розглядались, `SETCDR`-backpatch обрано, бо повторно використовує вже наявний механізм розширення середовища (M10/M11), а не додає нову структуру.
  - `list`/`reverse`/`append`/`map`/`filter`/`reduce` (variadic-параметричні, а не лише самореференційні) лишаються за межами M28 — наступний природний крок. Взаємно-рекурсивна хвостова форма `length`/`length-onto` — див. M29 нижче.

- ✅ **M29 — канонічна хвостово-рекурсивна, взаємно-рекурсивна `length`/`length-onto` пара, підтверджено реальним прогоном (2026-08-11)**: рівно те, чого бракувало M28 для повної відповідності `core.my`. Два letrec-плейсхолдери (`ph_onto`, `ph_length`) розширюють один спільний env-фрейм до побудови обох closures, тож кожна знаходить і себе, і одна одну через `SETCDR`-backpatch. `length-onto` вперше в bootstrap-демо використовує n-arity параметри `(values acc)` (шлях `closure_nary` в `eval_core.inc`, а не однопараметровий bare-symbol шлях M28). Мав ту саму помилку "забутий `quote`", що й M28 — виправлено паралельно тим самим фіксом. `(length '(a b c)) => 3` через три хвостові виклики `length-onto`. [tb_bootstrap_length_onto.sv](../fpga/sim/tb_bootstrap_length_onto.sv), [bootstrap_length_onto_demo.asm](../bootstrap_length_onto_demo.asm).

- ✅ **M30 — `reverse`/`reverse-onto` з `core.my`, підтверджено реальним прогоном з першого разу (2026-08-11)**: другий приклад тієї самої взаємно-рекурсивної letrec-пари (`reverse-onto`/`reverse`, замість `length-onto`/`length`), і перший bootstrap-приклад, чий результат — CONS-структура (список), а не fixnum, тож [tb_bootstrap_reverse.sv](../fpga/sim/tb_bootstrap_reverse.sv) вперше перевіряє відповідь через прямий обхід `car_ram`/`cdr_ram` (той самий патерн, що й `tb_bootstrap_pair.sv`), а не читання одного регістра. Урок M28/M29 про обов'язковий `quote` літеральних тестових даних застосовано з самого початку — жодного циклу "помилково PASSED → retraction → фікс" цього разу, `M30 PASSED` з першого реального прогону: `(reverse '(a b c)) => (c b a)`. [bootstrap_reverse_demo.asm](../bootstrap_reverse_demo.asm).
- ✅ **M31 — `append` з `core.my`, підтверджено реальним прогоном з першого разу (2026-08-12)**: `(def append (lambda (left right) (reverse-onto (reverse left) right)))` — на відміну від M28-M30, НЕ самореференційний, тож жодного третього letrec-плейсхолдера не знадобилось: звичайний двопараметровий closure, що знаходить `reverse`/`reverse-onto` звичайним lexical lookup через свій captured env (той самий фрейм, де M30 їх уже прив'язав через letrec). `(append '(a b) '(c d)) => (a b c d)` — перевірено обходом `car_ram`/`cdr_ram` (4 комірки), `M31 PASSED` з першого реального прогону, і додатково звірено проти my-lisp TCP `--protocol=sexpr` oracle (`(response (id 2) (status ok) (value (a b c d)) ...)`) — точний збіг. [tb_bootstrap_append.sv](../fpga/sim/tb_bootstrap_append.sv), [bootstrap_append_demo.asm](../bootstrap_append_demo.asm).

Кожен крок — окремий тестбенч (M12→M15), як і всі попередні. Після
M15 маємо мінімальний робочий `eval` для підмножини `my-lisp`
(atom/quote/cond/apply без `lambda`-визначення через `def`, без macro,
без чисел за межами fixnum) — це вже відповідає кінцевій точці "Етапу 1"
з докс: `(eval '(car (cons 'a 'b)) env) => a`.
