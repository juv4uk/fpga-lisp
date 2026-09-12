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

**Виправлення (2026-09-12):** перша версія цього коміту помилково
написала генератор на Python (`tools/gen_primitive_table.py` +
`tools/test_primitive_table.py`), прямо порушивши `juv4uk/fpga-lisp#6`
(ECO-LISP-SCRIPTS-1: "Не робити Python fallback", увесь новий
tooling -- на `.my`/`.мій`). Обидва файли видалено і переписано як
**`fpga/canon/gen-primitive-table.my`**, реальний my-lisp-скрипт
(перевірений через `cargo run -p my-lisp-cli --bin my-lisp --`, той
самий шлях, що й прецедент `scripts/symbol-table.my`).

- **`fpga/canon/execution-spec.my`** -- нове, невелике, вручну
  підтримуване джерело: яку Canon-ідентичність (`5`, `6`, `4`, `2`,
  `3`, `104`) яка локальна `PRIM_*`-адреса виконує, з ЛІТЕРАЛЬНОЮ
  назвою константи (`PRIM_CAR`, не похідною через uppercase --
  my-lisp принципово не має case-folding примітиву). Не генерується,
  ревʼюється при кожній зміні, як і сам `constants.inc`.
- **`fpga/canon/gen-primitive-table.my`** -- fail-closed генератор +
  вбудовані evidence-перевірки в одному скрипті: читає spec + реальний
  `semantic-registry.wsm` (через `read-file`/`read-all`, нативний
  s-expr reader, без regex) + реальний `constants.inc` (той самий
  reader читає `.define`-синтаксис як плоский список атомів). Падає
  (не підставляє fallback), якщо: Canon ID відсутній у реєстрі, жодна
  поверхня не `stable`, `en`-поверхня (коли присутня) розходиться зі
  spec, або spec's `local-primitive-id` розходиться з фактичним
  `PRIM_*` значенням у `constants.inc`. Перевірено: усі ці fail-closed
  шляхи реально піднімають помилку виконання (exit code 1).
- Вбудовані evidence-перевірки (усі 7 реально проходять під реальним
  `my-lisp.exe`, не лише написані): (1) `car`'s en/uk/sa-поверхні всі
  ведуть до одного запису таблиці (Canon `5` -> local primitive `0` ->
  `OP_CAR`); (2) жодна поверхня не є неоднозначною між різними Canon ID
  в цій таблиці; (3) `radio` І `RADIO` (окремо) НЕ зустрічаються в
  таблиці взагалі -- Canon identity і ordinary user symbol залишаються
  окремими просторами; (4) всі шість Canon-примітивів першої хвилі
  (car/cdr/cons/atom/eq/add) присутні з правильним local primitive id.

### Реальні баги, знайдені під час портування на my-lisp

Не суто механічний переклад -- три реальні логічні баги знайдено й
виправлено емпіричним тестуванням проти справжнього `my-lisp.exe`
(жоден з них не існував у Python-версії, специфічні для порту):

1. **`atom` не відрізняє "не знайдено" (`()`) від "знайдено, значення
   0"** -- `PRIM_CAR`'s значення справді `0`, а `0` сам є atom.
   `(atom const-value)` як перевірка "не знайдено" хибно спрацьовувала
   і для дійсно знайденого нульового значення. Виправлено на явне
   `(eq const-value (quote ()))`.
2. **Власноруч написаний `if` як звичайна функція** eager-обчислював
   усі три аргументи (включно з тим, що мав виконатись, лише якщо
   умова хибна) -- зламало б `(car (quote ()))` на відсутній
   поверхні, хоч і не проявилося на поточних 6 записах (у всіх є uk/sa).
   Замінено на прямий `cond` (lazy за конструкцією), `if` прибрано.
3. **`reduce`'s аргументи переплутано.** `(reduce f acc values)` --
   не `(reduce f values acc)`, як спочатку написано; переплутаний
   порядок призвів до того, що `reduce` одразу повертав `table`
   некрутнутим замість акумуляції поверхневих слів, і подальший `eq`
   на елементі-списку (не atom) впав з "eq expects two atoms".
4. **`princ`/`print`-вивід губиться при подальшій фатальній помилці**
   (буфер не флешиться перед абортом) -- fail-closed діагностичне
   повідомлення через `princ` перед навмисною помилкою ніколи не
   з'являлося на екрані. Виправлено: замість друку повідомлення,
   воно вбудовується безпосередньо в текст помилки через
   `(eval (string->symbol msg))` -- посилання на незв'язаний символ
   виводить його точний текст в "unknown symbol" помилці, що реально
   видно користувачу.

Усі чотири підтверджені прогоном, не лише виправлені "на око":
спочатку відтворено помилку, потім перевірено зникнення після фіксу.

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
yet. Phase B/C land as the smallest executable vertical proof:
`fpga/canon/execution-spec.my` (hand-maintained Canon id -> local
primitive bridge, literal `PRIM_*` constant names, no case-folding
needed) + `fpga/canon/gen-primitive-table.my` (a real my-lisp script,
run via `cargo run -p my-lisp-cli --bin my-lisp --`, matching the
`scripts/symbol-table.my` precedent). It fails closed against the real
`semantic-registry.wsm` and `constants.inc`, and its 7 embedded
evidence checks all pass under the real interpreter: car's en/uk/sa
surfaces all resolve to one table entry; no surface is ambiguous
across Canon ids; `radio` and `RADIO` (separately) never appear in the
table; all six first-wave primitives present with correct local ids.

**Correction, 2026-09-12:** this work was first written in Python
(`tools/gen_primitive_table.py`/`test_primitive_table.py`), directly
violating `juv4uk/fpga-lisp#6` (ECO-LISP-SCRIPTS-1, decided the same
day: no new Python tooling). Both files were deleted and rewritten as
the `.my` script described above. Porting surfaced three real logic
bugs specific to the port, none present in the Python version, each
reproduced then confirmed fixed against the real interpreter: `atom`
cannot distinguish "not found" from "found, value 0" (`PRIM_CAR`'s
real value); a hand-written `if` as an ordinary function eagerly
evaluated all three arguments instead of short-circuiting; `reduce`'s
argument order is `(f acc values)`, not `(f values acc)`. Also found:
`princ`/`print` output is buffered and lost when the process later
exits on error, so the fail-closed diagnostic is now surfaced by
referencing it as an unbound symbol instead (my-lisp's "unknown
symbol" error embeds the exact text).

No opcode, `TAG_PRIMITIVE`, `constants.inc` value, or old image was
changed or renumbered. `eval_core.inc`'s actual dispatch is not yet
switched to consume this table -- that is Phase D, a separate,
deliberately later step.
