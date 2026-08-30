# CPU + GPU + FPGA execution fabric

**Status:** architecture direction, 2026-08-24. `isa-contract.my`, RTL, and
hardware evidence remain authoritative.

The three repositories keep separate authority while forming one system:

```text
my-lisp    observable semantics
CML        analysis, Execution Graph, partitioning, lowering
fpga-lisp  FPGA ISA, RTL, transport, physical evidence
```

The target fabric is:

```text
my-lisp -> CML semantic IR -> Execution Graph
                                  |    |    |
                                 CPU  GPU  FPGA
```

CPU runs full Lisp semantics and coordinates jobs. Portable or
vendor-specific GPU backends run pure bulk operations over immutable typed
numeric buffers. The FPGA has two roles that evidence must keep distinct:

1. general Lisp execution through the existing `fpga-lisp` ISA;
2. future specialized stream/dataflow pipelines.

The connected GW5A-25A board, SRAM programming, UART upload, and observed
`(plus 3 4)` result establish the first role. They do not establish the second.

## FPGA executor boundary

CML owns graph nodes and logical buffers. `fpga-lisp` owns a versioned job and
result protocol that maps a node onto the physical machine:

```text
CPU logical buffer
 -> versioned frame
 -> UART / future PCIe transport
 -> program + FPGA-visible data
 -> execution
 -> named status + result frame
 -> CPU logical buffer
```

No raw pointer is a cross-device ABI. M0 may copy through host memory. BRAM
descriptors, DMA, pinned memory, or direct GPU/FPGA movement are later
optimizations and require an explicit ABI revision.

The executor must report live capabilities, device identity, supported
operations and representations, program limits, transport availability, and
named errors. A planned pipeline is never selectable. A failed job publishes
no partial language value.

## Synergy rather than substitution

Suggested placement is complementary:

| Work | Candidate |
|---|---|
| dynamic control, closures, exact arithmetic, GC | CPU |
| pure element-wise and reductions | GPU |
| deterministic streams/pipelines or Lisp-machine programs | FPGA |
| uncertain or unsupported regions | CPU fallback |

A golden heterogeneous experiment should be deliberately small:

```text
CPU validates input
 -> GPU maps a typed numeric buffer
 -> CPU converts or partitions
 -> FPGA executes a deterministic node
 -> CPU compares with reference execution
```

This proves orchestration only. Performance requires separate transfer,
launch, and execution measurements.

## Milestones affecting fpga-lisp

1. CML first implements an Execution Graph with a CPU-only executor.
2. Define a machine-readable, versioned FPGA job/result frame jointly with
   CML; keep existing ISA authority here.
3. Implement Rust host transport without deleting the current monitor, which
   remains an independent diagnostic path.
4. Run one graph node on physical hardware and record cable/device, bitstream,
   program, transport, and result evidence separately.
5. Only then design a dataflow specialization ABI and RTL pipeline.

FPGA conformance distinguishes simulation, synthesis, SRAM programming,
transport success, and observed results. Valid states are `CONFIRMED`,
`PARTIAL`, `UNSUPPORTED`, `UNAVAILABLE`, `BROKEN`, and `UNRESOLVED`; success
of the CPU or GPU backend does not infer FPGA success.

Hardware vendor names and transport primitives do not enter core my-lisp.
CML selects only a registered `Live` executor after semantic and
representation checks pass.

---

# Тканина виконання CPU + GPU + FPGA (Ukrainian)

**Статус:** архітектурний напрямок, 2026-08-24. `isa-contract.my`, RTL 
та апаратні докази залишаються авторитетними.

Три репозиторії зберігають окремий авторитет, водночас формуючи єдину систему:

```text
my-lisp    спостережувана семантика
CML        аналіз, Граф Виконання (Execution Graph), партиціювання, lowering
fpga-lisp  FPGA ISA, RTL, транспорт, фізичні докази
```

Цільова тканина (target fabric):

```text
my-lisp -> CML semantic IR -> Execution Graph
                                  |    |    |
                                 CPU  GPU  FPGA
```

CPU виконує повну семантику Lisp і координує завдання. Портативні чи 
специфічні для вендорів GPU-бекенди виконують чисті масові операції 
над незмінними типізованими числовими буферами. FPGA має дві ролі, які 
в доказах мають розрізнятися:
1. Виконання загального Lisp через існуючу ISA `fpga-lisp`.
2. Майбутні спеціалізовані конвеєри (pipelines) для потоків даних/даних.

Успішне програмування SRAM, завантаження через UART та результат `(plus 3 4)` 
встановлюють першу роль, але не другу.

## Межа FPGA-виконавця (executor)

CML володіє вузлами графа і логічними буферами. `fpga-lisp` володіє 
версіонованим протоколом завдань і результатів, який відображає вузол 
на фізичну машину. Жоден сирий вказівник не є міжпристроєвим ABI. 

Виконавець повинен повідомляти про наявні (live) можливості, ідентичність 
пристрою, підтримувані операції, ліміти програми, доступність транспорту 
та іменовані помилки. Невдале завдання не публікує часткових значень.

## Синергія замість заміни

Рекомендоване розміщення (placement) є взаємодоповнюючим:
- CPU: динамічний контроль, замикання, точна арифметика, GC, fallback.
- GPU: чисті поелементні операції та редукції.
- FPGA: детерміновані потоки/конвеєри або програми для Lisp-машини.

## Етапи, що стосуються fpga-lisp

1. CML спочатку реалізує Граф Виконання з CPU-виконавцем.
2. Визначити машиночитний, версіонований кадр завдання/результату FPGA 
   спільно з CML; зберегти існуючий авторитет ISA тут.
3. Реалізувати хостовий транспорт на Rust без видалення поточного монітора, 
   який залишається незалежним діагностичним шляхом.
4. Виконати один вузол графа на фізичному обладнанні та записати докази.
5. Лише після цього проєктувати спеціалізацію ABI для потоків даних та RTL-конвеєр.

Сумісність (conformance) FPGA розрізняє симуляцію, синтез, програмування SRAM, 
транспортний успіх і спостережувані результати. Назви вендорів апаратного 
забезпечення та транспортні примітиви не потрапляють у ядро `my-lisp`. 
CML обирає лише зареєстрованого виконавця типу `Live` після того, як 
семантичні перевірки та перевірки представлення пройдуть успішно.
