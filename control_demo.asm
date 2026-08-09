; M07 CONTROL: countdown loop exercising JF (falsy branch) and JMP
; (forward skip + backward loop), plus SUB/ADD/EQ.
; R1 counts down from 3 to 0, R2 counts up; expect R1=0, R2=3 at HALT.
LOADI R1, 3
LOADI R2, 0
LOADI R3, 1
LOADI R0, 0
loop:
EQ R4, R1, R0
JF R4, body
JMP done
body:
SUB R1, R1, R3
ADD R2, R2, R3
JMP loop
done:
HALT
