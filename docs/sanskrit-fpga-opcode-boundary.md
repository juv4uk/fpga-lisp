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
