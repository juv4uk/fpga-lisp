# SENS language core — exact-domain identity

Цей документ описує технічну модель Contract 11.

Для концептуального пояснення, чому SENS перейшов до domain-law growth, див. [`domain-paradigm.uk.md`](domain-paradigm.uk.md).

## Canonical semantic identity

Канонічний semantic object:

```text
exact binary object
+ exact domain
+ proved / ratified law
```

Bits не несуть значення самі по собі. Width не надає occupancy, callability чи semantic membership.

Однаковий packed payload у різних доменах — різні identity:

```text
D3 001 != D4 0001 != D5 00001 != D6 000001
```

Zero-padding, truncation, low-bit extraction або integer equality не можуть створити чи відновити domain identity.

---

## Current domain-width ladder and ratification status

```text
D1  exact one-bit PredicateBit — RATIFIED
D2  exact two-bit structural syntax — RATIFIED
D3  exact three-bit Core foundation — RATIFIED
D4  exact four-bit bootstrap — RATIFIED
D5  exact five-bit full compact domain — RATIFIED #3305
D6  exact six-bit full compact domain — RATIFIED #3393
D7  exact seven-bit sound/text domain — RATIFIED #3572 (126/128)
D8  exact eight-bit research carrier — UNRATIFIED
```

General exact-width carrier має зберігати W1…W8 без втрати width. Semantic domain admission is separate from carrier existence. D5 re-ratified #3305 after the #3278 reset; D6 is ratified #3393; D7 is ratified #3572; D8 remains the unratified research carrier.

При цьому:

```text
carrier existence
≠ residency
≠ derivability
≠ callability
≠ runtime implementation
```

Це одна з основних дисциплін Contract 11.

---

## D1 — PredicateBit

```text
0 = NO
1 = YES
```

PredicateBit не є Number, host Bool, T/NIL або structural empty.

Третього predicate-result немає.

---

## D2 — structure

```text
00  separator
01  close
10  open
11  dot
```

Це exact structural-domain objects, а не function identities.

---

## D3 — foundation

```text
000  structural empty ()
001  QUOTE
010  ATOM
011  CDR
100  CAR
101  EQ
110  COND
111  CONS
```

Назви — documentation/surface projections. Canonical identity — точна D3 coordinate під D3 law.

### Ратифікована конституція L1–L5 (#3202)

```text
L1  000 = ()
L2  D3 = exact D2-prefix fibre + one child bit
L3  one uniform semantic duality on D3
L4  dual3(x) = x XOR 111
L5  suffix-0 = evaluator/metalinguistic spine
```

D2-prefix fibres:

```text
00 → ()    / QUOTE
01 → ATOM  / CDR
10 → CAR   / EQ
11 → COND  / CONS
```

D3 semantic duals:

```text
()    ↔ CONS
QUOTE ↔ COND
ATOM  ↔ EQ
CDR   ↔ CAR
```

Suffix-0 spine: `() → ATOM → CAR → COND`.
Suffix-1 companion side: `QUOTE → CDR → EQ → CONS`.

L1–L4 звужують повний простір перестановок до двох орієнтацій; L5 є окремою ратифікованою аксіомою орієнтації, що вибирає цю карту.

### Predicate/control law

- `ATOM` повертає тільки D1 PredicateBit.
- `EQ` повертає тільки D1 PredicateBit у своїй admissible області.
- `COND` має двопольові clauses `(test expression)`.
- D1 `1` вибирає clause.
- D1 `0` переходить до наступного.
- exhaustion повертає D3 structural `()`, а не predicate false.

---

## D4 — bootstrap

