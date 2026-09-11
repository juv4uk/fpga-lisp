# FPGA shared-oracle parity 1

## Українська

Цей gate не має власної таблиці Lisp-результатів. Він читає
`tests/fixtures/conformance.my` безпосередньо з pinned Git-об'єкта
`my-lisp`, звіряє SHA-256 всього blob з
[`tools/shared_oracle_parity.pin`](../tools/shared_oracle_parity.pin), а тоді
вибирає compiler-corpus ordinal 2 і 3. Отже source та `expected` не можуть
непомітно перетворитися на локальну FPGA-істину.

Перший зріз перевіряє лише два exact upstream cases:

1. `(atom (quote radio))`;
2. `(eq (quote radio) (quote radio))`.

Для кожного випадку скрипт викликає CML, збирає image через authoritative
`assembler.py`, завантажує його в `tb_cml_e2e` через UART boot protocol і
читає `RESULT_TAG`/`RESULT_VAL`. Декодер визнає `t` тільки як фактичне
FPGA-представлення `TAG_SYMBOL + SYM_T`, причому обидва числа витягуються з
`lisp_word.sv` і `symbol-table.inc`. Він не читає `TAG_TRUE` як нове
семантичне значення.

`tb_cml_e2e` тепер не містить захардкодженого очікування `SYMBOL(7)`.
Це transport/observation harness; semantic comparison належить цьому gate і
pinned corpus. Так ми прибрали ще одне незалежне джерело expected.

Запуск у WSL/Guix:

```bash
python3 tools/shared_oracle_parity.py \
  --my-lisp-dir /mnt/c/GitHub/my-lisp \
  --cml-dir /mnt/c/GitHub/cml \
  --cml-bin /mnt/c/GitHub/cml/target/debug/cml \
  --target-contract-dir /mnt/c/GitHub/wsm-target-contract \
  --out evidence/FPGA-SHARED-ORACLE-PARITY-1/rtl-sim-YYYY-MM-DD \
  --mutation-witness
```

`result.json` містить digest source/expected, CML binary, target-contract,
RTL source, image та transcript. `coverage.json` містить рівно 17 compiler
corpus ordinals зі статусом `confirmed` або `unsupported`. `unsupported` тут
означає саме відсутність цього FPGA witness або названу межу представлення,
а не "майже працює".

Evidence також записує Git revision і worktree status CML поруч із digest
виконаного CML binary. Це навмисно: revision без digest binary не доводить,
яким саме compiler executable створено image; digest без revision не дає
читачеві зрозуміти його місце у вихідній історії.

Фізичний запуск є окремим полем provenance. RTL simulation ніколи не
записується як board evidence. І навпаки, один board run не стає повною
conformance claim.

Найменший наступний крок після цього зрізу не потребує нового opcode чи
tag: виконати ті самі upstream source blobs для G2 (`quote`, `car`, `cdr`,
`cons`) і G8 (`cond`) через цей самий gate. Це розширює доказ існуючого
mechanism, а не винаходить нову FPGA-семантику. Exact rationals лишаються
`unsupported`, доки не ратифіковано їх representation contract.

## English

This gate owns no local Lisp expectation table. It reads the pinned
`my-lisp` compiler-corpus blob, verifies its digest, then executes ordinals
2 and 3 through CML, the authoritative assembler, UART boot simulation, and
an FPGA representation decoder. `result.json` records provenance and a
deliberate comparator-mutation witness; `coverage.json` records all 17
corpus ordinals as `confirmed` or explicitly `unsupported`.

The generic SystemVerilog harness now only emits an observation. It no longer
asserts a stale local `SYMBOL(7)` expectation. Semantic expected values come
only from the pinned upstream corpus. RTL evidence and physical-board evidence
remain explicitly separate.
