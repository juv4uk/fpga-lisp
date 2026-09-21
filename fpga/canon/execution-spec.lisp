; Local FPGA execution spec for Canon-bridged primitives.
;
; This file is fpga-lisp's authority over HOW an upstream Canon SID is
; executed on this machine. It never defines WHAT that SID means.
;
; Canon identity comes from my-lisp's lib/surface/semantic-registry.lisp
; as an exact eight-bit spelling. The leading reader descriptor keeps this
; file readable by pre-#1098 my-lisp readers too; it does not turn SID into
; a number.
(binary 8)

; Format:
;   (canon-sid expected-surface local-primitive-const local-primitive-id opcode)
;
; canon-sid
;   Exact upstream language identity. It is the eight bits themselves,
;   not a decimal function number.
;
; expected-surface
;   Cross-check hint only. The current upstream registry must expose this
;   spelling for the same SID in at least one presentation namespace.
;   Surface spelling is never identity.
;
; local-primitive-const / local-primitive-id
;   fpga-lisp's local hardware execution ABI from fpga/asm/constants.inc.
;   These values answer HOW the FPGA executes the SID and are deliberately
;   separate from the Canon identity.
;
; opcode
;   Informational hardware mechanism name. It is not the Canon identity.
;
; Important namespace separation:
;   - Canon function SID: exactly 8 bits.
;   - PRIM_* local primitive IDs: FPGA-local mechanism IDs.
;   - LOADSYM program-local symbol IDs (currently allocated from 900):
;     separate namespace, may require 10+ bits.
;   - UPC8 value[9:0] transform result: data, not SID.
;
; The old row "(104 add ...)" was not merely a decimal rendering problem:
; in current my-lisp Canon, add/+ is 00001100, while 01101000 names a
; different identity (elapsed-ns). Exact-bit identity makes that drift
; visible and fail-closed instead of silently preserving a stale number.

(fpga-primitive-execution-spec
  (00000101 car  PRIM_CAR  0 OP_CAR)
  (00000110 cdr  PRIM_CDR  1 OP_CDR)
  (00000100 cons PRIM_CONS 2 OP_CONS)
  (00000010 atom PRIM_ATOM 3 OP_ATOM)
  (00000011 eq   PRIM_EQ   4 OP_EQ)
  (00001100 +    PRIM_ADD  5 OP_ADD)
)
