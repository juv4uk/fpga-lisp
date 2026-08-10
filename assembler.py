import sys
import argparse
import struct
import re
import os

OPCODES = {
    'NOP':    0,
    'LOADI':  1,
    'MOV':    2,
    'GETTAG': 2,  # MOV with rs2 == 1: rd = FIXNUM(tag of rs1)
    'MAKEPRIM': 2,  # MOV with rs2 == 2: rd = PRIMITIVE(value of rs1)
    'GETVAL': 2,  # MOV with rs2 == 3: rd = FIXNUM(value of rs1)
    'CONS':   3,
    'CAR':    4,
    'CDR':    5,
    'ATOM':   6,
    'EQ':     7,
    'JMP':    8,
    'CALL':   8,  # JMP with rd != 0: reg[rd] = return addr, then jump
    'RET':    8,  # JMP with rs1 != 0: jump to address held in rs1
    'LOADSYM': 9,
    'JF':     10,
    'HALT':   11,
    'OUT':    12,
    'ADD':    13,
    'SUB':    14,
    'IN':     15
}

def expand_includes(lines, base_dir, seen=None):
    """Recursively inline `.include "path"` directives (relative to the
    including file's own directory), so shared fragments -- symbol
    constants, the eval/lookup subroutine body -- don't have to be
    hand-copied into every .asm file."""
    if seen is None:
        seen = set()
    out = []
    for line in lines:
        stripped = line.split(';')[0].split('#')[0].strip()
        m = re.match(r'\.include\s+"([^"]+)"', stripped)
        if m:
            inc_path = os.path.normpath(os.path.join(base_dir, m.group(1)))
            if inc_path in seen:
                print(f"Error: circular .include of '{inc_path}'")
                sys.exit(1)
            seen.add(inc_path)
            with open(inc_path, 'r') as f:
                inc_lines = f.readlines()
            out.extend(expand_includes(inc_lines, os.path.dirname(inc_path), seen))
        else:
            out.append(line)
    return out


def parse_reg(reg_str):
    if not reg_str.startswith('R'):
        raise ValueError(f"Expected register (e.g., R1), got {reg_str}")
    return int(reg_str[1:])

def parse_imm(imm_str, labels):
    if imm_str in labels:
        return labels[imm_str]
    # Handle hex, bin, and dec
    if imm_str.startswith('0x'):
        return int(imm_str, 16)
    elif imm_str.startswith('0b'):
        return int(imm_str, 2)
    else:
        return int(imm_str)

