# Технічний огляд `fpga-lisp`

**Автор огляду:** Manus AI  
**Стан джерел:** гілка `master`, переглянута 18 серпня 2026 року  
**Репозиторій:** [juv4uk/fpga-lisp][1]

## Висновок у двох реченнях

`fpga-lisp` — це вже не «CPU з кількома Lisp-інструкціями», а **апаратний substrate для Lisp**, у якому tagged values, cons-heap, базові примітиви, closure/environment і частина evaluator утворюють одну послідовну модель. Його головна цінність — не в тому, що він зараз охоплює весь `my-lisp`, а в тому, що кожен наступний шар — від `eval` до `reverse`, `append` і `equal?` — доводиться поверх тих самих фізичних Lisp-структур, а не додається як окремий магічний апаратний блок.

> **Найсильніший архітектурний вибір:** hardware знає про representation і кілька фундаментальних операцій, а не про «високорівневі фічі Lisp». Саме це дозволяє мові рости нагору, не перетворюючи HDL на великий інтерпретатор.

## 1. Що насправді будується

Конституція машини коротка, але достатньо жорстка: базовий об’єкт — Lisp value, кожне value має tag, cons-cell є фізичним об’єктом, а `CONS`/`CAR`/`CDR`/`ATOM`/`EQ` виконуються апаратно. Closure та environment при цьому залишаються Lisp-структурами, а кінцевий задум — виконувати evaluator, написаний Lisp-ом [2] [3].

```text
32-bit tagged word + physical CONS heap
                 ↓
hardware CONS / CAR / CDR / ATOM / EQ / ADD
                 ↓
minimal control ISA + UART bootloader + monitor
                 ↓
Lisp environments, closures, software call stack
                 ↓
eval over hardware primitives
                 ↓
bootstrapped core.my functions
                 ↓
CML-produced image / shared my-lisp conformance contract
```

Така побудова відрізняється від звичайного soft-core під Linux чи від bytecode VM. Тут машинне слово з самого початку має Lisp-форму, а heap не є абстракцією runtime поверх байтової пам’яті: він буквально складається з двох RAM-масивів `CAR_RAM[address]` і `CDR_RAM[address]` [3].

| Рівень | Реалізація | Чому це важливо |
|---|---|---|
| Значення | 32 біти: 4-bit tag + 28-bit payload | Semantics видимі в усьому datapath, а не заховані у runtime. |
| Heap | 4096 фізичних cons-cells, split CAR/CDR BRAM | Списки, closures і environments мають однакове представлення. |
| Примітиви | `CONS`, `CAR`, `CDR`, `ATOM`, `EQ`, `ADD` | Примітивні операції доступні і для evaluator, і для bootstrapped функцій. |
| Виконання | 16 registers, 4096-word imem, minimal ISA | ISA керує substrate, а не дублює мову. |
| Розвиток мови | eval, `null?`, `reverse`, `append`, `equal?` | Вищі можливості стають виконуваними Lisp-структурами. |

## 2. ISA: маленька, але вже не «іграшкова»

Machine-readable `isa-contract.my` фіксує версію **1.0** й робить інтерфейс переносним між FPGA, CML та іншими реалізаціями: слово, tags, bit-layout інструкції, registers, primitive IDs, memory/image framing, truth semantics і error policy описані як дані, а не лише як prose [4]. Це особливо правильне рішення для екосистеми з кількома реалізаціями.

Усі 16 верхніх opcode вже зайняті. Замість тихо ламати контракт або роздувати ISA, проєкт використовує раніше вільні поля інструкцій як **явно задокументовані modes** [4] [5].

| Основний opcode | Encoded mode | Роль |
|---|---|---|
| `MOV` | `rs2=1` | `GETTAG`: отримати tag як fixnum для evaluator dispatch. |
| `MOV` | `rs2=2` | `MAKEPRIM`: перетворити ID на `TAG_PRIMITIVE`. |
| `MOV` | `rs2=3` | `GETVAL`: витягнути payload як fixnum. |
| `CAR` | `rs2≠0` | `FETCH_PAIR`: прочитати CAR і CDR за один доступ та записати у два регістри. |
| `ATOM` | `rs2≠0` | `SETCDR`: internal bootstrap-only backpatch existing cons-cell. |
| `JMP` | `rd≠0, rs1=0` | `CALL`: записати link address і перейти. |
| `JMP` | `rd=0, rs1≠0` | `RET`: перейти за адресою з регістру. |

Це не випадкові «хаки», бо modes записані в контракті. Однак вони підвищують ціну будь-якого майбутнього розширення: після заповнення opcode-space дисципліна decoder/assembler/contract/test fixture має бути бездоганною. Історія з `FETCH_PAIR` це вже підтвердила: реальна RTL-симуляція знайшла в testbench помилкові opcode numbers та неправильне bit packing, хоча модельна перевірка не бачила проблеми [6].

## 3. Memory model: саме тут машина стає Lisp-машиною