D4 — owner-ratified full compact four-bit bootstrap domain (#3272).

```text
0000  APPLY
0001  EVAL
0010  LAMBDA
0011  DEFINE
0100  NOT
0101  NULL
0110  CDAR
0111  CDDR
1000  CAAR
1001  CADR
1010  LOOKUP
1011  BIND
1100  EVCON
1101  EVLIS
1110  LIST
1111  APPEND
```

D4 щільний: усі 16 координат зайняті. Це не означає, що всі 16 є незалежними примітивами.

Класифікація:
- нові bootstrap capabilities: `LAMBDA`, `DEFINE`;
- generated selectors: `CAAR`, `CADR`, `CDAR`, `CDDR`;
- derived bootstrap residents: `APPLY`, `EVAL`, `LOOKUP`, `BIND`, `EVCON`, `EVLIS`;
- compact derived conveniences: `NOT`, `NULL`, `LIST`, `APPEND`.

D4 fibres пам'ятають семантичного D3-батька:

```text
000 EMPTY → APPLY / EVAL
001 QUOTE → LAMBDA / DEFINE
010 ATOM  → NOT / NULL
011 CDR   → CDAR / CDDR
100 CAR   → CAAR / CADR
101 EQ    → LOOKUP / BIND
110 COND  → EVCON / EVLIS
111 CONS  → LIST / APPEND
```

`NOT` і `NULL` не є синонімами: D1 `0` ≠ structural D3 `()`. `NOT` працює з PredicateBit, а `NULL` перевіряє structural empty.

`LIST` і `APPEND` — CONS-family residents: перший збирає значення у список, другий з'єднує списки.

Старі D4/SID8/Sens8/Function8 координати не мають placement authority. Історія може бути донором capability, але координата визначається чинним D3/D4 law та owner-ratification #3272.

---

## D5 — full compact five-bit domain

D5 **OWNER-RATIFIED #3305**, 32/32 occupied, 32 distinct residents, zero lower-domain duplicates.

```text
00000 EVALQUOTE    00001 FUNCTION
00010 FEXPR        00011 MACRO
00100 LABEL        00101 PROG
00110 SET          00111 SETQ
01000 ZEROP        01001 NUMBERP
01010 PLUS         01011 DIFFERENCE
01100 CDAAR        01101 CDADR
01110 CDDAR        01111 CDDDR
10000 CAAAR        10001 CAADR
10010 CADAR        10011 CADDR
10100 REVERSE      10101 REVERSE-ONTO
10110 TIMES        10111 QUOTIENT
11000 GO           11001 RETURN
11010 LESSP        11011 GREATERP
11100 ASSOC        11101 MEMBER
11110 PAIRLIS      11111 SUBST
```

Внутрішня логіка D5 локальна, не глобальна:

- **5 SEMANTIC-GENERATOR** families, включно з чотирма selector-pairs та `REVERSE/REVERSE-ONTO`;
- **5 LOCAL-ALGEBRA** families;
- **2 MULTI-DELTA-FAMILY** pairs;
- **4 COORDINATE-HISTORICAL** pairs, для яких ратифіковано residency/coordinate, але не вигадано неіснуючий закон.

Selector-family:

```text
D4:0110 CDAR -> 01100 CDAAR / 01101 CDADR
D4:0111 CDDR -> 01110 CDDAR / 01111 CDDDR
D4:1000 CAAR -> 10000 CAAAR / 10001 CAADR
D4:1001 CADR -> 10010 CADAR / 10011 CADDR
```

List generator-family:

```text
10100 REVERSE
10101 REVERSE-ONTO

REVERSE(x) = REVERSE-ONTO(x, ())
REVERSE-ONTO(x,y) = APPEND(REVERSE(x), y)
APPEND(x,y) = REVERSE-ONTO(REVERSE(x), y)
```

`APPEND` не дублюється в D5: єдина чинна identity — `D4:1111 APPEND`.

D5 semantic residency не дорівнює готовності всіх runtime mechanisms. Exact W5 coordinate є чинною D5 identity; якщо конкретний механізм ще не підключений, invocation fail-closed.

Нормативні машинні джерела: `contracts/d5-ratification.lisp`, `knowledge/d5-ratified.json`.

---

## D6 — full compact six-bit domain

D6 **OWNER-RATIFIED #3393**, 64/64 occupied, 64 distinct residents.

Нормативні машинні джерела: `contracts/d6-ratification.lisp`, `knowledge/d6-ratified.json`, Contract 11.6.

Coordinate basis зберігає походження доказу:
- 16 selector-generator coordinates — proved;
- 16 law-anchored coordinates — owner-ratified;
- 32 S4 gauge coordinates — owner-ratified coordinate choice after the S3 theorem fixed the common LSB fibre axis.

Ратифікація S4 gauge робить ці координати нормативними identity, але не переписує історію доказу: gauge choice лишається відмінним від семантичного derivation theorem. Стара історична D6 64/64 карта лишається donor/provenance only. D6 residency не гарантує runtime callability; відсутній mechanism fail-closed.

---

## D7 — owner-ratified sound/text domain

D7 **OWNER-RATIFIED #3572**, 126/128 admitted residents. Нормативні машинні джерела: `contracts/d7-ratification.lisp`, `knowledge/d7-ratified.json`, Contract 11.6.

Поточний cut складається з 107 baseline-recovered residents та 19 owner-admitted same-coordinate Shiva overlays. Координати `0100001` і `0101010` лишаються owner-reserved/pinned — це не вільні opcode-и.

Рольова межа лишається суворою: Text digits є Text, не Number; LocalOrdinal — окрема W7 role і не витрачає Sound/Text occupancy. D7 residency не робить домен generic callable Core.

Фонологічні witnesses зберігають свою силу без переписування provenance: varga 5×5 product, vowel 7×2×2 із `length XOR 0000001` та `nasal XOR 0000010`, а non-varga має локальні/shared-factor закони без примусового глобального place-axis.

Hakāradvitva `43/43` належить D14 grammar topology: для 42 unique sounds точна interval ceiling = `39/43`, а `43/43` виникає лише на 43-node grammar path з h₁/h₂. Це має **zero D7 coordinate effect** і не доводить існування двох фонетичних h.

Shiva candidate D (`h/r/l` migration + відмова від двох ḹ-line identities) **не входить** у #3572 і потребує окремого owner decision (#3432).

---

## D8 — exact eight-bit research space

D8 наразі **UNRATIFIED / RESEARCH** (#3278, clean-room #3281).

Bit8/W8 механіка може існувати, але 8 physical bits не створюють Core.D8 semantics, callability або occupancy. Legacy Function8/Sens8 та старі D8 maps є лише donor/provenance evidence.

---

## Generative families

Contract 11 допускає і заохочує law-derived residents.

Selector positive control:

```text
roots:
100 = CAR
011 = CDR

laws:
suffix 0 = compose CAR / A
suffix 1 = compose CDR / D
```

Звідси:

```text
D4 selector slice inside the ratified #3272 map:
1000 CAAR
1001 CADR
0110 CDAR
0111 CDDR
```

і далі родина продовжується за тим самим законом у ширших доменах, де цей law admitted.

Кожен generated resident бажано має certificate:

```text
root + path + law version -> coordinate
```

---

## UNKNOWN

UNKNOWN/free — epistemic status.

Він не означає:

- spare opcode;
- permission to allocate;
- zero semantics;
- future callable slot.

UNKNOWN означає, що canonical law/evidence ще не пояснив coordinate.

---

## Reader

Canonical binary reader зберігає exact width до semantic routing.

```text
10 001 01
```

структурно читається як:

```text
D2 open
W3 exact word 001
D2 close
```

Reader не має zero-extend W3 до W8 для того, щоб знайти meaning.

Apostrophe на початку expression — reader sugar для already-admitted D3 QUOTE.

---

## Surfaces

Human-language і symbolic spellings — optional projections:

```text
surface/UI input
      ↓
mechanical projection
      ↓
exact domain identity
```

Заборонені моделі:

```text
name -> meaning
raw integer -> guessed domain
width -> semantic role
host enum -> language identity
```

Surface registry може допомогти знайти already-admitted identity. Він не створює semantic law.

---

## AST

Canonical AST має зберігати domain-qualified identity:

```text
DomainIdentity {
    domain,
    exact_bits,
    law/provenance
}
```

Human spelling може зберігатися окремо для diagnostics/source mapping, але не визначає equality.

---

## Compiler / lowering

Бажаний one-way pipeline:

```text
surface
  ↓
domain-qualified AST
  ↓
law-aware lowering
  ↓
IR
  ↓
backend
```

Після semantic lowering backend не повинен повторно вгадувати domain із packed bits.

Compatibility adapters дозволені лише як явно обмежені migration/backend boundaries.

---

## Execution profiles

Core1/Core2/Core3/Core4 у старих дослідженнях — execution/research profiles та historical stages, а не альтернативні semantic universes.

Поточна exact-width ladder W1–W8 є спільною механічною основою. Чинна semantic ratification охоплює D1–D7; D5 ratified #3305, D6 ratified #3393, D7 ratified #3572, а D8 лишається research.

Profile може вибирати mechanism, але не може:

- mint new identity;
- renumber domain;
- змінити PredicateBit law;
- змінити D3 control law;
- оголосити raw backend code canonical identity.

---

## Execution mechanisms

Rust runtime — reference implementation, не semantic authority.

Інші mechanisms можуть бути:

- C;
- Common Lisp;
- Prolog;
- Datalog;
- CLIPS;
- WASM;
- FPGA;
- GraalVM;
- інші substrates.

Backend отримує already-selected semantic object.

Backend opcode, host type, native enum, register number або physical memory layout не створюють SENS meaning.

---

## Physical representation

```text
semantic_width != physical_width
```

Backend може:

- pack several D3 values у physical word;
- розмістити D5 у BRAM geometry;
- widen temporary arithmetic;
- vectorize values;
- map operations to FPGA primitives.

Але semantic identity до і після mechanism boundary має залишатися тією самою.

---

## Structural empty is not another zero

```text
D3 000 structural empty
!= D1 0 PredicateBit NO
!= Number 0
!= any equal numeric payload in another domain
```

Numeric equality не колапсує domains.

---

## Migration rule

Source tree може містити bounded compatibility code від попередньої flat exact-8 архітектури.

Такий код допустимий лише як:

- compatibility;
- transport;
- backend mechanism;
- archived provenance;
- explicit external ABI.

Новий canonical exact-domain code не повинен створювати нову залежність від legacy flat identity.

Для цього існує one-way paradigm guard.

---

## Ratification vs implementation

Status треба читати окремими осями:

```text
domain ratified
law ratified
resident admitted
certificate replayed
runtime implemented
backend implemented
benchmarked
optimized
```

Жоден нижчий status не переписує вищий semantic law.

---

## Project boundary

Поточна semantic authority:

1. `language-contract.lisp`;
2. ratified domain laws;
3. executable conformance/witnesses;
4. reference runtime;
5. backends;
6. generated docs;
7. explanatory docs.

The current canonical source extension is **`.lisp`**. **`.wsm`** and **`.my`** remain supported legacy aliases. File suffixes do not create semantic identity.

Authority precedence: [`semantic-authority-map.md`](semantic-authority-map.md).
