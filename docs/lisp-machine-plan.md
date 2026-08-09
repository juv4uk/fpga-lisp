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
- ✅ Branching (M07 CONTROL): `JMP`/`JF` перевірені циклом (countdown) — [tb_control.sv](../fpga/sim/tb_control.sv), PASS.
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

Кожен крок — окремий тестбенч (M12→M15), як і всі попередні. Після
M15 маємо мінімальний робочий `eval` для підмножини `my-lisp`
(atom/quote/cond/apply без `lambda`-визначення через `def`, без macro,
без чисел за межами fixnum) — це вже відповідає кінцевій точці "Етапу 1"
з докс: `(eval '(car (cons 'a 'b)) env) => a`.
