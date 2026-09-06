# Step C: Sandhi Engine Design Proposal (2026-09-06)

**Статус:** HYPOTHESIS (pre-implementation)
**Попередня сесія:** Step B (UPC-8 hardware) + Flash (A) — CLOSED

## Контекст

ISA 1.2 додає encoded-mode MOV rs2=4/5/6 (decode/transform/predicate).
Sandhi — це наступний щабель: правила, що працюють на **парі** звуків.
Тому sandhi_engine НЕ може бути додатковим rs2-режимом в `upc8_unit`
(комбінаційний, 1 код на вхід). Потрібен **окремий sequential модуль**
з власною state machine, що ітерує правила по черзі (sūtra-processor embryo).

---

## 1. Encoding — реальні коди (верифіковано)

### Джерело authority

Формула з власного Step-B демо (`owner-reference-2026-09-06/README.md:79`):

```
base_code = 0x80 | (row << 3) | (nasal << 1) | length
```

Біти `code[7:6]=cls`, `code[5:3]=row`, `code[2]=free_bit`, `code[1]=nasal`, `code[0]=length`.
`in_skt_layer = (cls==10) && !free_bit`.

### Таблиця клас-10 голосних (UPC-8, canonical errep)

| row | Short (len=0) | Long (len=1) | SLP1 |
|-----|---------------|--------------|------|
| 0   | 0x80          | 0x81         | a / ā |
| 1   | 0x88          | 0x89         | i / ī |
| 2   | 0x90          | 0x91         | u / ū |
| 3   | 0x98          | 0x99         | ṛ / ṝ |
| 4   | 0xA0          | 0xA1         | ḷ / ḹ |
| 5   | 0xA8          | 0xA9         | e / ai |
| 6   | 0xB0          | 0xB1         | o / au |
| 7   | —             | —            | reserved |

### Напівголосні (виходи yaṇ: y/v/r/l)

З `upc8-class-table.json` (canonical layer): **y=0x0A, v=0x0B, r=0x0C, l=0x0D**.

### Помилки, яких ТРЕБА уникнути

- `upc8-class-table.json` codes (0x00–0x29) — це **SLP1-зграда символів**, НЕ
  код класу 10. Для голосних реальним кодом є `0x80+` (формула вище).
- Row 4 = ḷ, Row 5 = e/ai, Row 6 = o/au (має велику різницю для guṇa).

---

## 2. Існуючий OP_GUNA (upc8_unit.sv:136) — попередження про смисл

`upc8_transform.v`/`upc8_unit.sv` реалізують одно-кодовий GUNA:
`a→e (row0→row5)`, `i/u/ṛ/ḷ→a (rows1–4→row0)`, `e→ai`, `o→au`.

Це **НЕ** співпадає з парним sandhi guṇa (a+i→e), яке задане в команді Step C.
Приклад невідповідності: OP_GUNA(i)=a, тоді як sandhi-правило вимагає
a+i→e (результат e, а саме правило симетричне від пари, а не від одного коду).

**Рекомендація:** sandhi_engine реалізує парні правила **безпосередньо**
(власний матч за (cls,row) + власна output-мапа), не прокладаючи через
OP_GUNA upc8_unit. `upc8_unit` лишається недоторканим (верифікований залізом).
Семантика OP_GUNA окремого (одно-кодового) сенсу — питання до власника
(чи залишити як є, чи виправити у наступній ітерації).

---

## 3. Архітектура sandhi_engine

### Інтерфейс (пропозиція)

```
module sandhi_engine (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,        // pulse: begin computation
    input  logic [7:0] code_prev,    // previous sound (value[7:0]) or (value[15:8])
    input  logic [7:0] code_curr,    // current sound
    output logic       done,         // pulse: result ready
    output logic [1:0] result_mode,  // 2'b00=no change(passthrough), 2'b01=1 code out, 2'b10=2 codes out
    output logic [7:0] result_0,     // first output code
    output logic [7:0] result_1,     // second output code (yaṇ: y/v/r/l + following vowel)
    output logic       error         // 1 = invalid input / rule table fault
);
```

### State Machine

```
IDLE ──start──→ LOAD_RULE(0) ──→ APPLY ──→ CHECK_NEXT ──→ OUTPUT ──→ IDLE
                   ▲                                     │
                   └─────────── rule++ (no-match) ────────┘
```

- **LOAD_RULE (1 такт)**: завантажити правило n з вбудованої rule-таблиці.
- **APPLY (1–2 такти)**: декодувати (cls,row) пари; перевірити pattern правила;
  при збігу зафіксувати результат (result_mode, result_0/1).
- **CHECK_NEXT (1 такт)**: якщо збіг → OUTPUT; інакше rule++, якщо правила
  не вичерпано → LOAD_RULE; вичерпано → OUTPUT (passthrough, mode=00).
- **OUTPUT (1 такт)**: done=1 на 1 цикл → IDLE.

Worst case для 3 правил: ~12 тактів. Влаштовано саме як послідовний
sūtra-processor: rule-таблиця = маленький ROM констант (має 3 записи).

### Rule-таблиця (embryo, 3 записи)

Запис: `{prev_cls_match, prev_row_match, curr_cls_match, curr_row_match, apply_type, out_map}`.

