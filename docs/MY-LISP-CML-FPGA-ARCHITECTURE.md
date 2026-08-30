# my-lisp, CML, and fpga-lisp: one semantic system

Status: architecture analysis, 2026-08-24. This document records the
relationship observed in the three live repositories; machine-readable
contracts remain authoritative over this prose.

## Roles

```text
my-lisp    defines what a program means
CML        lowers that meaning into executable forms
fpga-lisp  physically executes one of those forms
```

`my-lisp` is the semantic authority. CML is the integration point, not a
second definition of Lisp. `fpga-lisp` is both an ISA target for CML AOT
programs and an independent hardware evaluator. Those two FPGA roles must
remain distinguishable:

```text
CML -> assembly -> fpga-lisp ISA     compiled execution
Lisp data -> hardware eval/apply     independent semantic implementation
```

The first path tests the compiler. The second tests the universality of the
language and prevents CML and the FPGA backend from agreeing on the same
incorrect interpretation.

## Current contract boundary

| Component | Declared boundary | Observed state |
|---|---|---|
| my-lisp | language contract 3.0 | semantic source of truth |
| CML | language 2.0, partial capability admission from 2.1 | common IR, C and FPGA emitters |
| fpga-lisp | ISA 1.1 | 32-bit tagged Lisp machine with extended register-input frame |
| CML -> FPGA | language 2.0 / ISA 1.1 | real assembler, transport, and hardware path |

The FPGA path already supports tagged values, a 4096-cell cons heap, a
4096-word program image, sixteen registers, the McCarthy primitives,
ADD/SUB, control flow, calls, closures, lexical environments, variadic
arguments, recursive definitions, and compiled examples including
`reverse`, `append`, and structural `equal?`.

## Target architecture

```text
                     my-lisp
              versioned language contract
                         |
                 canonical fixtures
                         |
                         v
                  CML semantic IR
                         |
             analysis + representation
              +----------+----------+
              |                     |
          C runtime          FPGA machine IR
                                    |
                           register allocation
                                    |
                            shared execution ABI
                                    |
                              fpga-lisp ISA
                                    |
                                  RTL
```

GPU and FPGA dataflow work belongs beside this path, not inside the language
semantics:

```text
CML semantic IR
  +-- general Lisp lowering -> C runtime / fpga-lisp machine
  `-- compute/dataflow IR   -> GPU / specialized FPGA pipeline
