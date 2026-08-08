; test_memory.asm
; Tests the CONS, CAR, and CDR instructions.

start:
    ; Load 'A' (65) into R1
    LOADI R1, 65
    ; Load 'B' (66) into R2
    LOADI R2, 66
    
    ; Output 'A' to make sure R1 is correct
    OUT R1
    
    ; Output 'B' to make sure R2 is correct
    OUT R2
    
    ; Now, CONS R1 and R2, put the result (pointer) into R3
    ; R3 will now hold a pointer to a pair ('A' . 'B')
    CONS R3, R1, R2
    
    ; We can't directly print R3 since it's a pointer, but we can 
    ; extract the values back out.
    
    ; Extract the CAR of R3 into R4 (should be 'A')
    CAR R4, R3
    
    ; Extract the CDR of R3 into R5 (should be 'B')
    CDR R5, R3
    
    ; Print the extracted CAR ('A')
    OUT R4
    
    ; Print the extracted CDR ('B')
    OUT R5
    
    ; Print a newline (10)
    LOADI R6, 10
    OUT R6
    
    ; Print carriage return (13)
    LOADI R6, 13
    OUT R6
    
    ; Wait for an input before looping so it doesn't spam
    IN R7
    
    ; Loop back
    JMP start
