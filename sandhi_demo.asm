; ============================================================================
; sandhi_demo.asm — Step C demo: sandhi rule engine via MOV rs2=7 (SANDHI)
; ============================================================================
; ISA 1.3 sandhi mode: input pair packed in rs1.value[15:8]=prev, [7:0]=curr.
; Output packed in rd.value[17:16]=result_mode, [15:8]=result_1, [7:0]=result_0.
;
;   mode 00 = passthrough (pair unchanged)       out0=prev, out1=curr
;   mode 01 = single code in result_0            (guṇa / savarṇa)
;   mode 10 = two codes: result_0 + result_1     (yaṇ: semivowel + vowel)
;
; Four pairs, one per rule family:
;   1. i+a  ->  y+a        (yaṇ)         mode 10, out0=0x0A, out1=0x80
;   2. a+i  ->  e          (guṇa)        mode 01, out0=0xA8
;   3. aa+a ->  aa         (savarṇa)     mode 01, out0=0x81
;   4. k+a  ->  k+a        (passthrough) mode 00, out0=0x23, out1=0x80
;
; Build (either tool, byte-identical): 
;   python assembler.py sandhi_demo.asm
;   my-lisp assembler.my sandhi_demo.asm sandhi_demo.bin
; ============================================================================

LOADI R1, 0x8880      ; prev=i (0x88), curr=a (0x80)
SANDHI R2, R1         ; -> [y, a]

LOADI R1, 0x8088      ; prev=a, curr=i
SANDHI R3, R1         ; -> [e]

LOADI R1, 0x8180      ; prev=aa, curr=a
SANDHI R4, R1         ; -> [aa]

LOADI R1, 0x2380      ; prev=k (0x23), curr=a
SANDHI R5, R1         ; -> k,a passthrough

HALT