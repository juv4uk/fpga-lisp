# Testing · Тестування · Tests

[English](#english) · [Українська](#українська) · [Deutsch](#deutsch)

## English

Every milestone in [`lisp-machine-plan.md`](lisp-machine-plan.md) has its own testbench under [`fpga/sim/`](../fpga/sim). Each one is self-contained: it bit-bangs a program over simulated UART into the `lisp_machine` bootloader, waits for `halted`, then inspects the register file directly (`u_mac.u_regs.regs[...]`) and prints `M<nn> PASSED`/`FAILED`.

Run any of them with [Icarus Verilog](http://iverilog.icarus.com/):

```bash
iverilog -g2012 -I fpga/rtl -o tb.vvp \
  fpga/rtl/lisp_word.sv fpga/rtl/heap.sv fpga/rtl/lisp_data_unit.sv \
  fpga/rtl/registers.sv fpga/rtl/instruction_decoder.sv fpga/rtl/control.sv \
  fpga/rtl/uart.sv fpga/rtl/bootloader.sv fpga/rtl/lisp_machine.sv \
  fpga/sim/tb_<name>.sv
vvp tb.vvp
```

| Milestone | Testbench | What it proves |
|---|---|---|
| M03 | [`tb_machine.sv`](../fpga/sim/tb_machine.sv) | `(car (cons 'a 'b)) => a` through the full bootloader + control unit — the original "physical Lisp machine" milestone. |
| M05 | [`tb_atom_eq.sv`](../fpga/sim/tb_atom_eq.sv) | `ATOM` and `EQ`: `(atom 'a)`, `(atom (cons 'a 'a))`, `(eq 'a 'a)`. |
| M06 | [`tb_list.sv`](../fpga/sim/tb_list.sv) | A 3-element list built as a `CONS` chain and walked back to `NIL` with `CAR`/`CDR`. |
| M07 | [`tb_control.sv`](../fpga/sim/tb_control.sv) | `JMP`/`JF` branching: a countdown/count-up loop using `SUB`/`ADD`/`EQ`. |
| M08 | [`tb_monitor.sv`](../fpga/sim/tb_monitor.sv) | The post-`HALT` binary debug monitor: `REG`, `HEAP`, `HP` commands over UART. |
| M09 | [`tb_call.sv`](../fpga/sim/tb_call.sv) | `CALL`/`RET` subroutine calls (`JAL`/`JALR`-style reuse of `OP_JMP`). |
| M10 | [`tb_env.sv`](../fpga/sim/tb_env.sv) | An alist environment `((x . 10) (y . 20))` and a hand-assembled `lookup` subroutine. |
| M11 | [`tb_lambda.sv`](../fpga/sim/tb_lambda.sv) | A closure represented as `(params . (body . env))`, with parameter binding via environment extension. |
| M12 | [`tb_eval_atom.sv`](../fpga/sim/tb_eval_atom.sv) | The first real `eval(expr, env)` call: symbol → `lookup`, non-symbol → self-evaluating, dispatched via the new `GETTAG` mode of `OP_MOV`. |
| M13 | [`tb_eval_quote.sv`](../fpga/sim/tb_eval_quote.sv) | `eval` dispatches on `ATOM` vs `CONS`; for a `CONS` expr it checks `car(expr) == 'quote` and returns `car(cdr(expr))` unevaluated — `(quote radio) => radio`, the first fixture in `conformance.my`. |
| M14 | [`tb_eval_cond.sv`](../fpga/sim/tb_eval_cond.sv) | `eval` recognizes `(cond ...)` and recurses into itself for each clause's test/value — the first genuine self-recursion, requiring a software call stack built from `CONS` cells (register frames alone can't survive a recursive call into the same subroutine). `(cond (() 'wrong) (t 'right)) => right`. |

There is also [`tb_cons.sv`](../fpga/sim/tb_cons.sv), a unit-level test of `lisp_data_unit` alone (no bootloader, no control unit) — the very first thing that ever worked in this project.

No opcode is added lightly: the 4-bit opcode field has been full (16/16) since `LOADSYM` claimed the unused `OP_JT` slot. `CALL`/`RET` (M09) and `GETTAG` (M12) both extend existing opcodes (`JMP`, `MOV`) by giving meaning to previously-ignored instruction fields, rather than consuming new slots — check the commit history and `lisp-machine-plan.md`'s status section before assuming a new instruction is the only way to add a capability.

No CI runs these yet; run the full set locally before trusting a change:

```bash
for tb in tb_cons tb_atom_eq tb_machine tb_monitor tb_control tb_list tb_call tb_env tb_lambda tb_eval_atom tb_eval_quote tb_eval_cond; do
  iverilog -g2012 -I fpga/rtl -o ${tb}.vvp fpga/rtl/lisp_word.sv fpga/rtl/heap.sv \
    fpga/rtl/lisp_data_unit.sv fpga/rtl/registers.sv fpga/rtl/instruction_decoder.sv \
    fpga/rtl/control.sv fpga/rtl/uart.sv fpga/rtl/bootloader.sv fpga/rtl/lisp_machine.sv \
    fpga/sim/${tb}.sv
  vvp ${tb}.vvp | tail -2
done
```

## Українська

Кожен milestone у [`lisp-machine-plan.md`](lisp-machine-plan.md) має власний тестбенч у [`fpga/sim/`](../fpga/sim). Кожен — самодостатній: він імітує UART, надсилаючи програму в bootloader `lisp_machine`, чекає на `halted`, тоді читає регістровий файл напряму (`u_mac.u_regs.regs[...]`) і друкує `M<nn> PASSED`/`FAILED`.

Запуск будь-якого через [Icarus Verilog](http://iverilog.icarus.com/) — див. команду вище (англійською секцією).

| Milestone | Тестбенч | Що перевіряє |
|---|---|---|
| M03 | [`tb_machine.sv`](../fpga/sim/tb_machine.sv) | `(car (cons 'a 'b)) => a` через повний bootloader + control unit — перший "фізичний Lisp machine" milestone. |
| M05 | [`tb_atom_eq.sv`](../fpga/sim/tb_atom_eq.sv) | `ATOM` і `EQ`: `(atom 'a)`, `(atom (cons 'a 'a))`, `(eq 'a 'a)`. |
| M06 | [`tb_list.sv`](../fpga/sim/tb_list.sv) | 3-елементний список як ланцюжок `CONS`, пройдений назад до `NIL` через `CAR`/`CDR`. |
| M07 | [`tb_control.sv`](../fpga/sim/tb_control.sv) | Розгалуження `JMP`/`JF`: цикл лічби вниз/вгору через `SUB`/`ADD`/`EQ`. |
| M08 | [`tb_monitor.sv`](../fpga/sim/tb_monitor.sv) | Бінарний debug-monitor після `HALT`: команди `REG`, `HEAP`, `HP` через UART. |
| M09 | [`tb_call.sv`](../fpga/sim/tb_call.sv) | Виклики підпрограм `CALL`/`RET` (перевикористання `OP_JMP` у стилі `JAL`/`JALR`). |
| M10 | [`tb_env.sv`](../fpga/sim/tb_env.sv) | Середовище-alist `((x . 10) (y . 20))` і рукописна підпрограма `lookup`. |
| M11 | [`tb_lambda.sv`](../fpga/sim/tb_lambda.sv) | Closure як `(params . (body . env))`, зв'язування параметра через розширення середовища. |
| M12 | [`tb_eval_atom.sv`](../fpga/sim/tb_eval_atom.sv) | Перший реальний виклик `eval(expr, env)`: символ → `lookup`, не-символ → self-evaluating, диспетчеризація через новий режим `GETTAG` в `OP_MOV`. |
| M13 | [`tb_eval_quote.sv`](../fpga/sim/tb_eval_quote.sv) | `eval` розгалужується через `ATOM` vs `CONS`; для `CONS`-виразу перевіряє `car(expr) == 'quote` і повертає `car(cdr(expr))` без обчислення — `(quote radio) => radio`, перша фікстура `conformance.my`. |
| M14 | [`tb_eval_cond.sv`](../fpga/sim/tb_eval_cond.sv) | `eval` розпізнає `(cond ...)` і рекурсивно викликає сам себе для test/value кожної клаузи — перша справжня самореференція, що потребує програмного call-стеку з `CONS`-комірок. `(cond (() 'wrong) (t 'right)) => right`. |

Також є [`tb_cons.sv`](../fpga/sim/tb_cons.sv) — модульний тест лише `lisp_data_unit` (без bootloader, без control unit) — перше, що взагалі запрацювало в цьому проєкті.

Жоден опкод не додається легковажно: 4-бітне поле опкоду зайняте (16/16) з моменту, коли `LOADSYM` зайняв вільний слот `OP_JT`. `CALL`/`RET` (M09) і `GETTAG` (M12) розширюють наявні опкоди (`JMP`, `MOV`), надаючи сенс раніше ігнорованим полям інструкції, а не займають нові слоти — перевір історію комітів і розділ статусу в `lisp-machine-plan.md`, перш ніж припускати, що новий опкод — єдиний спосіб додати можливість.

CI поки немає — прожени весь набір локально перед тим, як довіряти зміні (команда вище).

## Deutsch

Jeder Meilenstein in [`lisp-machine-plan.md`](lisp-machine-plan.md) hat seine eigene Testbench unter [`fpga/sim/`](../fpga/sim). Jede ist eigenständig: sie simuliert UART, sendet ein Programm in den Bootloader von `lisp_machine`, wartet auf `halted` und liest dann die Registerdatei direkt aus (`u_mac.u_regs.regs[...]`), gibt `M<nn> PASSED`/`FAILED` aus.

Ausführung über [Icarus Verilog](http://iverilog.icarus.com/) — siehe Befehl im englischen Abschnitt oben.

| Meilenstein | Testbench | Was bewiesen wird |
|---|---|---|
| M03 | [`tb_machine.sv`](../fpga/sim/tb_machine.sv) | `(car (cons 'a 'b)) => a` über den vollständigen Bootloader + Control Unit. |
| M05 | [`tb_atom_eq.sv`](../fpga/sim/tb_atom_eq.sv) | `ATOM` und `EQ`. |
| M06 | [`tb_list.sv`](../fpga/sim/tb_list.sv) | Eine 3-elementige Liste als `CONS`-Kette. |
| M07 | [`tb_control.sv`](../fpga/sim/tb_control.sv) | `JMP`/`JF`-Verzweigung: eine Countdown/Count-up-Schleife. |
| M08 | [`tb_monitor.sv`](../fpga/sim/tb_monitor.sv) | Der binäre Debug-Monitor nach `HALT`. |
| M09 | [`tb_call.sv`](../fpga/sim/tb_call.sv) | `CALL`/`RET`-Unterprogrammaufrufe. |
| M10 | [`tb_env.sv`](../fpga/sim/tb_env.sv) | Eine Alist-Umgebung und eine `lookup`-Subroutine. |
| M11 | [`tb_lambda.sv`](../fpga/sim/tb_lambda.sv) | Eine Closure als `(params . (body . env))`. |
| M12 | [`tb_eval_atom.sv`](../fpga/sim/tb_eval_atom.sv) | Der erste echte `eval(expr, env)`-Aufruf. |
| M13 | [`tb_eval_quote.sv`](../fpga/sim/tb_eval_quote.sv) | `eval` verzweigt über `ATOM` vs `CONS`; bei `CONS` prüft es `car(expr) == 'quote` und liefert `car(cdr(expr))` unausgewertet zurück. |
| M14 | [`tb_eval_cond.sv`](../fpga/sim/tb_eval_cond.sv) | `eval` erkennt `(cond ...)` und ruft sich selbst rekursiv auf — die erste echte Selbstrekursion, die einen Software-Aufrufstapel aus `CONS`-Zellen benötigt. |

Auch vorhanden: [`tb_cons.sv`](../fpga/sim/tb_cons.sv), ein reiner Unit-Test von `lisp_data_unit`.

Kein Opcode wird leichtfertig hinzugefügt: Das 4-Bit-Opcode-Feld ist voll belegt (16/16). `CALL`/`RET` (M09) und `GETTAG` (M12) erweitern bestehende Opcodes statt neue Slots zu verbrauchen.

Es gibt noch keine CI — den vollständigen Satz vor jeder Änderung lokal ausführen (Befehl oben).
