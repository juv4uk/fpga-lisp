# FPGA TAG_TRUE replacement — physical readback, 2026-09-11

## Claim

The board running the volatile image described by the 2026-09-08 task
update executes the `ATOM`/`EQ` path as canonical `Symbol("t")`, encoded
as `TAG_SYMBOL` with payload `79`, rather than as the manufactured
`TAG_TRUE` value.

## Procedure

1. The owner pressed the board's physical RESET button during the three
   second reset window.  `rst_n` is physical pin `H11`; it cannot be
   asserted through the UART monitor.
2. Native Windows `monitor.py` opened FT2232 channel `COM4` at 115200 baud
   and uploaded `eval_all_primitives_demo.bin` (216 instructions).
3. After the program halted, the monitor sent `reg 9` and `err` over the
   monitor protocol.

## Observed result

```text
R9 = SYMBOL(79)  [0x2000004F]
ERR: no error (halted normally via HALT)
```

The uploaded file had SHA-256
`23727ad19cb45a86d13b24b651a693f4a04b6f8f599f95ac34a860fcff5fe642`.

`eval_all_primitives_demo` evaluates a path containing `cdr`, `atom`, and
`eq`; its expected final value is the positive result of `eq`.  The observed
word has tag `2` (`TAG_SYMBOL`) and payload `79`, matching `SYM_T` in
`fpga/asm/symbol-table.inc` and the current `OP_ATOM`/`OP_EQ` RTL lowering.

## Scope and limits

This is a physical SRAM-image execution result, not a claim of permanent
exFlash programming, blanket ISA conformance, or proof of every positive
`ATOM`/`EQ` input shape.  The bitstream identity is inherited from the
previously recorded 2026-09-08 SRAM programming event; this readback did not
perform a new JTAG query or write to flash.

## Українська версія

### Твердження

Плата, що виконує volatile-образ із запису задачі від 2026-09-08,
виконує шлях `ATOM`/`EQ` як канонічний `Symbol("t")`: `TAG_SYMBOL` із
payload `79`, а не як штучне значення `TAG_TRUE`.

### Процедура й результат

Власник натиснув фізичну кнопку RESET у трисекундному вікні. `rst_n` — це
фізичний пін `H11`, тому UART-monitor не може сам його встановити. Нативний
Windows `monitor.py` відкрив канал FT2232 `COM4` на 115200 baud, завантажив
216-інструкційний `eval_all_primitives_demo.bin`, а після `HALT` надіслав
`reg 9` і `err`.

```text
R9 = SYMBOL(79)  [0x2000004F]
ERR: no error (halted normally via HALT)
```

SHA-256 переданого файлу:
`23727ad19cb45a86d13b24b651a693f4a04b6f8f599f95ac34a860fcff5fe642`.
Демо проходить через `cdr`, `atom` і `eq`; його остаточне значення є
позитивним результатом `eq`. Отримане слово має tag `2` (`TAG_SYMBOL`) та
payload `79`, як `SYM_T` у `fpga/asm/symbol-table.inc` і поточне RTL
пониження `OP_ATOM`/`OP_EQ`.

### Межа доказу

Це доказ виконання SRAM-образу на фізичній платі. Він не стверджує запис у
постійний exFlash, повну ISA-conformance або перевірку кожної позитивної
форми `ATOM`/`EQ`. Ідентичність бітстріму успадкована з зафіксованого
SRAM-програмування 2026-09-08; цього разу не було нового JTAG-зчитування
чи запису у flash.
