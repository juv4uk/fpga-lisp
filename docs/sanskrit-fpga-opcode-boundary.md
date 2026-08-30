# Sanskrit/Pāṇinian layer ↔ fpga-lisp ISA boundary (SANSKRIT-P9)

Answers one question: does the Sanskrit/Pāṇinian semantic layer (dhātu
roots, kāraka roles, SLP1 canonical forms — see the full migration
specification, my-lisp/cml side) require any change to fpga-lisp's ISA?
**No**, and this document is the contract that fixes that, per the
spec's own architectural principle (its section 14/15): Semantic ISA
and Machine ISA are different layers and must not be mixed.

## The boundary, concretely

```
Sanskrit/Pāṇinian layer   (dhātu, kāraka, SLP1)         -- my-lisp/cml
        ↓
   Semantic AST            (SemanticCall { predicate, roles })
        ↓
   Semantic IR              lowering pass                -- my-lisp/cml
        ↓
   existing low-level IR    (whatever cml already emits)  -- cml
        ↓
   fpga-lisp ISA 1.0        opcodes, TAG_PRIMITIVE ids     -- fpga-lisp (this repo)
        ↓
       RTL
```

fpga-lisp sits at the bottom of this stack and never sees SLP1, IAST,
Devanāgarī, or any Sanskrit-specific representation — the same way it
never saw `length`, `reverse`, or `equal?` as English words either.
Every dhātu-based operation that reaches hardware does so exactly like
every `core.my` function already does: as a closure built from `CONS`/
`CAR`/`CDR`/`ATOM`/`EQ`/`ADD` (or a future primitive, added the normal
way — see below), assembled and run through the existing bootloader.
`(dA :kartf server :karman packet :sampradAna client)` compiles down to
*some* IR that fpga-lisp executes; fpga-lisp's own contract has no
opinion about, and no dependency on, what the source syntax looked like
above the IR boundary.

## Opcode space vs primitive-id space — the distinction that resolves this

fpga-lisp's ISA has two separate extension points, with very different
scarcity:

