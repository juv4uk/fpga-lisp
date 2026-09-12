; Local FPGA execution spec for Canon-bridged primitives.
;
; This file is fpga-lisp's own authority over HOW a Canon semantic
; identity (my-lisp's lib/surface/semantic-registry.wsm) is executed
; on this machine -- it does not define WHAT the identity means (that
; stays my-lisp's authority) and it does not change any existing
; opcode, TAG_PRIMITIVE numbering, or PRIM_* value in
; fpga/asm/constants.inc. It is the small, hand-maintained bridge
; fpga/canon/gen-primitive-table.my needs instead of the identity
; being re-typed by hand in eval_core.inc, old test .asm files, or any
; future consumer.
;
; Format: (canon-id expected-en-spelling local-primitive-const local-primitive-id opcode)
;   canon-id                 -- semantic-registry.wsm's numeric id
;   expected-en-spelling     -- sanity cross-check only: if the
;                               registry's "en" surface for this id is
;                               present, it must equal this word, or
;                               generation fails closed. If the
;                               registry's en surface is "missing" for
;                               this id (e.g. 104/add has no en entry
;                               yet), the check is skipped, not failed.
;   local-primitive-const    -- the exact .define name in
;                               fpga/asm/constants.inc (e.g. PRIM_CAR).
;                               Given literally, not derived by case
;                               conversion: my-lisp has no
;                               uppercase/case-folding primitive by
;                               design (see
;                               docs/shared-oracle-parity-2-symbol-identity-gate.md),
;                               and this generator does not need one.
;   local-primitive-id       -- must equal that constant's actual
;                               value in constants.inc (cross-checked
;                               by the generator, not just asserted
;                               here).
;   opcode                   -- the hardware mechanism name,
;                               informational for now (car/cdr/cons/
;                               atom/eq/add are dispatched through
;                               try_apply's primitive path in
;                               eval_core.inc, not literal same-named
;                               top-level opcodes -- "OP_*" here names
;                               the mechanism, not a promise that a
;                               same-named ISA opcode exists).
;
; Adding an entry here does NOT create hardware. It documents which
; already-existing local primitive a Canon identity maps to. Removing
; or renumbering an entry needs the same care as touching constants.inc
; itself -- see that file's own header.

(fpga-primitive-execution-spec
  (5 car PRIM_CAR 0 OP_CAR)
  (6 cdr PRIM_CDR 1 OP_CDR)
  (4 cons PRIM_CONS 2 OP_CONS)
  (2 atom PRIM_ATOM 3 OP_ATOM)
  (3 eq PRIM_EQ 4 OP_EQ)
  (104 add PRIM_ADD 5 OP_ADD)
)
