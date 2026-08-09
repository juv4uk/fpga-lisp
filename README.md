# fpga-lisp

**A Lisp machine built in hardware, from a tagged word up · Lisp-машина, побудована в залізі — від таговоного слова вгору · Eine Lisp-Maschine, in Hardware gebaut — vom getaggten Wort an aufwärts**

[English](#english) · [Українська](#українська) · [Deutsch](#deutsch)

## English

`fpga-lisp` is a from-scratch Lisp machine implemented in SystemVerilog for the Sipeed Tang Primer 25K FPGA board (Gowin GW5A-25A). It is not a soft-core CPU running a Lisp interpreter — `CONS`/`CAR`/`CDR`/`ATOM`/`EQ` are physical hardware operations, and the machine grows upward from there toward its own `eval`, the same way [`my-lisp`](https://github.com/juv4uk/my-lisp) grows its standard library from seven primitives. `fpga-lisp` is the second of two committed implementations of the `my-lisp` language — a from-scratch HDL Lisp-machine core, developed in parallel with the canonical Rust implementation, and eventually accountable to the same [implementation-independent conformance contract](docs/reference/conformance.my).

The full design philosophy, instruction set, memory model, and milestone-by-milestone roadmap live in [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md) — read that first. The one-page constitution is [`docs/lisp-machine.md`](docs/lisp-machine.md).

### Quick facts

- **Word**: 32 bits — 4-bit tag + 28-bit value. Tags implemented so far: `FIXNUM`, `CONS`, `SYMBOL`, `NIL`, `TRUE`.
- **Heap**: a bump-allocated cons-cell store (parallel `CAR`/`CDR` BRAMs), no garbage collector yet.
- **ISA**: 16 opcodes, all allocated. `CALL`/`RET` and `GETTAG` reuse the `JMP` and `MOV` opcodes (RISC-V JAL/JALR-style dual-purposing) rather than consuming new instruction slots.
- **Toolchain**: [`assembler.py`](assembler.py) (asm → `.bin`), [`upload.py`](upload.py) (serial bootloader + terminal), [`monitor.py`](monitor.py) (post-`HALT` binary debug REPL: `reg <n>`, `heap <addr>`, `hp`).
- **Status**: primitives, branching, lists, subroutine calls, environments (alists), closures, and the first `eval` dispatch (atoms) are all implemented and verified — see [`docs/testing.md`](docs/testing.md) for the full milestone list. Tagged releases: `lisp-machine-v0.01`, `lisp-machine-v0.02`.

### Build, simulate, flash

Simulate a testbench with [Icarus Verilog](http://iverilog.icarus.com/):

```bash
iverilog -g2012 -I fpga/rtl -o tb.vvp fpga/rtl/*.sv fpga/sim/tb_machine.sv
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

### Repository layout

- [`fpga/rtl/`](fpga/rtl) — SystemVerilog source: word format, heap, data unit, register file, decoder, control unit, UART, bootloader, top-level integration.
- [`fpga/sim/`](fpga/sim) — one testbench per milestone (`tb_cons.sv`, `tb_atom_eq.sv`, `tb_list.sv`, `tb_control.sv`, `tb_call.sv`, `tb_env.sv`, `tb_lambda.sv`, `tb_eval_atom.sv`, `tb_monitor.sv`, `tb_machine.sv`).
- [`fpga/synth/`](fpga/synth) — Gowin synthesis script and pin constraints.
- [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md) — the full roadmap and current status against it.
- [`docs/testing.md`](docs/testing.md) — the milestone/testbench inventory.
- [`docs/reference/conformance.my`](docs/reference/conformance.my) — the implementation-independent contract from `my-lisp` that this core will eventually need to match.

## Українська

`fpga-lisp` — Lisp-машина, побудована з нуля на SystemVerilog для плати Sipeed Tang Primer 25K (Gowin GW5A-25A). Це не soft-core процесор, що виконує Lisp-інтерпретатор — `CONS`/`CAR`/`CDR`/`ATOM`/`EQ` є фізичними апаратними операціями, і машина росте вгору звідти до власного `eval`, так само як [`my-lisp`](https://github.com/juv4uk/my-lisp) вирощує свою стандартну бібліотеку із семи примітивів. `fpga-lisp` — друга з двох запланованих реалізацій мови `my-lisp`: HDL-ядро Lisp-машини з нуля, що розробляється паралельно з канонічною Rust-реалізацією і зрештою має відповідати тому самому [implementation-independent контракту сумісності](docs/reference/conformance.my).

Повна філософія дизайну, набір інструкцій, модель пам'яті та поетапний roadmap — у [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md), читати першим. Однosторінкова "конституція" — [`docs/lisp-machine.md`](docs/lisp-machine.md).

### Коротко

- **Слово**: 32 біти — 4-бітний tag + 28-бітне значення. Реалізовані теги: `FIXNUM`, `CONS`, `SYMBOL`, `NIL`, `TRUE`.
- **Heap**: сховище cons-комірок з bump-allocator (паралельні `CAR`/`CDR` BRAM), garbage collector'а поки немає.
- **ISA**: 16 опкодів, усі зайняті. `CALL`/`RET` і `GETTAG` перевикористовують опкоди `JMP` і `MOV` (за принципом RISC-V JAL/JALR) замість нових слотів інструкцій.
- **Інструментарій**: [`assembler.py`](assembler.py) (asm → `.bin`), [`upload.py`](upload.py) (серійний завантажувач + термінал), [`monitor.py`](monitor.py) (бінарний debug REPL після `HALT`: `reg <n>`, `heap <addr>`, `hp`).
- **Стан**: примітиви, розгалуження, списки, виклики підпрограм, середовища (alist), closures і перший диспетчер `eval` (атоми) — реалізовані й перевірені; повний перелік — [`docs/testing.md`](docs/testing.md). Теговані релізи: `lisp-machine-v0.01`, `lisp-machine-v0.02`.

### Збірка, симуляція, прошивка

Симуляція тестбенчу через [Icarus Verilog](http://iverilog.icarus.com/):

```bash
iverilog -g2012 -I fpga/rtl -o tb.vvp fpga/rtl/*.sv fpga/sim/tb_machine.sv
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

### Структура репозиторію

- [`fpga/rtl/`](fpga/rtl) — SystemVerilog: формат слова, heap, data unit, регістровий файл, декодер, control unit, UART, bootloader, top-level.
- [`fpga/sim/`](fpga/sim) — по одному тестбенчу на milestone.
- [`fpga/synth/`](fpga/synth) — скрипт синтезу Gowin і pin-обмеження.
- [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md) — повний roadmap і поточний стан.
- [`docs/testing.md`](docs/testing.md) — перелік milestone/тестбенчів.
- [`docs/reference/conformance.my`](docs/reference/conformance.my) — контракт сумісності з `my-lisp`.

## Deutsch

`fpga-lisp` ist eine von Grund auf in SystemVerilog gebaute Lisp-Maschine für das Sipeed-Tang-Primer-25K-FPGA-Board (Gowin GW5A-25A). Es ist kein Soft-Core-Prozessor, der einen Lisp-Interpreter ausführt — `CONS`/`CAR`/`CDR`/`ATOM`/`EQ` sind physische Hardware-Operationen, und die Maschine wächst von dort aus zu ihrem eigenen `eval`, genauso wie [`my-lisp`](https://github.com/juv4uk/my-lisp) seine Standardbibliothek aus sieben Primitiven heraus wachsen lässt. `fpga-lisp` ist die zweite von zwei geplanten Implementierungen der Sprache `my-lisp` — ein von Grund auf neuer HDL-Lisp-Maschinen-Kern, parallel zur kanonischen Rust-Implementierung entwickelt und letztlich demselben [implementierungsunabhängigen Konformitätsvertrag](docs/reference/conformance.my) verpflichtet.

Die vollständige Design-Philosophie, der Befehlssatz, das Speichermodell und die schrittweise Roadmap stehen in [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md) — zuerst lesen. Die einseitige "Verfassung" ist [`docs/lisp-machine.md`](docs/lisp-machine.md).

### Kurzfakten

- **Wort**: 32 Bit — 4-Bit-Tag + 28-Bit-Wert. Bisher implementierte Tags: `FIXNUM`, `CONS`, `SYMBOL`, `NIL`, `TRUE`.
- **Heap**: ein Bump-Allocator-Cons-Zellen-Speicher (parallele `CAR`/`CDR`-BRAMs), noch kein Garbage Collector.
- **ISA**: 16 Opcodes, alle belegt. `CALL`/`RET` und `GETTAG` nutzen die Opcodes von `JMP` und `MOV` wieder (RISC-V-JAL/JALR-Stil) statt neue Instruktions-Slots zu verbrauchen.
- **Toolchain**: [`assembler.py`](assembler.py), [`upload.py`](upload.py), [`monitor.py`](monitor.py) (binäres Debug-REPL nach `HALT`).
- **Status**: Primitive, Verzweigung, Listen, Unterprogrammaufrufe, Umgebungen (Alists), Closures und der erste `eval`-Dispatch (Atome) sind implementiert und verifiziert — vollständige Liste in [`docs/testing.md`](docs/testing.md). Getaggte Releases: `lisp-machine-v0.01`, `lisp-machine-v0.02`.

### Bauen, Simulieren, Flashen

Testbench mit [Icarus Verilog](http://iverilog.icarus.com/) simulieren:

```bash
iverilog -g2012 -I fpga/rtl -o tb.vvp fpga/rtl/*.sv fpga/sim/tb_machine.sv
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

### Repository-Struktur

- [`fpga/rtl/`](fpga/rtl) — SystemVerilog-Quellcode.
- [`fpga/sim/`](fpga/sim) — eine Testbench pro Meilenstein.
- [`fpga/synth/`](fpga/synth) — Gowin-Syntheseskript und Pin-Constraints.
- [`docs/lisp-machine-plan.md`](docs/lisp-machine-plan.md) — vollständige Roadmap und aktueller Status.
- [`docs/testing.md`](docs/testing.md) — Meilenstein-/Testbench-Inventar.
- [`docs/reference/conformance.my`](docs/reference/conformance.my) — Konformitätsvertrag mit `my-lisp`.
