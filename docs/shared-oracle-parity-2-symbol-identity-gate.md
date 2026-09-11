# Shared-oracle parity 2: symbol-identity gate

## Українська

### Результат

Наступний shared-oracle зріз для G2/G8 **заблокований чесно**, а не
позначений `PASS` за схожістю тексту. FPGA не потребує нового opcode, tag чи
RTL для чотирьох перевірених форм; реальна межа лежить раніше — у втраті
case-sensitive identity символів під час CML lowering.

### Відтворюваний raw experiment

Pinned `my-lisp@4a5dba0d1d61103385406ef2821d76661442621c` compiler corpus
було подано в наявний CML executable, далі в authoritative `assembler.py`,
UART boot harness і реальний `iverilog`. Усі чотири програми компілюються,
завантажуються і доходять до `HALT`:

| Corpus ordinal | Upstream source | Raw FPGA observation |
| --- | --- | --- |
| 4 | `(car (quote (radio antenna)))` | `TAG_SYMBOL`, value `901` |
| 5 | `(cdr (quote (radio antenna)))` | `TAG_CONS`, heap address `1` |
| 6 | `(cons (quote radio) (quote (antenna)))` | `TAG_CONS`, heap address `3` |
| 7 | `(cond (() (quote wrong)) (t (quote right)))` | `TAG_SYMBOL`, value `901` |

`tb_cml_e2e.sv` already emits a stable `HEAP:` dump, so proper and dotted
pair shapes can be decoded from the physical representation. Thus neither
`CONS`, `CAR`, `CDR`, `JF`, nor heap observation is the missing hardware
mechanism.

### Чому raw result ще не є semantic confirmation

`my-lisp` parser зберігає spelling символу: він будує
`ExprKind::Symbol(token.into())`; `Value::Symbol` equality порівнює рядки
без case-folding. Отже `radio` та `RADIO` є різними мовними значеннями,
доки semantic authority не скаже інакше.

Поточний CML target deliberately uppercases quoted symbols:

```text
CML preflight: Quoted::Sym(name) -> name.to_uppercase()
CML emission:  symbol table lookup by name.to_uppercase()
```

Його `.bin.sym` sidecar для upstream `radio` тому містить `901 RADIO`.
Якщо FPGA comparator зараз мовчки зробить `RADIO -> radio`, він сховає саме
ту semantic loss, яку має виявляти independent hardware witness. Якщо він
просто порівняє raw spelling, він справедливо відхилить fixture. Жоден із
цих варіантів не дає підстав назвати ordinal 4–7 `confirmed` сьогодні.

### Потрібний контрактний крок

Перш ніж розширювати FPGA gate, `my-lisp` semantic authority і CML мають
ратифікувати один із двох явних шляхів:

1. **Lossless symbols:** CML/target ABI зберігають точний canonical symbol
   spelling, а `.sym` sidecar є його image-local mapping.
2. **Language-level normalization:** semantic contract прямо визначає
   normalization і доводить, що вона не змінює identity. Наразі це
   суперечить фактичному my-lisp parser/equality, тому не може бути мовчазним
   backend rule.

Після першого варіанту FPGA робота мала: decoder читає sidecar і heap dump,
порівнює відновлену структуру з upstream `expected`, повторює mutation
witness, а потім запускає ті самі images на платі. Жодного нового machine
tag, opcode або RTL design тут не потрібно.

**Live підтвердження, уточнене (2026-09-11):** my-lisp session
підтвердила `(eq (quote radio) (quote RADIO))` -> `()` на самому
my-lisp (case-sensitive identity — G1/G7 контракт). cml session потім
перевірила емпірично, реальним компілятором (не з пам'яті): той самий
вираз, скомпільований і виконаний через cml's C-бекенд, дає `T`.
Це означає, що uppercase на CML lowering (`lower.rs`, спільний для
всіх бекендів — C/FPGA/x86, не специфічний для fpga-lisp шляху) —
**не** reversible internal representation, а реальне **злиття** двох
синтаксично різних upstream-символів в один target-символ. Два різні
джерельні символи стають тотожними після компіляції — це порушення
G1/G7, не нешкідлива "representational substitution", як спершу
припускалося. cml сама це підтвердила і не запропонувала self-fix;
`ratify-then-consume` дисципліна (той самий шаблон, що й TAG_BOXED
wsm-target-contract#2 і Canon-поверхні cml#9 цієї сесії) лишається
потрібною, але тепер спирається на перевірений факт, а не гіпотезу.
fpga-lisp лишається пасивним спостерігачем цього рішення, так само як
з `ISA-RATIONAL`.

### Межі

Це не твердження, що CML уже неправильний для всіх його поточних цілей.
Це конкретний conformance blocker для exact my-lisp shared-oracle parity.
Також це не дозволяє FPGA самостійно встановлювати spelling policy.

## English

The next G2/G8 shared-oracle slice is honestly blocked on symbol identity,
not on missing FPGA hardware. Real CML → assembler → UART-loaded RTL runs
halted for `car`, `cdr`, `cons`, and `cond`; the harness already exposes the
heap needed for structural decoding. However, my-lisp preserves and compares
symbol spellings exactly, while the current CML target uppercases quoted
symbols and emits sidecar entries such as `901 RADIO` for upstream `radio`.

Lowercasing that sidecar inside the FPGA comparator would hide a semantic
loss; accepting the raw spelling would correctly reject the fixture. Exact
parity therefore needs a ratified lossless symbol ABI (or a language-level
normalization decision). Once that exists, no new FPGA opcode, tag, or RTL is
needed to confirm these fixtures.
