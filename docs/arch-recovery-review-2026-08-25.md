# Architecture Recovery Review — fpga-lisp

**Дата:** 2026-08-25 · **Автор:** Vyasa (COMPILER STEWARD)
**Тип:** read-only recovery review · **Задача:** ARCH-RECOVERY-REVIEW-FPGA
**Ресурси:** читання коду/доків/плану; білди й симуляції не запускався

---

## 1. As-built архітектура

```
Інструментарій (self-hosting):
  assembler.my (423 ряд.)   — збірка .asm → .bin, LOADSYM-intern, .include
  scripts/symbol-table.my   — канонічна алфавітна таблиця символів core.my
  job_transport.py (133)    — CML↔UART бридж (COM4/pyserial; I/O межа,
                              свідомо НЕ переноситься в Lisp за директивою)

RTL (9 модулей SystemVerilog):
  lisp_machine.sv (top, 204) ├── bootloader.sv (204, ISA 1.0+1.1 extended hdr)
  ├── instruction_decoder ├── control (eval_core dispatch) ├── registers
  ├── lisp_word.sv (tagged word: TAG_FIXNUM/TAG_PAIR/PRIMITIVE...) 
  ├── heap (car_ram/cdr_ram) ├── uart └─(monitor reg/error protocol)

Симуляція: 35 testbench-ів (tb_*.sv), кожен мілстон має фізичний прогон-файл.

ISA: 1.0 (legacy boot frame, byte-identical гарантовано) →
     1.1 (extended boot header: bit15, ≤16 tagged register inits, dup forbidden)

Мілістони: M1..M33 задокументовані в docs/lisp-machine-plan.md з per-step
evidence; чесні retraction-історії збережені (M28 forgotten-quote → fix pattern).
```

## 2. Сильні сторони (перевірені сьогодні)

1. **Evidence-first культура**: кожен мілстоун = testbench + реальний прогон +
   результат у плані; помилки не приховуються (M28 «forgotten quote» описано).
2. **ISA еволюція назад-сумісна**: 1.1 розширює, не ламає (byte-identity).
3. **Межа I/O чиста**: serial/pyserial лишаються Python; ядро Lisp-частини
   самодостатнє (директива міграції дотримана без додаткових рухів).
4. **Оракульний звʼязок**: bootstrap результати звірялись проти my-lisp TCP
   oracle sexpr-протоколу (M31/M32 evidence).
5. **G8 truthiness і SETCDR-boundary** явно зафіксовані в isa-contract notes.

## 3. Відкриті фронти (за планом/гейтами)

| Фронт | Стан |
|---|---|
| ISA-RATIONAL | BLOCKED gate: limb-base fixture з мого sign-off G1-G5 (07e5ffe); value-equivalence умовно прийнято, RTL не почато |
| M33 → physical board + CML payload | RTL-sim only зараз; окремі наступні кроки |
| Full regression | CI gate за owner resource policy (локально не ганяється) |
| Single-cycle pratyāhāra claims (bitmask64) | RTL для твердження не існує — claim чесно не підвищено |

## 4. Ризики / борги

1. **MED — регресійне вікно**: 35 tb + повний набір прогонів потребує
   спокійного вікна; останні ISA 1.1 зміни пройшли тільки targeted tb.
2. **MED — dual numbering**: hand-written PROGRAM_SYMBOLS (28 програм)
   проти канонічного symbol-table.my — міграційний гейт зафіксований
   (ba0fa0b), ренумерація очікує text-primitives ратифікації.
3. **LOW — bootloader.sv зріст**: 204 рядки з двома форматами заголовків;
   наступна ISA-версія має винести парсер заголовків в окремий блок.

---
*Read-only: код/симуляції не змінювались. Усі твердження — з файлів репо.*
