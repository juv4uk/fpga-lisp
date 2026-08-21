"""Assembler definitions for FPGA Lisp Phonetic Vector ALU Instructions."""

# New Phonetic Vector ALU Extended Opcodes
PHONETIC_OPCODES = {
    'SAVARNA':       0x1,  # SAVARNA rd, rs1, rs2 -> rd = 1 if homogeneous else 0
    'VOICE':         0x2,  # VOICE rd, rs1        -> rd = rs1 | GHOSHA
    'DEVOICE':       0x3,  # DEVOICE rd, rs1      -> rd = rs1 & ~GHOSHA
    'PALATALIZE':    0x4,  # PALATALIZE rd, rs1   -> rd = rs1 | PALATAL_MOD
    'DEPALATALIZE':  0x5,  # DEPALATALIZE rd, rs1 -> rd = rs1 & ~PALATAL_MOD
    'PRATTEST':      0x6,  # PRATTEST rd, rs1, rs2 -> rd = (mask_rs2 >> code_rs1) & 1
    'PRATROM':       0x7,  # PRATROM rd, rs1, id  -> rd = (ROM[id] >> code_rs1) & 1
    'SANDHIVOICE':   0x8,  # SANDHIVOICE rd, rs1  -> rd = Sandhi voiced form
    'STHANAEQ':      0xE,  # STHANAEQ rd, rs1, rs2 -> rd = 1 if same sthana
    'PRAYATNAEQ':    0xF,  # PRAYATNAEQ rd, rs1, rs2 -> rd = 1 if same prayatna
}

# Macro Expansion for Assembler
def encode_phonetic_instruction(op_name: str, rd: int, rs1: int, rs2: int = 0, imm: int = 0) -> int:
    """Encode 32-bit FPGA Lisp instruction with Phonetic ALU extension sub-modes."""
    sub_op = PHONETIC_OPCODES[op_name.upper()]
    # Tagged coprocessor instruction format: [31:28]=OP_PHONETIC_ALU, [27:24]=rd, [23:20]=rs1, [19:16]=rs2, [15:12]=sub_op, [11:0]=imm
    instr = (0x2 << 28) | (rd << 24) | (rs1 << 20) | (rs2 << 16) | (sub_op << 12) | (imm & 0xFFF)
    return instr
