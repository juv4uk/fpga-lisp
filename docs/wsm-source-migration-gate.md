# Ворота міграції `.my` → `.wsm` для fpga-lisp (FPGA-WSM-SOURCE-MIGRATION-GATE)

**Статус:** інвентаризація + пропозиція воріт, 2026-09-08. Жоден файл тут
не перейменований і жоден протокольний контракт не змінений — це прямо
заборонено умовою самої задачі, поки ворота не прийняті.

## English

Inventory of every `fpga-lisp` consumer pinned to a literal `.my` path,
plus a proposed atomic producer+consumer gate for a future `.wsm` rename.
No files renamed here; Ukrainian section below is authoritative, this is
a mirror for non-Ukrainian readers.

---

## 1. Навіщо це потрібно

`my-lisp` і споріднені репо цієї екосистеми вже активно використовують
розширення `.wsm` поряд з historичним `.my` (взаємозамінні на рівні
парсера — див. `my-lisp`'s CLAUDE.md/оракул). Якщо колись `.my`-файли,
від яких `fpga-lisp` залежить, буде перейменовано на `.wsm` без
координації — CI/тести тут можуть мовчки зламатись (fetch по жорстко
зашитому шляху, parity-тест проти файлу, якого більше нема за старою
назвою). Ця задача — інвентаризація ризику й дизайн воріт, **не**
виконання переходу.

## 2. Повна інвентаризація `.my`-точок дотику

### 2.1 Виконувані продюсери (є Python-пара, парність оракул-перевірена)

| `.my`-файл | Python-пара | Consumer (тест/CI) |
|---|---|---|
| `assembler.my` | `assembler.py` | `tests/test_assembler_my_parity.py` (запускає обидва, звіряє байт-у-байт вивід на 28 fixtures) |
| `check-stale-refs.my` | `check_stale_refs.py` | `tests/test_stale_refs_my_parity.py` |

Обидва вже позначені задачами `FPGA-ASSEMBLER-MY-PARITY`/`FPGA-ASSEMBLER-MY-SYMBOLS`
як byte-identical parity, "Python remains bootstrap/reference pending
independent review and authority migration" — тобто явний, іменований
намір колись зробити `.my`-версію авторитетною. Саме ці два — найвищий
ризик при перейменуванні: consumer жорстко називає файл по імені
(`[str(self.my_lisp), "assembler.my", ...]`), не по патерну.

### 2.2 Дані/конфігурація, які читає тулінг (не виконувані програми)

| Файл | Хто читає | Джерело |
|---|---|---|
| `isa-contract.my` | `check_stale_refs.py` (жорстко в списку шляхів) | локально авторський |
| `repo.my`, `tasks.my` | агенти/swarm registry (за домовленим ім'ям файлу, не розширенням) | локально авторський |
| `docs/reference/conformance.my` | `fixture_coverage.py` | **синхронізується** з `my-lisp` через `sync-my-lisp.yml` (`fetch "tests/fixtures/conformance.my" "docs/reference/conformance.my"`) |
| `docs/reference/my-lisp-lib/core.my`, `meta-eval.my` | довідкові копії | те саме `sync-my-lisp.yml`, `fetch "lib/core.my" ...`, `fetch "lib/meta-eval.my" ...` |
| `contracts/my-lisp/language-contract.my`, `lock.my` | `sync-my-lisp-contract-authority.yml` | reusable workflow **з репо `my-lisp`** (`uses: juv4uk/my-lisp/.github/workflows/sync-language-contract.yml@main`) |

Це найкрихкіша категорія: `sync-my-lisp.yml` жорстко зашиває точний шлях
на боці `my-lisp` (`tests/fixtures/conformance.my`, `lib/core.my`,
`lib/meta-eval.my`). Якщо `my-lisp` перейменує ці конкретні файли на
`.wsm` без попередження — `fetch` мовчки почне тягнути неіснуючий шлях
(залежно від реалізації fetch-кроку: або явна помилка, або тихий "нічого
не змінилось" — це варто перевірити окремо, не входить у цю
інвентаризацію).

### 2.3 Заморожені evidence-артефакти (не живі consumer'и)

`evidence/G5/fpga-lisp/*.my`, `evidence/G8/fpga-lisp/*.my`,
`evidence/S1/fpga-lisp/*.my`, `evidence/upc8-fpga-lisp-integration/isa-contract-patch.my`
— хеш-іменовані історичні знімки. Жоден активний скрипт/workflow їх не
читає (перевірено grep по `.py`/`.yml`) — це архів, не production-шлях.
Ворота міграції на них не поширюються.

### 2.4 Файли без знайденого автоматичного consumer'а

`gen_symbol_table_v01.my`, `docs/equal-oracle-checklist.my` — жоден
`.py`/`.yml` файл у репо не згадує їх за іменем. Або призначені для
ручного запуску, або консюмер ще не підключений. Позначаю як "невідомо",
не "безпечно" — не перевірено достатньо, щоб стверджувати відсутність
залежності поза цим репо.

## 3. Пропозиція воріт (atomic producer+consumer gate)

Ворота діють окремо для трьох категорій вище:

1. **Локально-авторські виконувані пари (2.1)**: перейменування `.my`→`.wsm`
   дозволене ОДНИМ комітом, який одночасно перейменовує файл І оновлює
   рядок з жорстко зашитою назвою у відповідному тесті
   (`test_assembler_my_parity.py`, `test_stale_refs_my_parity.py`). Ніколи
   не розділяти на два коміти — вікно між ними ламає CI.
2. **Синхронізовані копії з `my-lisp` (2.2)**: `fpga-lisp` НЕ ініціює цю
   зміну сам — вона залежить від рішення `my-lisp` (федеративна межа,
   §9 root policy). Ворота тут: перш ніж `my-lisp` перейменує
   `tests/fixtures/conformance.my`/`lib/core.my`/`lib/meta-eval.my`,
   `sync-my-lisp.yml` у цьому репо мусить бути оновлений в тому ж вікні
   (bump шляху + перевірка, що fetch справді падає видимою помилкою, а
   не тихо), а `sync-my-lisp-contract-authority.yml` (reusable workflow
   з `my-lisp`) оновлюється автоматично разом з апстрімом — тут ризик
   нижчий, бо контракт логіки живе в `my-lisp`, не дублюється тут.
3. **Evidence-архів (2.3) і файли без consumer'а (2.4)**: поза межами
   воріт — перше не чіпається (історичний запис), друге потребує
   окремого дослідження перед тим, як зважати на нього при рейт-плануванні.

**Що ворота НЕ дозволяють**: перейменування жодного файлу з 2.1 чи
координацію з `my-lisp` щодо 2.2 без окремого явного дозволу власника —
ця задача дає лише інвентаризацію й дизайн, не виконання.