- **Opcode space** (`isa-contract.my`'s `opcodes` alist): 4-bit field,
  **16/16 slots already allocated**. Every extension since `LOADSYM`
  filled it (`CALL`/`RET`, `GETTAG`/`MAKEPRIM`/`GETVAL`, `SETCDR`) has
  reused an existing opcode's unused instruction field rather than
  spending a new slot. This is genuinely scarce.
- **Primitive-id space** (`isa-contract.my`'s `primitive-ids` alist,
  the 28-bit payload of a `TAG_PRIMITIVE` value): **6 ids used out of
  up to 2^28 possible** (`car=0 cdr=1 cons=2 atom=3 eq=4 add=5`). Adding
  a new hardware-backed primitive (if a dhātu ever needs one that isn't
  expressible as composition of existing primitives — no evidence yet
  that any of the P1-P8 experimental core does) means adding one entry
  to this alist and one dispatch case in `eval_core.inc`'s
  `try_apply`, the same pattern M27 (`PRIM_ADD`) already used. It does
  **not** touch the opcode field at all.

Everything in the migration spec (dhātu roots composed via kāraka
roles, lowered through a semantic IR) describes exactly the shape that
already fits fpga-lisp's existing model — `core.my`'s own functions are
"meaning composed from a handful of hardware-backed primitives," which
is structurally the same thing a lowered dhātu predicate would be.

## What would actually require fpga-lisp RTL work

Only if a specific dhātu's operational semantics needs a genuinely new
*hardware* capability — not just a new *name* — would this repo be
involved at all, and even then the cost is a primitive-id addition
(cheap), not an opcode addition (expensive), unless the operation is
fundamentally impossible to express via `eval`-level dispatch (unlikely
for anything expressible as a Lisp closure, per the M16-M32 track
record). No such case has been identified in the P1-P8 experimental
core as of this writing.

## Conclusion

**No opcode changes needed for SANSKRIT-P1 through P8** as scoped in
the migration spec. This repo's involvement is passive: fpga-lisp's
ISA stays exactly as ISA 1.0 defines it, semantic layer changes are
invisible below the IR boundary, and the only future dependency would
be a primitive-id addition, following the M27 precedent, only if a
concrete need is identified — not preemptively.

---

# Санскритський/Панінівський рівень ↔ межа ISA fpga-lisp (SANSKRIT-P9) (Ukrainian)

Дає відповідь на одне запитання: чи вимагає санскритський/панінівський 
семантичний рівень (корені-дхату, ролі-карака, канонічні форми SLP1 — див. 
повну специфікацію міграції на стороні `my-lisp`/`cml`) будь-яких змін в ISA 
fpga-lisp? **Ні**, і цей документ є контрактом, який фіксує це, згідно з 
архітектурним принципом самої специфікації: семантична ISA та машинна ISA — 
це різні рівні, і їх не можна змішувати.

## Межа (конкретно)

```
Санскрит/Паніні (dhātu, kāraka, SLP1)         -- my-lisp/cml
        ↓
   Семантичний AST (SemanticCall { ... })
        ↓
   Семантичний IR (lowering)                  -- my-lisp/cml
        ↓
   Існуючий низькорівневий IR                 -- cml
        ↓
   fpga-lisp ISA 1.0 (opcodes, TAG_PRIMITIVE) -- fpga-lisp (цей репозиторій)
        ↓
       RTL
```

`fpga-lisp` знаходиться на дні цього стеку і ніколи не бачить SLP1, IAST, 
Деванагарі чи будь-яке специфічне для санскриту представлення — так само, 
як він ніколи не бачив англійських слів `length`, `reverse` або `equal?`. 
Уся робота на базі дхату доходить до апаратного забезпечення точно так само, 
як і функції `core.my`: у вигляді замикань, складених із базових примітивів 
(`CONS`, `CAR`, `ADD` тощо). Контракт `fpga-lisp` не залежить від того, як 
виглядав синтаксис над межею IR.

## Простір опкодів проти простору ідентифікаторів примітивів

ISA `fpga-lisp` має дві точки розширення, з різним рівнем дефіциту:
- **Простір опкодів (Opcode space):** 4-бітне поле, **вже зайнято 16/16 
  можливих слотів**. Це справжній дефіцит; нові інструкції перевикористовують 
  поля існуючих опкодів.
- **Простір ідентифікаторів примітивів (Primitive-id space):** 28-бітне 
  навантаження значення `TAG_PRIMITIVE`. **Використано 6 ідентифікаторів із 
  2^28 можливих**. Додавання нового апаратного примітива (якщо він коли-небудь 
  знадобиться для дхату) означатиме лише додавання одного запису до словника 
  і одного випадку диспетчеризації (`try_apply`), як це було зроблено для 
  `PRIM_ADD`. Це **не чіпає** поле опкодів взагалі.

Структурно "значення, складене з жменьки апаратних примітивів" (як зараз 
працює `core.my`) — це те саме, чим буде понижений предикат дхату.

## Що насправді вимагало б роботи в RTL fpga-lisp

Тільки якщо операційна семантика конкретного дхату вимагатиме принципово 
нової *апаратної* можливості — а не просто нового *імені* — цей репозиторій 
буде залучений, і навіть тоді вартістю буде ідентифікатор примітива (дешево), 
а не опкод (дорого). Таких випадків у експериментальному ядрі P1-P8 поки не 
виявлено.

## Висновок

**Жодних змін опкодів для SANSKRIT-P1 - P8 не потрібно.** Роль цього 
репозиторію є пасивною: ISA `fpga-lisp` залишається точно такою, як визначено 
в ISA 1.0, семантичний рівень невидимий нижче межі IR, і єдина можлива зміна 
в майбутньому — це додавання ідентифікатора примітива (primitive-id), лише 
якщо буде виявлена конкретна потреба, а не наперед.
