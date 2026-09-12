# Canon migration Phase A audit (fpga-lisp, 2026-09-11/12)

## Українська

### Мета

За командою власника (переказаною через my-lisp-cyberpunk сесію,
2026-09-11): перейти fpga-lisp на архітектуру
`surface -> Canon semantic ID -> function table -> hardware mechanism`
еволюційно, без перенумерування чинного ISA. Ця Phase A фіксує знайдені
місця hardcode ДО реалізації (як вимагає план), Phase B/C вже
реалізовані в цьому ж коміті як перший вертикальний зріз.

### Знайдені місця hardcode / ручного dispatch

1. **`fpga/asm/constants.inc`** -- `SYM_QUOTE=50`, `SYM_COND=80`,
   `PRIM_CAR=0`, `PRIM_CDR=1`, `PRIM_CONS=2`, `PRIM_ATOM=3`,
   `PRIM_EQ=4`, `PRIM_ADD=5`. Це і є fpga-lisp's власний, чинний
   hardware execution ABI -- НЕ джерело проблеми, навпаки, вже
   правильний рівень абстракції (local primitive id, не spelling).
   Phase B/C будують міст ДО цих значень, не змінюючи їх.
2. **`fpga/asm/eval_core.inc`'s `try_apply`** (рядки 112-227) -- ручний
   ланцюжок `EQ`-порівнянь проти `PRIM_CAR`/`PRIM_CDR`/`PRIM_ATOM`/
   `PRIM_EQ`/`PRIM_CONS`/`PRIM_ADD` для кожного примітиву. Числа вже
   іменовані через `.define`, але сам dispatch написаний вручну для
   кожного примітиву окремо -- саме той "case spelling у різних
   місцях" патерн, який Phase D (не в цьому коміті) мала б замінити
   генерованою таблицею, БЕЗ зміни фактичного ISA/opcodes.
3. **`eval_all_primitives_demo.asm`, `eval_primitive_demo.asm`** та
   інші старі bootstrap-демо -- використовують СИРІ числові літерали
   (`50`, `80`, `1`, `3`, `4`) замість навіть `constants.inc`'s
   `.define`-констант. Старіші за `constants.inc`'s появу. НЕ чіпаються
   в цьому коміті (Phase F: "тільки після зелених доказів визначити,
   які старі дублікати можна видалити").
4. **`gen_symbol_table.py`** -- вже виправлено попереднім комітом
   (`10ca19c`): `quote`/`cond` spelling тепер береться з
   `semantic-registry.wsm` (Canon 0001/0007), а не хардкодиться. Це
   перший, вже наявний доказ принципу, на який спирається ця Phase
   B/C робота.

### Що НЕ є hardcode-проблемою (перевірено, не припущено)

`assembler.py`'s `_intern_loadsym_operands` не робить case-folding над
текстом символу-операнда (лише над opcode-мнемонікою) -- fpga-lisp не
має symbol-collision бага, аналогічного cml's `radio`/`RADIO`
(докладніше: `docs/canon-symbol-registry-fpga-lisp-part.md`).

## Phase B + C: generated Canon primitive execution table

- **`fpga/canon/execution-spec.my`** -- нове, невелике, вручну
  підтримуване джерело: яку Canon-ідентичність (`0005`, `0006`, `0004`,
  `0002`, `0003`, `0104`) яка локальна `PRIM_*`-адреса виконує. Не
  генерується, ревʼюється при кожній зміні, як і сам `constants.inc`.
- **`tools/gen_primitive_table.py`** -- fail-closed генератор: читає
  spec + реальний `semantic-registry.wsm` + реальний `constants.inc`,
  падає (не підставляє fallback), якщо: Canon ID відсутній у реєстрі,
  жодна поверхня не `stable`, `en`-поверхня (коли присутня)
  розходиться зі spec, або spec's `local_primitive_id` розходиться з
  фактичним `PRIM_*` значенням у `constants.inc`. Перевірено: усі ці
  fail-closed шляхи реально піднімають виключення (не просто
  теоретично прописані).
- **`tools/test_primitive_table.py`** -- виконуваний доказ (4/4 тести
  проходять): (1) `car`'s en/uk/sa-поверхні всі ведуть до одного
  запису таблиці (Canon `0005` -> local primitive `0` -> `OP_CAR`); (2)
  жодна поверхня не є неоднозначною між різними Canon ID в цій
  таблиці; (3) `radio`/`RADIO` (та інші довільні символи) НЕ
  зустрічаються в таблиці взагалі -- Canon identity і ordinary user
  symbol залишаються окремими просторами; (4) всі шість
  Canon-примітивів першої хвилі (car/cdr/cons/atom/eq/add) присутні з
  правильним local primitive id.

### Що НЕ зроблено в цьому коміті (свідомо)

- `fpga/asm/constants.inc`, `symbol-table.inc`, будь-який opcode,
  `TAG_PRIMITIVE`, старі `.asm`/`.bin` образи -- **не змінено і не
  перенумеровано**.
- `eval_core.inc`'s фактичний dispatch (`try_apply`) -- **не
  переведено** на генеровану таблицю (це Phase D, окремий крок з
  власним RTL/assembler regression прогоном перед комітом).
- Diferential тести проти my-lisp Canon/oracle (Phase E) -- не
  розпочато.

Це навмисно вузький, executable перший крок (Phase A audit + Phase
B/C generated bridge), а не "великий rewrite" -- відповідно до explicit
вказівки власника.

## English

Phase A audit found the real hardcode sites (`eval_core.inc`'s
`try_apply` manual `PRIM_*` dispatch chain; old pre-`constants.inc`
`.asm` demos using raw numeric literals) without touching any of them
yet. Phase B/C land in this same commit as the smallest executable
vertical proof: `fpga/canon/execution-spec.my` (hand-maintained Canon
id -> local primitive bridge) + `tools/gen_primitive_table.py`
(fail-closed generator cross-checking the real
`semantic-registry.wsm` and `constants.inc`) + `tools/test_primitive_table.py`
(4/4 passing: car's en/uk/sa surfaces all resolve to one table entry;
no surface is ambiguous across Canon ids; `radio`/`RADIO` never appear
in the table; all six first-wave primitives present with correct
local ids). No opcode, `TAG_PRIMITIVE`, `constants.inc` value, or old
image was changed or renumbered. `eval_core.inc`'s actual dispatch is
not yet switched to consume this table -- that is Phase D, a separate,
deliberately later step.