`heap.sv` зберігає CAR і CDR у незалежних BRAM-подібних масивах. `lisp_data_unit.sv` тримає 13-bit `hp` для 12-bit address space: адреси 0–4095 валідні, а `hp=4096` — однозначний sentinel `HEAP_FULL`; отже остання доступна комірка не губиться через off-by-one [7].

| Властивість | Наслідок |
|---|---|
| Bump allocator | Простий, детермінований `CONS`; немає прихованої політики allocation. |
| Немає GC зараз | Вичерпання heap завершує машину з помилкою; це чесна межа, а не непомітна деградація. |
| Independent `we_car` / `we_cdr` | `SETCDR` змінює тільки CDR already allocated cell й не руйнує CAR. |
| 2-cycle read handshake | Control не припускає combinational RAM; `valid/error` синхронізують accessor з FSM. |
| Monitor heap peek | Після halt зовнішній інструмент бачить raw heap без змішування debug із Lisp semantics. |

Найглибша ідея тут — поява `SETCDR`. Це deliberately internal capability, а не Lisp-visible `set-cdr!`: воно потрібне для letrec-style bootstrap. Placeholder `(name . NIL)` входить у frame, closure захоплює цей frame, потім CDR placeholder дописується на closure. Так виникає необхідний цикл `placeholder → closure → environment → placeholder`, і function може знайти сама себе звичайним lookup [3].

Це водночас точно визначає майбутнє GC. Reference counting не зможе прибрати такі цикли, отже майбутній reclaim мусить бути trace-based: хоча сьогодні heap взагалі нічого не звільняє, архітектурне рішення про mark-and-sweep або його наступника вже обумовлене representation, а не смаком реалізатора [3]. Це дуже дорослий момент проєкту.

## 4. Evaluator: не окрема мікропрограма, а Lisp, що використовує машину

Найцінніша частина не в тому, що існує `eval` у asm, а в тому, як було подолано реальні обмеження substrate.

| Етап | Вирішена проблема | Архітектурний результат |
|---|---|---|
| M12 | Відрізнити symbol від fixnum | `GETTAG` mode, atom evaluator. |
| M13 | Розпізнати дані vs форму | `quote` через структуру cons. |
| M14 | Рекурсивний `cond` | Software call stack із cons-cells у R11. |
| M15–M18 | Closure apply і callable primitives | `eval '(car (cons 'a 'b)) env => a`. |
| M22–M24 | Від 2 args до довільної arity | Generic parameter/argument binding loop. |
| M26–M30 | Self/mutual recursion | letrec backpatch через internal `SETCDR`. |
| M31–M32 | Поверх substrate | `append` та structural `equal?` як Lisp functions. |

Особливо правильно, що рекурсивний evaluator не отримав «спеціальний апаратний call stack». Для nested eval використовується cons-stack: перед recursive call зберігаються continuation data, після повернення вони знімаються з R11-linked list [3]. Це доводить, що missing control structure може бути зроблена з already available Lisp material.

Так само добре обмежено `SETCDR`: він не просочується до звичайного evaluator dispatch. Він існує як bootstrap capability на межі «що потрібно, щоб мова могла виразити власну рекурсію», а не як довільна мутація, що з самого початку розмиває semantic model [4] [5].

## 5. Verification: найкраща риса репозиторію

Проєкт не зупинився на формулі «модель каже PASS». Звіт `FETCH_PAIR` чітко показує, що Python behavioral model дав правильну інтуїцію щодо RTL, але не міг перевірити elaboration/module-hierarchy/errors реального SystemVerilog testbench. Реальний `iverilog` викрив two testbench bugs — white-box FSM bypass і reversed encoding — після чого `FETCH_PAIR` отримав actual RTL-SIM-PASS, а повний regression rerun пройшов без регресій [6].

> Це хороший інженерний патерн: не замовчати невдалий перший testbench, а зберегти різницю між **MODEL-PASS**, **RTL-SIM-PASS**, **SYNTH-PASS** і **HW-PASS** як частину доказової історії.

CI встановлює Icarus Verilog, збирає asm binaries, окремо запускає `tb_fetch_pair` і далі повний перелік testbenches. Workflow зупиняється не лише на явному `FAILED`, а й на відсутності чіткого `PASSED`/`Machine Halted` verdict [8]. Це особливо корисно для HDL, де тест може формально завершитися без asserted failure, але не зробити необхідної перевірки.

Є один невеликий документаційний drift: свіжий test report описує «32-testbench regression», тоді як чинний CI перелік має 33 benches у `fpga/sim/` плюс окремий `tb_fetch_pair`. Це не виглядає як semantic проблема RTL, але хороший кандидат на маленький documentation consistency fix [6] [8].

## 6. CML і спільний контракт

`tb_cml_e2e.sv` — саме той bridge, який потрібен між compiler та hardware. Він не підставляє слова напряму в instruction memory: fixture binary завантажується через змодельований UART bootloader у тому самому framing, який описаний ISA-contract, чекає `halted`, а потім видає stable host-facing output: `RESULT_TAG`, `RESULT_VAL`, optional error/error-PC та повний structured heap dump [4] [9].

```text
my-lisp language semantics
          │
          ├── conformance fixtures
          │
          ├── canonical Rust implementation
          ├── CML compiler → binary image
          │                    │ UART image protocol
          └── fpga-lisp RTL ───┴── result + heap decoding
```

