;; ============================================================================
;; PATCH: ISA 1.1 -> 1.2 (UPC-8 phonetic primitives)
;; ============================================================================
;; Add to isa-contract.my after the existing encoded-modes block.
;; Version bump: (version . (1 2))
;; ============================================================================

;; In the (version . (1 1)) line, change to:
 (version . (1 2))

;; In the (encoded-modes . ...) block, add after SETCDR:
    (upc8-decode    . ((opcode . mov) (rs2 . 4) (scope . phonetic)))
    (upc8-transform . ((opcode . mov) (rs2 . 5) (scope . phonetic)))
    (upc8-predicate . ((opcode . mov) (rs2 . 6) (scope . phonetic)))

;; Add to (notes . "..."):
;; "2026-09-06: ISA 1.2 adds UPC-8 phonetic primitives (decode/transform/predicate)
;;  via encoded MOV modes rs2=4/5/6. UPC8_TRANSFORM packs op[2:0] into value[10:8]
;;  and code[7:0] into value[7:0] of the source FIXNUM. All three ops are
;;  combinational (0 wait states). Backward-compatible with ISA 1.1 images."
