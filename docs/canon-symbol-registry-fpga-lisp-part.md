# fpga-lisp's part of the Canon/semantic-registry migration plan

## Українська

### Результат аудиту

fpga-lisp має **той самий клас прогалини**, що й LSP my-lisp
(quote/cond), `eval.rs` wsm-my-lisp, і `lower.rs`/`semantic.rs` cml:
[`fpga/asm/symbol-table.inc`](../fpga/asm/symbol-table.inc) —
hardcoded ASCII-написання символів (`SYM_CAR`, `SYM_QUOTE`, `SYM_T`,
...), заморожений знімок, згенерований одноразово
(`my-lisp@f32ec78`'s `scripts/symbol-table.my`, 2026-08-10), **не**
жива проекція з `semantic-registry.wsm`'s канонічних числових ID.

### Чого НЕМАЄ (перевірено, не припущено)

На відміну від cml's `radio -> RADIO` колізії: `assembler.py`'s
`_intern_loadsym_operands` (рядки 76-95) НЕ робить `.upper()`/
`.lower()` над текстом символу-операнда -- він зберігає точний
spelling як ключ Python dict (`ids[operand] = next_id`),
case-sensitive за замовчуванням. Єдині `.upper()` виклики в
`assembler.py`/`assembler_phonetic.py` стосуються opcode-мнемоніки
(`LOADSYM`, `MOV`, ...), не Lisp-даних чи символів мовного рівня --
звичайна асемблерна конвенція, не семантична втрата. **fpga-lisp не
має symbol-collision бага, аналогічного cml's.**

### Чого Є (реальна прогалина)

`symbol-table.inc`'s власний header вже чесно каже: "FROZEN SNAPSHOT,
not a live regeneration target" -- перегенерація алфавітним порядком
переномерувала б кожен `SYM_*`, вже запечений у зібрані `.asm`/`.inc`
бінарні слова. Це саме структурна причина, чому fpga-lisp досі не
споживає `semantic-registry.wsm` напряму: числовий ID тут прив'язаний
до порядку появи в `core.my`, а не до незалежного від spelling
канонічного ID реєстру.

### Пропонована частина плану (документ, не реалізація)

1. **Не міняти нічого в живому `symbol-table.inc` без deliberate
   regeneration review** -- той самий застережний протокол, що вже
   написаний у файлі, лишається чинним.
2. Якщо/коли `semantic-registry.wsm` отримає стабільний numeric ID
   для кожного символу з `lib/core.my`, fpga-lisp може згенерувати
   `symbol-table.inc` з РЕЄСТРУ замість алфавітного проходу по
   `core.my` -- та сама ідея, що й cml's запропонований `build.rs`
   генератор (cml#9), просто для asm-рівня константи замість Rust
   dispatch table.
3. Це **явно новий крок, не терміновий**: поточний frozen snapshot
   коректний і не має semantic-loss бага, на відміну від cml's
   uppercasing. Пріоритет нижчий, ніж symbol-identity gate
   (`FPGA-SHARED-ORACLE-PARITY-2`), яка блокує вже наявний
   conformance-зріз.
4. fpga-lisp координується напряму з my-lisp/wsm-my-lisp/cml, коли
   `semantic-registry.wsm` matures до точки, де regeneration має сенс
   -- не діє в односторонньому порядку.

## English

fpga-lisp has the same class of gap as my-lisp's LSP, wsm-my-lisp's
`eval.rs`, and cml's `lower.rs`/`semantic.rs`:
[`fpga/asm/symbol-table.inc`](../fpga/asm/symbol-table.inc) is a
hardcoded, frozen ASCII-spelling symbol table, generated once from
`my-lisp@f32ec78`'s `scripts/symbol-table.my`, not a live projection
from `semantic-registry.wsm`'s canonical numeric IDs.

Unlike cml's `radio -> RADIO` collision: `assembler.py`'s
`_intern_loadsym_operands` never uppercases/lowercases the symbol
operand text -- it preserves exact spelling as the dict key.
**fpga-lisp does not have a symbol-collision bug analogous to cml's.**
The only real gap is architectural: the ID assignment is tied to
alphabetical position in `core.my`, not to a spelling-independent
canonical registry ID, so regenerating it later would silently
renumber every baked-in `SYM_*` constant. Proposed part of the plan:
regenerate `symbol-table.inc` from `semantic-registry.wsm` once it
carries stable per-symbol IDs, deliberately reviewed, not automatic --
same caution the file's own header already states. Lower priority
than the already-blocking symbol-identity gate
(`FPGA-SHARED-ORACLE-PARITY-2`).