```

Thus `fpga-lisp` is not merely "another GPU-like backend." It can execute
general Lisp through its machine ISA, while a future FPGA dataflow backend
could specialize pure stream or pipeline regions without an evaluator.

## Important seams to formalize

### First-class builtins

Language contract 2.1 makes builtins ordinary callable values that may be
passed and lexically shadowed. CML's C backend has this capability, while the
FPGA emitter still lowers primitive calls directly. The hardware already has
`TAG_PRIMITIVE`; the next design must bootstrap primitive values into the
environment and make both the hardware evaluator and CML-generated calls use
the same lookup/apply rule.

### Execution ABI

CML currently documents the effective FPGA calling convention: R0 carries
the complete argument list, R4 the environment, R11 the cons-based software
stack, R14 the link, and R15 the result. This is a contract between two repos,
not merely a private implementation note. It should become a machine-readable
shared ABI checked by both CML and fpga-lisp.

### Numeric representation

my-lisp promises arbitrary-precision exact integers and exact normalized
rationals. FPGA currently has a fixnum payload, and CML additionally limits
literals to the LOADI immediate range. The proposed boxed sign-magnitude
bignum and numerator/denominator rational representations are directionally
sound, but must be ratified through fixtures before RTL. The representation
draft also says only two tag slots remain although ISA 1.0 names six of sixteen
tag values; that statement needs correction or an explicit account of other
reserved tags.

The safe sequence is:

```text
my-lisp fixtures
-> representation contract
-> ISA tag revision
-> RTL constructors/accessors
-> arithmetic routines
-> CML representation lowering
-> differential conformance
```

### Heap and garbage collection

R11's stack is itself a cons list in the same 4096-cell bump-allocated heap.
Calls therefore consume heap even after logical pops. `SETCDR` also permits
cycles through recursive closure environments, so reference counting is not
sufficient. A tracing collector is a runtime-correctness milestone for larger
compiled programs, not merely a performance optimization.

### Error ABI

The language exposes named error classes, while the hardware interface mainly
records an error flag and program counter. CML can catch some errors before
emission, but runtime failures need a machine-visible error kind plus location
and, optionally, detail. This can extend the monitor/result protocol without
requiring a new opcode.

### FPGA machine IR

The FPGA emitter currently hardcodes scratch registers in each compilation
routine. This has already produced real clobbering bugs. Before bignums, GC
calls, or substantially more complex expressions, CML needs a lower FPGA
machine IR with virtual registers, liveness, and allocation before assembly
emission.

## Recommended order

1. Keep language semantics and fixtures authoritative in my-lisp.
2. Complete CML's typed lowering diagnostics and explicit capability matrices.
3. Make the CML/fpga-lisp execution ABI machine-readable and jointly tested.
4. Implement first-class FPGA primitives using the existing primitive tag.
5. Add machine-visible named error kinds.
6. Introduce FPGA machine IR and register allocation in CML.
7. Ratify bignum/rational representation through my-lisp fixtures.
8. Implement boxed numeric values and arithmetic on FPGA.
9. Add tracing garbage collection.
10. Claim full compiled-language conformance only from the differential matrix.

## Repository responsibility

- `my-lisp`: owns observable semantics, contract versions, canonical fixtures,
  and representation-level semantic invariants.
- `cml`: owns frontend admission, semantic IR, target validation, partitioning,
  machine IR, ABI use, code generation, and differential conformance.
- `fpga-lisp`: owns ISA encoding, tagged-word and heap representation, runtime
  hardware behavior, monitor/error protocol, synthesis constraints, and RTL
  evidence.

The three repositories already form the right system. The highest-leverage
next step is not a new backend but a stronger formal seam between CML and
fpga-lisp: shared ABI, capability declarations, error protocol, and value
representation contracts.

## GPU preparation status

CML now owns an analysis-only compute contract (`compute-contract.my`, version
0.1) and recognizes `map`/`reduce` execution shapes without changing my-lisp.
GPU admission remains fail-closed. The current my-lisp `Vector` is
heterogeneous and mutable through `vector-set!`; it is therefore not silently
treated as a typed GPU buffer. Any immutable/typed contiguous representation
is a future my-lisp contract decision, after which CML may refine storage and
numeric facts and select a backend without changing program results.

---

# Аналіз архітектури: my-lisp, CML та fpga-lisp як єдина семантична система (Ukrainian)

**Статус:** архітектурний аналіз, 2026-08-24. Цей документ фіксує зв'язки, 
що спостерігаються в трьох живих репозиторіях; машиночитні контракти 
залишаються авторитетними над цим текстом.

## Ролі

- `my-lisp` визначає, що означає програма (семантичний авторитет).
- `CML` перетворює це значення у виконувані форми (точка інтеграції).
- `fpga-lisp` фізично виконує одну з цих форм (цільова ISA для AOT компілятора 
  та незалежний апаратний обчислювач).

Два шляхи (зкомпільований код через CML і пряме обчислення даних на FPGA) 
повинні бути розділені, щоб тестувати компілятор та універсальність мови незалежно.

## Поточні межі контрактів

Шлях на FPGA вже підтримує теговані значення, купу (heap) на 4096 cons-комірок, 
програму на 4096 слів, 16 регістрів, базові примітиви, рекурсію, лексичні 
замикання (closures) та зкомпільовані приклади типу `reverse` чи `equal?`. 
`CML` використовує контракти версії 2.0, частково 2.1; `fpga-lisp` — ISA 1.1.

## Цільова архітектура

Роботи з потоками даних (dataflow) для GPU/FPGA знаходяться поруч із цим 
шляхом, а не всередині семантики мови. `fpga-lisp` — це не просто "ще один 
бекенд на кшталт GPU", він здатен виконувати загальний Lisp через свою ISA.

## Важливі межі, що потребують формалізації

1. **Вбудовані функції першого класу (First-class builtins):** Контракт 2.1 
   дозволяє передавати та перевизначати (shadow) builtins. C-бекенд це 
   підтримує, FPGA — поки ні. Потрібно уніфікувати підхід, використовуючи 
   вже існуючий `TAG_PRIMITIVE`.
2. **Виконуваний ABI (Execution ABI):** Угода про виклики (R0 — аргументи, 
   R4 — середовище, R11 — стек, R14 — лінк, R15 — результат) має стати 
   машиночитним спільним контрактом між CML та fpga-lisp, а не просто приміткою.
3. **Числове представлення:** `my-lisp` обіцяє точні цілі числа довільної 
   розрядності (bignums) та раціональні дроби. FPGA наразі має лише fixnum. 
   Перехід на bignum вимагає обережної послідовності: фікстури -> контракт 
   представлення -> зміна тегів ISA -> RTL -> арифметика -> компіляція.
4. **Купа та збирання сміття (GC):** Оскільки стек викликів (`R11`) є 
   частиною тієї самої cons-купи і `SETCDR` створює цикли, підрахунок 
   посилань недостатній. Трасуючий збирач сміття є умовою коректності, а не 
   лише оптимізацією.
5. **ABI помилок:** Під час виконання (runtime) необхідні машиночитні типи 
   помилок, їхні локації та деталі, що має бути реалізовано як розширення 
   протоколу монітора/результату.
6. **Машинний IR для FPGA:** Перед додаванням GC чи bignums, `CML` має 
   додати нижчий рівень FPGA Machine IR із віртуальними регістрами та 
   алокацією, щоб уникнути конфліктів жорстко зашитих регістрів (clobbering).

## Рекомендована черговість

Зберегти авторитет фікстур у `my-lisp`. Завершити матриці можливостей у `CML`. 
Оформити спільний ABI. Зробити вбудовані функції FPGA об'єктами першого класу. 
Додати розрізнення типів помилок. Створити FPGA Machine IR. Затвердити 
представлення bignum/раціональних чисел, реалізувати їх в RTL. Додати GC. 
Лише після цього заявляти про повну сумісність.

## Відповідальність репозиторіїв
- **my-lisp:** семантика, контракти, фікстури.
- **cml:** компіляція, IR, генерація коду, порівняльна сумісність.
- **fpga-lisp:** ISA, RTL, апаратна поведінка, представлення купи.

## Статус підготовки до GPU
CML має контракт на аналіз обчислень і розпізнає патерни `map`/`reduce`. 
Оскільки вектори `my-lisp` є гетерогенними та мутабельними, вони не 
розглядаються автоматично як GPU-буфери. Будь-які незмінні (immutable) 
типізовані представлення — це майбутнє семантичне рішення.