Shared `conformance.my` intentionally ширший за поточне залізо: Tier 1 описує базові semantics, Tier 2 додає exact arithmetic/reader/strings, Tier 3 — library/reasoning-level behavior [10]. Це правильно. Contract не має штучно зменшуватися до того, що FPGA already supports; натомість implementation може чесно казати, які fixture tiers або форми вже представлені hardware tests.

## 7. Де справжні межі зараз

Це сильний прототип substrate, але ще не general-purpose `my-lisp` machine. Найважливіші межі не маскуються документацією:

| Межа | Поточний стан | Найкращий наступний крок |
|---|---|---|
| Numeric tower | FIXNUM + `ADD`/`SUB`; rational/bignum лише draft representation | Спершу fixtures і semantic agreement з `my-lisp`; тільки потім RTL tags/layout. |
| Memory reclamation | Bump allocation, no GC | Не поспішати: спершу stable root model і mark/traverse invariants; RC уже виключено SETCDR cycles. |
| Physical board loop | RTL/CI/synthesis докази окремі від board workflow | Зробити один reproducible board acceptance script, що повертає той самий structured result protocol, що і CML E2E. |
| Runtime scale | 4096 imem words, 4096 cons cells, UART loading dominates sim time | Keep images compact; вимірювати instruction/heap budget per fixture before adding complexity. |
| Conformance coverage | Є сильні selected milestones, але не entire contract | Опублікувати machine-readable manifest: fixture → supported/unsupported → backend evidence. |
| Opcode headroom | 16/16 primary opcodes used | Нові можливості лише через contract-reviewed modes або software-level encoding; не робити implicit overload. |

## 8. Пріоритети, які я б обрав

**Перший пріоритет — зробити coverage contract-visible.** Додати невеликий `fpga-conformance-manifest.my` або YAML, де для кожної shared fixture буде explicit `supported`, `blocked`, `out-of-scope`, `rtl-sim`, `synth`, `board` і посилання на bench/E2E evidence. Це буде набагато цінніше за ще одну bootstrap-функцію: CML, Rust і майбутня Racket implementation одразу знатимуть, що означає «conformant on FPGA».

**Другий — стабілізувати CML E2E як не лише smoke test.** Поточний harness already returns enough data for canonical decoding. Наступний крок — набір малих compiled fixtures, що покривають як мінімум quoted data, truthiness, primitive dispatch, closure application, one recursive core function, error result і heap structure. Це зробить CML ↔ FPGA link доказом contract execution, а не лише proof that one binary reaches symbol 7.

**Третій — не додавати великий новий hardware feature до закриття resource/accounting loop.** ISA 1.0 повна, memory budget реальний, UART costs observable. Для кожного нового step варто вимагати: instruction count, peak heap, worst-case simulated time, RTL regression and (when hardware changes) synthesis/timing evidence. У тебе вже є perf counters і test discipline; їх варто перетворити на routine acceptance criteria.

## Підсумок

`fpga-lisp` є дуже переконливою частиною всієї екосистеми, бо він робить твердження `my-lisp` перевірюваним іншим видом реалізації. Rust може бути canonical runtime, CML — compiler bridge, а FPGA — **незалежна materialization того самого мінімального contract**. Це набагато цікавіше, ніж просто написати Lisp у SystemVerilog.

Найсильніший доказ зрілості — не кількість opcode чи milestone. Це готовність проєкту зафіксувати, де модель недостатня, де bench був помилковий, де контракт ширший за поточне hardware і чому майбутній GC уже constrained сьогоднішнім `SETCDR`. Така доказова дисципліна і є тим, що може дозволити `fpga-lisp` зростати без втрати власної логіки.

## References

[1]: https://github.com/juv4uk/fpga-lisp "fpga-lisp repository"
[2]: https://github.com/juv4uk/fpga-lisp/blob/master/README.md "fpga-lisp README"
[3]: https://github.com/juv4uk/fpga-lisp/blob/master/docs/lisp-machine-plan.md "Lisp-machine architecture plan and milestones"
[4]: https://github.com/juv4uk/fpga-lisp/blob/master/isa-contract.my "Machine-readable ISA contract"
[5]: https://github.com/juv4uk/fpga-lisp/blob/master/fpga/rtl/control.sv "Control FSM and opcode modes"
[6]: https://github.com/juv4uk/fpga-lisp/blob/master/docs/test-report-2026-08-17.md "FETCH_PAIR test report"
[7]: https://github.com/juv4uk/fpga-lisp/blob/master/fpga/rtl/lisp_data_unit.sv "Lisp data unit"
[8]: https://github.com/juv4uk/fpga-lisp/blob/master/.github/workflows/ci.yml "CI simulation workflow"
[9]: https://github.com/juv4uk/fpga-lisp/blob/master/fpga/sim/tb_cml_e2e.sv "CML end-to-end testbench"
[10]: https://github.com/juv4uk/fpga-lisp/blob/master/docs/reference/conformance.my "Implementation-independent conformance fixtures"
