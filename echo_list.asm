# echo_list.asm
# 1. Reads characters from UART until '\n' or '\r' is encountered.
# 2. Builds a linked list (which ends up reversed since we prepend).
# 3. Reverses the linked list to restore original order.
# 4. Traverses the reversed list and prints the characters.

LOADI R1, 0         # R1 = head of input list (initially 0/NIL)
LOADI R10, 10       # '\n'
LOADI R13, 13       # '\r'

read_loop:
IN R2               # Read char into R2

# If char == 0 (no data), loop and wait
LOADI R3, 0
EQ R4, R2, R3
JF R4, check_newline
JMP read_loop

check_newline:
# Check if '\n'
EQ R4, R2, R10
JF R4, check_cr
JMP reverse_list

check_cr:
# Check if '\r'
EQ R4, R2, R13
JF R4, do_cons
JMP reverse_list

do_cons:
# CONS character onto list: R1 = CONS(R2, R1)
CONS R1, R2, R1

# Loop back to read
JMP read_loop

reverse_list:
LOADI R2, 0         # R2 = head of reversed list

reverse_loop:
# Check if R1 == 0 (end of input list)
LOADI R3, 0
EQ R4, R1, R3
JF R4, do_reverse
JMP print_list

do_reverse:
# R5 = CAR(R1) (the character)
CAR R5, R1
# R1 = CDR(R1) (next node)
CDR R1, R1
# R2 = CONS(R5, R2) (prepend to reversed list)
CONS R2, R5, R2

JMP reverse_loop

print_list:
# Check if R2 == 0 (end of reversed list)
LOADI R3, 0
EQ R4, R2, R3
JF R4, do_print
JMP halt_prog

do_print:
# R5 = CAR(R2)
CAR R5, R2
# Output the character
OUT R5

# R2 = CDR(R2)
CDR R2, R2

JMP print_list

halt_prog:
# Print newline at the end
OUT R10
HALT
