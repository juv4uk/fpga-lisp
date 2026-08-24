# fpga-lisp

**A Lisp machine built in hardware, from a tagged word up · Lisp-машина, побудована в залізі — від таговоного слова вгору · Eine Lisp-Maschine, in Hardware gebaut — vom getaggten Wort an aufwärts**

[English](#english) · [Українська](#українська) · [Deutsch](#deutsch)

## English

`fpga-lisp` is a from-scratch Lisp machine implemented in SystemVerilog for the Sipeed Tang Primer 25K FPGA board (Gowin GW5A-25A). It is not a soft-core CPU running a Lisp interpreter — `CONS`/`CAR`/`CDR`/`ATOM`/`EQ` are physical hardware operations, and the machine grows upward from there toward its own `eval`, the same way [`my-lisp`](https://github.com/juv4uk/my-lisp) grows its standard library from seven primitives. `fpga-lisp` is the second of two committed implementations of the `my-lisp` language — a from-scratch HDL Lisp-machine core, developed in parallel with the canonical Rust implementation, and eventually accountable to the same [implementation-independent conformance contract](docs/reference/conformance.my).

The full design philosophy, instruction set, memory model, and milestone-by-milestone roadmap live in [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md) — read that first. The one-page constitution is [`docs/lisp-machine.md`](docs/lisp-machine.md).

### Quick facts

- **Word**: 32 bits — 4-bit tag + 28-bit value. Tags: `FIXNUM`, `CONS`, `SYMBOL`, `NIL`, `TRUE`, `PRIMITIVE` — all 16 tag slots not yet used, 6 of 16 occupied.
- **Heap**: a bump-allocated cons-cell store (parallel `CAR`/`CDR` BRAMs), no garbage collector yet — but the design for one is already fixed: trace-based (mark-and-sweep), never reference counting, since `SETCDR`-built `letrec` closures can form real reference cycles.
- **ISA**: version 1.0 (`isa-contract.my`), 16 opcodes, all allocated. `CALL`/`RET`, `GETTAG`/`MAKEPRIM`/`GETVAL`, and `SETCDR` reuse the `JMP`/`MOV`/`ATOM` opcodes (RISC-V JAL/JALR-style dual-purposing) rather than consuming new instruction slots. `JF` matches my-lisp's truth semantics exactly: only `NIL` is falsy, fixnum `0` is truthy.
- **Program memory**: 4096 words (12-bit PC), sized against the board's real BRAM budget (56 blocks on the GW5A-25A; the heap alone uses 16) rather than picked arbitrarily. The UART bootloader protocol length prefix is 2 bytes, little-endian.
- **Toolchain**: [`assembler.py`](assembler.py) (asm → `.bin`, the authoritative encoder), [`upload.py`](upload.py) (serial bootloader + terminal), [`monitor.py`](monitor.py) (post-`HALT` binary debug REPL: `reg <n>`, `heap <addr>`, `hp`).
- **Status**: a complete `eval(expr, env)` — atoms, `quote`, `cond`, closure application (1/2/N-ary), and primitive-procedure dispatch — plus real self-referential and mutually-recursive functions bootstrapped straight from `my-lisp`'s `lib/core.my` and run on real hardware: `length`/`length-onto` (tail-recursive mutual pair), `reverse`/`reverse-onto`, `append`, and `equal?` (structural equality, not pointer comparison) all PASS on real `iverilog`, cross-checked against my-lisp's TCP semantic oracle. 34 milestones green at their documented evidence levels. See [`docs/testing.md`](docs/testing.md) for the full list and [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md) for the detailed history. Tagged releases: `lisp-machine-v0.01`–`v0.04`.

### Build, simulate, flash

Simulate a testbench with [Icarus Verilog](http://iverilog.icarus.com/):

```bash
iverilog -g2012 -I fpga/rtl -o tb.vvp \
  fpga/rtl/lisp_word.sv fpga/rtl/heap.sv fpga/rtl/lisp_data_unit.sv \
  fpga/rtl/registers.sv fpga/rtl/instruction_decoder.sv fpga/rtl/control.sv \
  fpga/rtl/uart.sv fpga/rtl/bootloader.sv fpga/rtl/lisp_machine.sv \
  fpga/sim/tb_machine.sv
vvp tb.vvp
```

Synthesize and flash with the Gowin EDA toolchain (`gw_sh` + `programmer_cli`), targeting the GW5A-25A on the Tang Primer 25K:

```bash
gw_sh fpga/synth/build.tcl
programmer_cli --device GW5A-25A --operation_index 2 --fsFile impl/pnr/project.fs
```

Assemble and upload a program over UART:

```bash
python assembler.py your_program.asm
python upload.py COM3 your_program.bin
python monitor.py COM3 your_program.bin   # upload + post-HALT debug REPL
```

### Resource usage (Gowin GW5A-25A)

Measured from `impl/pnr/project.rpt.txt` after the current build — not estimated:

| Resource | Total on device | Used | % |
|---|---|---|---|
| BSRAM (16 Kbit/block) | 56 | 24 (`imem`: 8, `heap`: 16) | 43% |
| DSP (27×18 multiplier) | 28 | 0 | 0% |
| LUT | 23,040 | ~1,363 | 6% |
| Register (FF) | 23,280 | ~952 | 5% |

Program memory (`imem`) and heap size were both chosen against this real BRAM budget, not picked arbitrarily — see [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md) for the arithmetic. The 28 unused DSP blocks (each a 27×18 + 12×12 multiplier) are headroom for later work this core doesn't need yet: exact-rational arithmetic (numerator/denominator multiplication) and bignum limb multiplication both map naturally onto them instead of emulating multiplication in LUT logic.

### Repository layout

- [`fpga/rtl/`](fpga/rtl) — SystemVerilog source: word format, heap, data unit, register file, decoder, control unit, UART, bootloader, top-level integration.
- [`fpga/sim/`](fpga/sim) — one testbench per milestone (`tb_cons.sv`, `tb_atom_eq.sv`, `tb_list.sv`, `tb_control.sv`, `tb_call.sv`, `tb_env.sv`, `tb_lambda.sv`, `tb_eval_atom.sv`, `tb_monitor.sv`, `tb_machine.sv`).
- [`fpga/synth/`](fpga/synth) — Gowin synthesis script and pin constraints.
- [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md) — the full roadmap and current status against it.
- [`isa-contract.my`](isa-contract.my) / [`docs/isa-contract.md`](docs/isa-contract.md) — the versioned machine-readable ISA boundary and its rationale.
- [`docs/testing.md`](docs/testing.md) — the milestone/testbench inventory.
- [`docs/reference/conformance.my`](docs/reference/conformance.my) — the implementation-independent contract from `my-lisp` that this core will eventually need to match.

## Українська

`fpga-lisp` — Lisp-машина, побудована з нуля на SystemVerilog для плати Sipeed Tang Primer 25K (Gowin GW5A-25A). Це не soft-core процесор, що виконує Lisp-інтерпретатор — `CONS`/`CAR`/`CDR`/`ATOM`/`EQ` є фізичними апаратними операціями, і машина росте вгору звідти до власного `eval`, так само як [`my-lisp`](https://github.com/juv4uk/my-lisp) вирощує свою стандартну бібліотеку із семи примітивів. `fpga-lisp` — друга з двох запланованих реалізацій мови `my-lisp`: HDL-ядро Lisp-машини з нуля, що розробляється паралельно з канонічною Rust-реалізацією і зрештою має відповідати тому самому [implementation-independent контракту сумісності](docs/reference/conformance.my).

Повна філософія дизайну, набір інструкцій, модель пам'яті та поетапний roadmap — у [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md), читати першим. Однosторінкова "конституція" — [`docs/lisp-machine.md`](docs/lisp-machine.md).

### Коротко

- **Слово**: 32 біти — 4-бітний tag + 28-бітне значення. Теги: `FIXNUM`, `CONS`, `SYMBOL`, `NIL`, `TRUE`, `PRIMITIVE` — зайнято 6 з 16 можливих.
- **Heap**: сховище cons-комірок з bump-allocator (паралельні `CAR`/`CDR` BRAM), garbage collector'а поки немає — але його дизайн уже зафіксований: trace-based (mark-and-sweep), ніколи не reference counting, бо `letrec`-closures, побудовані через `SETCDR`, можуть утворювати справжні цикли посилань.
- **ISA**: версія 1.0 (`isa-contract.my`), 16 опкодів, усі зайняті. `CALL`/`RET`, `GETTAG`/`MAKEPRIM`/`GETVAL` і `SETCDR` перевикористовують опкоди `JMP`/`MOV`/`ATOM` (за принципом RISC-V JAL/JALR) замість нових слотів інструкцій. `JF` точно відповідає truth-семантиці my-lisp: лише `NIL` — falsy, fixnum `0` — truthy.
- **Пам'ять програми**: 4096 слів (12-бітний PC), розмір обраний під реальний BRAM-бюджет плати (56 блоків на GW5A-25A; сам heap займає 16), а не довільно. Префікс довжини протоколу UART-завантажувача — 2 байти little-endian.
- **Інструментарій**: [`assembler.py`](assembler.py) (asm → `.bin`, авторитетний енкодер), [`upload.py`](upload.py) (серійний завантажувач + термінал), [`monitor.py`](monitor.py) (бінарний debug REPL після `HALT`: `reg <n>`, `heap <addr>`, `hp`).
- **Стан**: повний `eval(expr, env)` — атоми, `quote`, `cond`, аплікація closure (1/2/N-арна) і диспетчеризація примітивних процедур — плюс справжні самореференційні й взаємно-рекурсивні функції, забутстраплені прямо з `my-lisp`'s `lib/core.my` і виконані на реальному залізі: `length`/`length-onto` (хвостово-рекурсивна взаємна пара), `reverse`/`reverse-onto`, `append`, `equal?` (структурна рівність, не порівняння вказівників) — усі PASSED на реальному `iverilog`, звірені проти TCP semantic oracle my-lisp. 34 milestone'и зелені на задокументованих рівнях доказів. Повний перелік — [`docs/testing.md`](docs/testing.md), детальна історія — [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md). Теговані релізи: `lisp-machine-v0.01`–`v0.04`.

### Збірка, симуляція, прошивка

Симуляція тестбенчу через [Icarus Verilog](http://iverilog.icarus.com/):

```bash
iverilog -g2012 -I fpga/rtl -o tb.vvp \
  fpga/rtl/lisp_word.sv fpga/rtl/heap.sv fpga/rtl/lisp_data_unit.sv \
  fpga/rtl/registers.sv fpga/rtl/instruction_decoder.sv fpga/rtl/control.sv \
  fpga/rtl/uart.sv fpga/rtl/bootloader.sv fpga/rtl/lisp_machine.sv \
  fpga/sim/tb_machine.sv
vvp tb.vvp
```

Синтез і прошивка через Gowin EDA (`gw_sh` + `programmer_cli`), плата Tang Primer 25K (GW5A-25A):

```bash
gw_sh fpga/synth/build.tcl
programmer_cli --device GW5A-25A --operation_index 2 --fsFile impl/pnr/project.fs
```

Асемблювання й заливка програми через UART:

```bash
python assembler.py your_program.asm
python upload.py COM3 your_program.bin
python monitor.py COM3 your_program.bin   # заливка + debug REPL після HALT
```

### Використання ресурсів (Gowin GW5A-25A)

Виміряно з `impl/pnr/project.rpt.txt` після поточної збірки — не оцінка:

| Ресурс | Всього на кристалі | Використано | % |
|---|---|---|---|
| BSRAM (16 Кбіт/блок) | 56 | 24 (`imem`: 8, `heap`: 16) | 43% |
| DSP (множник 27×18) | 28 | 0 | 0% |
| LUT | 23 040 | ~1 363 | 6% |
| Register (FF) | 23 280 | ~952 | 5% |

Розмір пам'яті програми (`imem`) і heap обрано саме під цей реальний BRAM-бюджет, а не довільно — розрахунок у [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md). 28 невикористаних DSP-блоків (кожен — множник 27×18 + 12×12) — запас під те, що цьому ядру поки не потрібне: точна раціональна арифметика (множення чисельника/знаменника) і множення "лімбів" bignum природно лягають саме на них, а не на емуляцію множення через LUT-логіку.

### Структура репозиторію

- [`fpga/rtl/`](fpga/rtl) — SystemVerilog: формат слова, heap, data unit, регістровий файл, декодер, control unit, UART, bootloader, top-level.
- [`fpga/sim/`](fpga/sim) — по одному тестбенчу на milestone.
- [`fpga/synth/`](fpga/synth) — скрипт синтезу Gowin і pin-обмеження.
- [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md) — повний roadmap і поточний стан.
- [`isa-contract.my`](isa-contract.my) / [`docs/isa-contract.md`](docs/isa-contract.md) — версіонована машинно-читана межа ISA та її обґрунтування.
- [`docs/testing.md`](docs/testing.md) — перелік milestone/тестбенчів.
- [`docs/reference/conformance.my`](docs/reference/conformance.my) — контракт сумісності з `my-lisp`.

## Deutsch

`fpga-lisp` ist eine von Grund auf in SystemVerilog gebaute Lisp-Maschine für das Sipeed-Tang-Primer-25K-FPGA-Board (Gowin GW5A-25A). Es ist kein Soft-Core-Prozessor, der einen Lisp-Interpreter ausführt — `CONS`/`CAR`/`CDR`/`ATOM`/`EQ` sind physische Hardware-Operationen, und die Maschine wächst von dort aus zu ihrem eigenen `eval`, genauso wie [`my-lisp`](https://github.com/juv4uk/my-lisp) seine Standardbibliothek aus sieben Primitiven heraus wachsen lässt. `fpga-lisp` ist die zweite von zwei geplanten Implementierungen der Sprache `my-lisp` — ein von Grund auf neuer HDL-Lisp-Maschinen-Kern, parallel zur kanonischen Rust-Implementierung entwickelt und letztlich demselben [implementierungsunabhängigen Konformitätsvertrag](docs/reference/conformance.my) verpflichtet.

Die vollständige Design-Philosophie, der Befehlssatz, das Speichermodell und die schrittweise Roadmap stehen in [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md) — zuerst lesen. Die einseitige "Verfassung" ist [`docs/lisp-machine.md`](docs/lisp-machine.md).

### Kurzfakten

- **Wort**: 32 Bit — 4-Bit-Tag + 28-Bit-Wert. Tags: `FIXNUM`, `CONS`, `SYMBOL`, `NIL`, `TRUE`, `PRIMITIVE` — 6 von 16 belegt.
- **Heap**: ein Bump-Allocator-Cons-Zellen-Speicher (parallele `CAR`/`CDR`-BRAMs), noch kein Garbage Collector — dessen Design steht aber bereits fest: trace-basiert (Mark-and-Sweep), niemals Reference Counting, da über `SETCDR` gebaute `letrec`-Closures echte Referenzzyklen bilden können.
- **ISA**: Version 1.0 (`isa-contract.my`), 16 Opcodes, alle belegt. `CALL`/`RET`, `GETTAG`/`MAKEPRIM`/`GETVAL` und `SETCDR` nutzen die Opcodes von `JMP`/`MOV`/`ATOM` wieder (RISC-V-JAL/JALR-Stil) statt neue Instruktions-Slots zu verbrauchen. `JF` entspricht exakt der Wahrheitssemantik von my-lisp: nur `NIL` ist falsy, Fixnum `0` ist truthy.
- **Programmspeicher**: 4096 Woerter (12-Bit-PC), dimensioniert nach dem realen BRAM-Budget des Boards (56 Bloecke auf dem GW5A-25A; der Heap allein nutzt 16). Das Laengenpraefix des UART-Bootloader-Protokolls ist 2 Byte, Little-Endian.
- **Toolchain**: [`assembler.py`](assembler.py) (maßgeblicher Encoder), [`upload.py`](upload.py), [`monitor.py`](monitor.py) (binäres Debug-REPL nach `HALT`).
- **Status**: ein vollständiges `eval(expr, env)` — Atome, `quote`, `cond`, Closure-Anwendung (1/2/N-är) und Dispatch primitiver Prozeduren — plus echte selbstreferenzielle und wechselseitig rekursive Funktionen, direkt aus `my-lisp`'s `lib/core.my` gebootstrapt und auf echter Hardware verifiziert: `length`/`length-onto` (schwanzrekursives Paar), `reverse`/`reverse-onto`, `append`, `equal?` (strukturelle statt Zeiger-Gleichheit) — alle PASSED auf echtem `iverilog`, gegen my-lisps TCP-Orakel abgeglichen. 34 Meilensteine auf ihren dokumentierten Evidenzstufen grün. Vollständige Liste in [`docs/testing.md`](docs/testing.md), Details in [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md). Getaggte Releases: `lisp-machine-v0.01`–`v0.04`.

### Bauen, Simulieren, Flashen

Testbench mit [Icarus Verilog](http://iverilog.icarus.com/) simulieren:

```bash
iverilog -g2012 -I fpga/rtl -o tb.vvp \
  fpga/rtl/lisp_word.sv fpga/rtl/heap.sv fpga/rtl/lisp_data_unit.sv \
  fpga/rtl/registers.sv fpga/rtl/instruction_decoder.sv fpga/rtl/control.sv \
  fpga/rtl/uart.sv fpga/rtl/bootloader.sv fpga/rtl/lisp_machine.sv \
  fpga/sim/tb_machine.sv
vvp tb.vvp
```

Synthese und Flashen über die Gowin-EDA-Toolchain (`gw_sh` + `programmer_cli`), Ziel GW5A-25A auf dem Tang Primer 25K:

```bash
gw_sh fpga/synth/build.tcl
programmer_cli --device GW5A-25A --operation_index 2 --fsFile impl/pnr/project.fs
```

Programm assemblieren und per UART hochladen:

```bash
python assembler.py your_program.asm
python upload.py COM3 your_program.bin
python monitor.py COM3 your_program.bin   # Upload + Debug-REPL nach HALT
```

### Ressourcennutzung (Gowin GW5A-25A)

Gemessen aus `impl/pnr/project.rpt.txt` nach dem aktuellen Build — keine Schätzung:

| Ressource | Gesamt auf dem Chip | Genutzt | % |
|---|---|---|---|
| BSRAM (16 Kbit/Block) | 56 | 24 (`imem`: 8, `heap`: 16) | 43% |
| DSP (27×18-Multiplizierer) | 28 | 0 | 0% |
| LUT | 23.040 | ~1.363 | 6% |
| Register (FF) | 23.280 | ~952 | 5% |

Programmspeicher (`imem`) und Heap-Groesse wurden nach diesem realen BRAM-Budget gewaehlt, nicht willkuerlich — Rechnung in [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md). Die 28 ungenutzten DSP-Bloecke sind Reserve fuer spaetere Arbeit: exakte rationale Arithmetik und Bignum-Multiplikation passen natuerlich darauf, statt Multiplikation in LUT-Logik zu emulieren.

### Repository-Struktur

- [`fpga/rtl/`](fpga/rtl) — SystemVerilog-Quellcode.
- [`fpga/sim/`](fpga/sim) — eine Testbench pro Meilenstein.
- [`fpga/synth/`](fpga/synth) — Gowin-Syntheseskript und Pin-Constraints.
- [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md) — vollständige Roadmap und aktueller Status.
- [`isa-contract.my`](isa-contract.my) / [`docs/isa-contract.md`](docs/isa-contract.md) — die versionierte maschinenlesbare ISA-Grenze und ihre Begründung.
- [`docs/testing.md`](docs/testing.md) — Meilenstein-/Testbench-Inventar.
- [`docs/reference/conformance.my`](docs/reference/conformance.my) — Konformitätsvertrag mit `my-lisp`.