| Rule | Параметр prev/curr | Результат | Sūtra |
|------|--------------------|-----------|-------|
| 1 GUNA | cs10-голосна + i/ī або u/ū | e (a+i/ī), o (a+u/ū) | 6.1.87 `ād guṇaḥ` |
| 2 SAVARNA DĪRGHA | savarṇa пара (a+ā, i+ī, u+ū) | long: ā, ī, ū | 6.1.101 `akai savarṇe dīrghaḥ` |
| 3 YAṆ | ik (i/u/ṛ/ḷ) + будь-яка голосна | y/v/r/l + та сама голосна | 6.1.77 `iko yaṇ aci` |

---

## 4. Golden cases (пропозиція для tb_sandhi.sv)

Коди у форматі реального UPC-8 (клас 10).

| # | prev | curr | очікуване правило | результат |
|---|---|---|---|---|
| G1 | 0x80 (a) | 0x88 (i) | guṇa | 1 код: 0xA8 (e) |
| G2 | 0x80 (a) | 0x89 (ī) | guṇa | 1 код: 0xA8 (e) |
| G3 | 0x80 (a) | 0x90 (u) | guṇa | 1 код: 0xB0 (o) |
| G4 | 0x80 (a) | 0x91 (ū) | guṇa | 1 код: 0xB0 (o) |
| G5 | 0x80 (a) | 0x81 (ā) | savarṇa-dīrgha | 1 код: 0x81 (ā) |
| G6 | 0x88 (i) | 0x89 (ī) | savarṇa-dīrgha | 1 код: 0x89 (ī) |
| G7 | 0x90 (u) | 0x91 (ū) | savarṇa-dīrgha | 1 код: 0x91 (ū) |
| G8 | 0x88 (i) | 0x80 (a) | yaṇ | 2 коди: [0x0A (y), 0x80 (a)] |
| G9 | 0x88 (i) | 0x90 (u) | yaṇ | 2 коди: [0x0A (y), 0x90 (u)] |
| G10 | 0x90 (u) | 0x80 (a) | yaṇ | 2 коди: [0x0B (v), 0x80 (a)] |
| G11 | 0x23 (k) | 0x80 (a) | none | passthrough: [0x23, 0x80] |

Примітки:
- Порядок правил важливий: savarṇa (Rule 2) солодше перевірити перед guṇa/yaṇ,
  оскільки a+ā має бути dīrgha, не guṇa. Ембріональний порядок: GUNA→SAV→YAṆ
  поки що дає той самий результат для цих case, але правило-порядок слід
  обговорити окремо (див. питання нижче).
- Статус G5–G7: класична savarṇa dīrgha. Для пар ідентичних кодів (a+a, i+i)
  теж dīrgha (ā/ī) — додати окремо.

---

## 5. Питання до власника (перед реалізацією)

### Q1. Порядок правил в rule-таблиці
Рекомендація: **SAVARNA → GUNA → YAṆ** (спершу savarṇa, бо a+ā можуть бути
й guṇa-кандидатом). Чи прийняти?

### Q2. Output packing
Для MOV rs2=7: як пакувати результат у регістр? Пропозиція:
`rd[15:8]=code_prev`, `rd[7:0]=code_curr` на вхід; вихід —
`rd[17:16]=result_mode`, `rd[15:8]=result_1`, `rd[7:0]=result_0`
(для passthrough mode=00, result_0=prev, result_1=curr). Прийняти?

### Q3. No-match поведінка
Non-sandhi пара (напр., k+a): повернути passthrough з mode=00, error=0
(не зупиняти потік) чи error=1? Рекомендація: **passthrough, error=0**.

### Q4. Чи включати ī/ū жгути
yaṇ правило класично працює i/u/ṛ/ḷ. Жгути лише i→y, u→v (перші 2 з 4)?
Чи повний набір (ṛ→r, ḷ→l) одразу? Рекомендація: **ембріон = i→y, u→v**
(2 з 4), щоб тримати три правила мінімальними.

### Q5. Rule-таблиця
Чи ок як ROM констант усередині sandhi_engine (максимум ~8 майбутніх правил)?
Чи повинна бути з перезаписом через UART/регістри вже зараз? Рекомендація:
**ROM констант зараз** (це embryo; перезапис — пізніше).

---

## 6. План реалізації

1. Відповіді на Q1–Q5
2. `fpga/rtl/sandhi_engine.sv` — sequential, 3 правила, rule-таблиця
3. `fpga/tb/tb_sandhi.sv` — 10+ golden cases (таблиця вище)
4. iverilog → PASS (instruction_decoder.sv першим у списку файлів)
5. Інтеграція `control.sv`: MOV rs2=7 → запуск sandhi_engine, busy-wait на done
6. `fpga/tb/tb_sandhi_machine.sv` — end-to-end через машину
7. `isa-contract.my` v1.3 — entry для sandhi mode
8. gw_sh synthesis → LUT delta
9. Hardware smoke на Tang Primer 25K (за Step-C критеріями повної команди)

---

## Evidence

- Формула коду: `owner-reference-2026-09-06/README.md:79`, `upc8_decode.v`
- Предикати: `upc8_unit.sv:49-60` (is_class10, ac_14, aṇ, ik, reserved_row)
- OP_GUNA: `upc8_unit.sv:136-151` (одно-кодовий; увага — не збігається з парним guṇa)
- SLP1-коди напівголосних: `evidence/upc8-demo/upc8-class-table.json` (y=0x0A, v=0x0B, r=0x0C, l=0x0D)
- Апаратний доказ decode: tb_upc8_machine 0x83 → 0x183 (PASS на залізі)