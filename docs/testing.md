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
| M15 | [`tb_eval_apply.sv`](../fpga/sim/tb_eval_apply.sv) | `eval` applies an M11 closure to an argument: evaluates the operator and argument, binds the parameter by extending the closure's captured env, evaluates the body in the new env. `(identity 42) => 42` — closes the plan's first big phase. |
| M16 | [`tb_eval_primitive.sv`](../fpga/sim/tb_eval_primitive.sv) | `eval` also dispatches to hardware `CAR`/`CONS` when the operator evaluates to a new `TAG_PRIMITIVE` marker instead of a closure. `(eval '(car (cons 'a 'b)) env) => a` — the plan's literal Etap-1 goal. Program is read from `eval_primitive_demo.bin` via `$fread` rather than hand-transcribed (190 instructions). |
| M17 | [`tb_error_recovery.sv`](../fpga/sim/tb_error_recovery.sv) | A `CAR`/`CDR`/`CONS` type error now halts cleanly (`ST_WAIT_LDU` -> `ST_HALT`) instead of hanging forever, and monitor command `0x04` reports `{err_flag, err_pc}` for diagnosis. |
| M18 | [`tb_eval_all_primitives.sv`](../fpga/sim/tb_eval_all_primitives.sv) | Extends M16's primitive dispatch (`car`, `cons`) with `cdr`, `atom`, `eq` — all five hardware primitives are now callable from `eval` as ordinary procedures. `(eq (atom (cdr (quote (a . b)))) (atom (quote c))) => TRUE`. |
| M19 | [`tb_bootstrap_nullp.sv`](../fpga/sim/tb_bootstrap_nullp.sv) | The first function ported from my-lisp's `lib/core.my`: `null?`, as a closure whose body calls the `eq` primitive. `(null? NIL) => TRUE`, `(null? (quote a)) => NIL`. Assembled externally (216 instructions), read via `$fread`. |
| M20 | [`tb_bootstrap_second.sv`](../fpga/sim/tb_bootstrap_second.sv) | `second` from `core.my`: a closure body chaining two primitive calls (`car` of `cdr`). `(second (quote (x y z))) => y`. |
| M21 | [`tb_bootstrap_not.sv`](../fpga/sim/tb_bootstrap_not.sv) | `not` from `core.my`: a closure body built from `cond` rather than a primitive application. `(not NIL) => TRUE`, `(not (quote a)) => NIL`. |
| M22 | [`tb_bootstrap_pair.sv`](../fpga/sim/tb_bootstrap_pair.sv) | `pair` from `core.my`: the first two-parameter closure. `params` is a 2-element list, distinguished from the 1-arg shape via `ATOM`. `(pair 'a 'b) => (a b)`. |
| M23 | [`tb_bootstrap_caar.sv`](../fpga/sim/tb_bootstrap_caar.sv) | `caar` from `core.my`: same chained-primitive shape as M20's `second`, but `car` of `car`. `(caar '((x y) z)) => x`. |
| M24 | [`tb_bootstrap_triple.sv`](../fpga/sim/tb_bootstrap_triple.sv) | Closures generalized from a hardcoded two-parameter case (M22) to a real N-ary binding loop. `(lambda (a b c) (cons a (cons b c)))` applied to `('x 'y 'z) => (x y . z)` — first proof beyond N=2. |

There is also [`tb_cons.sv`](../fpga/sim/tb_cons.sv), a unit-level test of `lisp_data_unit` alone (no bootloader, no control unit) — the very first thing that ever worked in this project.

`tb_eval_primitive.sv` is the one exception to "hand-transcribed hex words in the testbench": at 190 instructions, hand-transcription was too error-prone, so it reads `eval_primitive_demo.bin` directly via `$fread`. Assemble it first: `python assembler.py eval_primitive_demo.asm` (the `.bin` is a gitignored build artifact, not committed).

No opcode is added lightly: the 4-bit opcode field has been full (16/16) since `LOADSYM` claimed the unused `OP_JT` slot. `CALL`/`RET` (M09) and `GETTAG` (M12) both extend existing opcodes (`JMP`, `MOV`) by giving meaning to previously-ignored instruction fields, rather than consuming new slots — check the commit history and `lisp-machine-plan.md`'s status section before assuming a new instruction is the only way to add a capability.

No CI runs these yet; run the full set locally before trusting a change:

```bash
for tb in tb_cons tb_atom_eq tb_machine tb_monitor tb_control tb_list tb_call tb_env tb_lambda tb_eval_atom tb_eval_quote tb_eval_cond tb_eval_apply tb_eval_primitive tb_error_recovery tb_eval_all_primitives tb_bootstrap_nullp tb_bootstrap_second tb_bootstrap_not tb_bootstrap_pair tb_bootstrap_caar tb_bootstrap_triple; do
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
| M15 | [`tb_eval_apply.sv`](../fpga/sim/tb_eval_apply.sv) | `eval` застосовує closure з M11 до аргументу: обчислює оператор і аргумент, зв'язує параметр через розширення захопленого середовища, обчислює тіло в новому середовищі. `(identity 42) => 42` — закриває перший великий етап плану. |
| M16 | [`tb_eval_primitive.sv`](../fpga/sim/tb_eval_primitive.sv) | `eval` також диспетчерить на апаратні `CAR`/`CONS`, коли оператор обчислюється до нового маркера `TAG_PRIMITIVE` замість closure. `(eval '(car (cons 'a 'b)) env) => a` — буквальна мета Етапу 1 плану. |
| M17 | [`tb_error_recovery.sv`](../fpga/sim/tb_error_recovery.sv) | Тип-помилка `CAR`/`CDR`/`CONS` тепер чисто зупиняє машину (`ST_WAIT_LDU` → `ST_HALT`) замість вічного зависання; команда монітора `0x04` повертає `{err_flag, err_pc}`. |
| M18 | [`tb_eval_all_primitives.sv`](../fpga/sim/tb_eval_all_primitives.sv) | Розширює диспетчеризацію M16 (`car`, `cons`) на `cdr`, `atom`, `eq` — усі п'ять апаратних примітивів тепер викликані з `eval` як звичайні процедури. |
| M19 | [`tb_bootstrap_nullp.sv`](../fpga/sim/tb_bootstrap_nullp.sv) | Перша функція, перенесена з `lib/core.my` my-lisp: `null?` як closure, тіло якого викликає примітив `eq`. `(null? NIL) => TRUE`, `(null? (quote a)) => NIL`. |
| M20 | [`tb_bootstrap_second.sv`](../fpga/sim/tb_bootstrap_second.sv) | `second` з `core.my`: тіло closure ланцюжком викликає два примітиви (`car` над `cdr`). `(second (quote (x y z))) => y`. |
| M21 | [`tb_bootstrap_not.sv`](../fpga/sim/tb_bootstrap_not.sv) | `not` з `core.my`: тіло closure побудоване з `cond`, а не аплікації примітиву. `(not NIL) => TRUE`, `(not (quote a)) => NIL`. |
| M22 | [`tb_bootstrap_pair.sv`](../fpga/sim/tb_bootstrap_pair.sv) | `pair` з `core.my`: перша двопараметрична closure. `params` — 2-елементний список, розрізнюваний через `ATOM`. `(pair 'a 'b) => (a b)`. |
| M23 | [`tb_bootstrap_caar.sv`](../fpga/sim/tb_bootstrap_caar.sv) | `caar` з `core.my`: той самий патерн, що й M20's `second`, але `car` над `car`. `(caar '((x y) z)) => x`. |
| M24 | [`tb_bootstrap_triple.sv`](../fpga/sim/tb_bootstrap_triple.sv) | Closures узагальнено з жорсткого двопараметричного випадку (M22) до справжнього N-арного циклу зв'язування. `(lambda (a b c) (cons a (cons b c)))`, застосована до `('x 'y 'z)`, дає `(x y . z)` — перше підтвердження для N>2. |

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
| M15 | [`tb_eval_apply.sv`](../fpga/sim/tb_eval_apply.sv) | `eval` wendet eine Closure aus M11 auf ein Argument an — schließt die erste große Phase des Plans ab. `(identity 42) => 42`. |
| M16 | [`tb_eval_primitive.sv`](../fpga/sim/tb_eval_primitive.sv) | `eval` dispatcht auch an Hardware-`CAR`/`CONS`, wenn der Operator zu einem neuen `TAG_PRIMITIVE`-Marker ausgewertet wird. `(eval '(car (cons 'a 'b)) env) => a`. |
| M17 | [`tb_error_recovery.sv`](../fpga/sim/tb_error_recovery.sv) | Ein `CAR`/`CDR`/`CONS`-Typfehler haelt die Maschine nun sauber an, statt fuer immer zu haengen; Monitor-Befehl `0x04` liefert `{err_flag, err_pc}`. |
| M18 | [`tb_eval_all_primitives.sv`](../fpga/sim/tb_eval_all_primitives.sv) | Erweitert M16s Dispatch (`car`, `cons`) um `cdr`, `atom`, `eq` — alle fuenf Hardware-Primitive sind nun als Prozeduren aus `eval` aufrufbar. |
| M19 | [`tb_bootstrap_nullp.sv`](../fpga/sim/tb_bootstrap_nullp.sv) | Die erste aus my-lisps `lib/core.my` portierte Funktion: `null?` als Closure, deren Body das `eq`-Primitiv aufruft. |
| M20 | [`tb_bootstrap_second.sv`](../fpga/sim/tb_bootstrap_second.sv) | `second` aus `core.my`: ein Closure-Body, der zwei Primitive verkettet (`car` von `cdr`). |
| M21 | [`tb_bootstrap_not.sv`](../fpga/sim/tb_bootstrap_not.sv) | `not` aus `core.my`: ein Closure-Body aus `cond` statt einer Primitiv-Anwendung. |
| M22 | [`tb_bootstrap_pair.sv`](../fpga/sim/tb_bootstrap_pair.sv) | `pair` aus `core.my`: die erste zweiparametrige Closure. |
| M23 | [`tb_bootstrap_caar.sv`](../fpga/sim/tb_bootstrap_caar.sv) | `caar` aus `core.my`: gleiche Form wie M20s `second`, aber `car` von `car`. |
| M24 | [`tb_bootstrap_triple.sv`](../fpga/sim/tb_bootstrap_triple.sv) | Closures von einem hartkodierten Zweiparameterfall (M22) auf eine echte N-äre Bindungsschleife verallgemeinert. `(lambda (a b c) (cons a (cons b c)))` angewandt auf `('x 'y 'z) => (x y . z)` — erster Beweis über N=2 hinaus. |

Auch vorhanden: [`tb_cons.sv`](../fpga/sim/tb_cons.sv), ein reiner Unit-Test von `lisp_data_unit`.

Kein Opcode wird leichtfertig hinzugefügt: Das 4-Bit-Opcode-Feld ist voll belegt (16/16). `CALL`/`RET` (M09) und `GETTAG` (M12) erweitern bestehende Opcodes statt neue Slots zu verbrauchen.

Es gibt noch keine CI — den vollständigen Satz vor jeder Änderung lokal ausführen (Befehl oben).
