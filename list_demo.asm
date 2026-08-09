; M06 LIST: build (radio antenna signal) as a CONS chain, walk it back.
LOADSYM R1, 2    ; 'radio
LOADSYM R2, 3    ; 'antenna
LOADSYM R3, 4    ; 'signal
LOADSYM R5, 9    ; dummy A
LOADSYM R6, 10   ; dummy B (different, for EQ -> NIL trick)
EQ R7, R5, R6    ; R7 = NIL (false comparison)
CONS R8, R3, R7  ; cell2 = (signal . NIL)
CONS R9, R2, R8  ; cell1 = (antenna . cell2)
CONS R10, R1, R9 ; cell0 = (radio . cell1)  <- list head
CAR R11, R10     ; R11 = radio
CDR R12, R10     ; R12 = cell1
CAR R13, R12     ; R13 = antenna
CDR R14, R12     ; R14 = cell2
CAR R15, R14     ; R15 = signal
CDR R0, R14      ; R0 = NIL (end of list)
HALT
