; G4 evidence (evidence/ISA-RATIONAL/): does hardware ADD silently wrap
; a TAG_FIXNUM's 28-bit payload, or does it signal overflow some other
; way? Builds 2^27 by doubling 1 twenty-seven times, then adds it to
; itself once more: 2^27 + 2^27 = 2^28, which is exactly one past the
; 28-bit field's maximum representable value (2^28 - 1). If ADD
; silently wraps mod 2^28, R2 ends up 0. If it saturates or sets an
; error flag some other way, R2 will not be 0 and/or `error` will
; assert (observed by the testbench directly on the RTL signal, not
; inferred from R2 alone).

LOADI R1, 1      ; R1 = 2^0
ADD R1, R1, R1   ; 2^1
ADD R1, R1, R1   ; 2^2
ADD R1, R1, R1   ; 2^3
ADD R1, R1, R1   ; 2^4
ADD R1, R1, R1   ; 2^5
ADD R1, R1, R1   ; 2^6
ADD R1, R1, R1   ; 2^7
ADD R1, R1, R1   ; 2^8
ADD R1, R1, R1   ; 2^9
ADD R1, R1, R1   ; 2^10
ADD R1, R1, R1   ; 2^11
ADD R1, R1, R1   ; 2^12
ADD R1, R1, R1   ; 2^13
ADD R1, R1, R1   ; 2^14
ADD R1, R1, R1   ; 2^15
ADD R1, R1, R1   ; 2^16
ADD R1, R1, R1   ; 2^17
ADD R1, R1, R1   ; 2^18
ADD R1, R1, R1   ; 2^19
ADD R1, R1, R1   ; 2^20
ADD R1, R1, R1   ; 2^21
ADD R1, R1, R1   ; 2^22
ADD R1, R1, R1   ; 2^23
ADD R1, R1, R1   ; 2^24
ADD R1, R1, R1   ; 2^25
ADD R1, R1, R1   ; 2^26
ADD R1, R1, R1   ; 2^27  (R1 = 134217728, still fits in 28 bits: max is 268435455)
ADD R2, R1, R1   ; 2^27 + 2^27 = 2^28 = 268435456 -- one past the 28-bit max
HALT