def assemble(lines):
    labels = {}
    instructions_pass1 = []
    
    # First pass: strip comments, find labels, record instruction strings
    pc = 0
    for line_num, line in enumerate(lines):
        # Strip comments
        if ';' in line:
            line = line.split(';')[0]
        # Also support '#' comments for convenience
        if '#' in line:
            line = line.split('#')[0]
            
        line = line.strip()
        if not line:
            continue

        # .define NAME VALUE -- a named constant (e.g. a symbol id or
        # primitive id), usable anywhere a label is (LOADSYM/LOADI/JMP
        # immediates). Unlike a label, it isn't tied to a PC address
        # and doesn't consume an instruction slot.
        m = re.match(r'\.define\s+(\S+)\s+(\S+)', line)
        if m:
            name, value_str = m.group(1), m.group(2)
            if value_str.startswith('0x'):
                labels[name] = int(value_str, 16)
            elif value_str.startswith('0b'):
                labels[name] = int(value_str, 2)
            else:
                labels[name] = int(value_str)
            continue

        # Check for label
        if line.endswith(':'):
            label = line[:-1].strip()
            labels[label] = pc
            continue
            
        # If line has a label and an instruction on the same line (e.g. "loop: OUT R1")
        if ':' in line:
            parts = line.split(':', 1)
            label = parts[0].strip()
            labels[label] = pc
            line = parts[1].strip()
            if not line:
                continue
                
        instructions_pass1.append((line_num + 1, line))
        pc += 1

    # Second pass: assemble instructions
    machine_code = []
    for line_num, line in instructions_pass1:
        # replace commas with spaces to unify parsing
        line_clean = line.replace(',', ' ')
        parts = [p for p in line_clean.split() if p]
        
        op = parts[0].upper()
        if op not in OPCODES:
            print(f"Error (line {line_num}): Unknown opcode '{op}'")
            sys.exit(1)
            
        opcode_val = OPCODES[op]
        instr_word = opcode_val << 28
        
        try:
            if op in ['NOP', 'HALT']:
                pass
                
            elif op in ['LOADI', 'LOADSYM']:
                rd = parse_reg(parts[1])
                imm = parse_imm(parts[2], labels)
                instr_word |= (rd << 24) | (imm & 0xFFFF)
                
            elif op in ['MOV', 'CAR', 'CDR']:
                rd = parse_reg(parts[1])
                rs1 = parse_reg(parts[2])
                instr_word |= (rd << 24) | (rs1 << 20)

            elif op in ['GETTAG', 'MAKEPRIM', 'GETVAL']:
                # Same opcode as MOV; rs2 selects the mode (see OPCODES).
                mode = {'GETTAG': 1, 'MAKEPRIM': 2, 'GETVAL': 3}[op]
                rd = parse_reg(parts[1])
                rs1 = parse_reg(parts[2])
                instr_word |= (rd << 24) | (rs1 << 20) | (mode << 16)


            elif op in ['CONS', 'ADD', 'SUB', 'EQ', 'ATOM']:
                # Note: ATOM historically took 2 ops in some designs, but if it takes 1, we handle it
                rd = parse_reg(parts[1])
                rs1 = parse_reg(parts[2])
                rs2 = parse_reg(parts[3]) if len(parts) > 3 else 0
                instr_word |= (rd << 24) | (rs1 << 20) | (rs2 << 16)
                
            elif op in ['OUT', 'IN']:
                # Format varies slightly: IN R1, OUT R1
                if op == 'IN':
                    rd = parse_reg(parts[1])
                    instr_word |= (rd << 24)
                else: # OUT R1 uses rs1
                    rs1 = parse_reg(parts[1])
                    instr_word |= (rs1 << 20)
                    
            elif op in ['JMP']:
                imm = parse_imm(parts[1], labels)
                instr_word |= (imm & 0xFFFF)

            elif op in ['CALL']:
                rd = parse_reg(parts[1])
                imm = parse_imm(parts[2], labels)
                instr_word |= (rd << 24) | (imm & 0xFFFF)

            elif op in ['RET']:
                rs1 = parse_reg(parts[1])
                instr_word |= (rs1 << 20)

            elif op in ['JF']:
                rs1 = parse_reg(parts[1])
                imm = parse_imm(parts[2], labels)
                instr_word |= (rs1 << 20) | (imm & 0xFFFF)
                
            else:
                print(f"Error (line {line_num}): Unhandled format for opcode '{op}'")
                sys.exit(1)
                
        except Exception as e:
            print(f"Error (line {line_num}): Failed to parse '{line}': {e}")
            sys.exit(1)
            
        machine_code.append(instr_word)
        
    return machine_code

def main():
    parser = argparse.ArgumentParser(description="Lisp FPGA Assembler")
    parser.add_argument('input', help="Input .asm file")
    parser.add_argument('-o', '--output', help="Output .bin file")
    args = parser.parse_args()
    
    with open(args.input, 'r') as f:
        lines = f.readlines()

    lines = expand_includes(lines, os.path.dirname(os.path.abspath(args.input)))

    machine_code = assemble(lines)
    
    out_file = args.output
    if not out_file:
        out_file = args.input.replace('.asm', '.bin')
        if out_file == args.input:
            out_file += '.bin'
            
    print(f"Assembled {len(machine_code)} instructions.")
    
    with open(out_file, 'wb') as f:
        for instr in machine_code:
            f.write(struct.pack('<I', instr))
            
    print(f"Wrote binary to {out_file}")

if __name__ == '__main__':
    main()
