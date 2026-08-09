; M09 CALL/RET: subroutine doubles R2 via ADD, then returns to the
; instruction right after CALL. R1 holds the return address (link reg).
LOADI R2, 5
CALL R1, func
HALT
func:
ADD R2, R2, R2
RET R1
