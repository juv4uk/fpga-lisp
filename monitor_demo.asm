; Demo program for monitor.py: (cons 'a 'b), leave result in R3
LOADSYM R1, 2   ; R1 = SYMBOL #2 ('a)
LOADSYM R2, 3   ; R2 = SYMBOL #3 ('b)
CONS R3, R1, R2 ; R3 = (cons 'a 'b)
HALT
