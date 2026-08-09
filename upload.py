import serial
import time
import struct
import argparse
import sys

def compile_asm(asm_lines):
    instructions = []
    # Simplified assembler for testing
    for line in asm_lines:
        if isinstance(line, int):
            instructions.append(line)
            continue
            
        line = line.strip()
        if not line or line.startswith('//'):
            continue
            
        parts = line.split()
import os

def upload_program(port, baudrate, binary_file):
    print(f"Reading binary file: {binary_file}")
    with open(binary_file, 'rb') as f:
        data = f.read()
        
    instructions = [struct.unpack('<I', data[i:i+4])[0] for i in range(0, len(data), 4)]
    
    if len(instructions) > 4095:
        print("Program too long! Max 4095 instructions.")
        return
        
    print("==================================================")
    print(" [!] IMPORTANT: PRESS THE RESET BUTTON NOW! [!]")
    print(" (Press the S1/Reset button on your FPGA board)")
    print("==================================================\n")
    print("Waiting 3 seconds for you to press reset...")
    time.sleep(3)
        
    print(f"Opening port {port} at {baudrate} baud...")
    with serial.Serial(port, baudrate, timeout=1) as ser:
        # Reset the stream (just wait a bit)
        time.sleep(0.1)
        
        # Send length (2 bytes, little-endian; up to 4095 instructions)
        length = len(instructions)
        print(f"Uploading {length} instructions...")
        ser.write(struct.pack('<H', length))
        
        # Send instructions (little-endian)
        for i, instr in enumerate(instructions):
            instr_data = struct.pack('<I', instr)
            ser.write(instr_data)
            print(f"Inst {i}: 0x{instr:08X} -> {list(instr_data)}")
            
        print("Upload complete!")
        print("--- Entering Serial Terminal Mode ---")
        print("Press Ctrl+C to exit.")
        
        # Simple terminal
        import threading
        
        def read_from_port():
            while True:
                try:
                    if ser.in_waiting > 0:
                        data = ser.read(ser.in_waiting)
                        sys.stdout.buffer.write(data)
                        sys.stdout.buffer.flush()
                    else:
                        time.sleep(0.01)
                except Exception as e:
                    print(f"\nRead error: {e}")
                    break

        thread = threading.Thread(target=read_from_port, daemon=True)
        thread.start()
        
        try:
            import msvcrt
            is_windows = True
        except ImportError:
            is_windows = False

        try:
            while True:
                if is_windows:
                    if msvcrt.kbhit():
                        user_input = msvcrt.getch()
                        # Allow Ctrl+C to break
                        if user_input == b'\x03':
                            raise KeyboardInterrupt
                        
                        # Echo typed characters to the screen
                        sys.stdout.buffer.write(user_input)
                        if user_input == b'\r':
                            sys.stdout.buffer.write(b'\n')
                        sys.stdout.buffer.flush()
                        
                        ser.write(user_input)
                    else:
                        time.sleep(0.01)
                else:
                    import select
                    dr, dw, de = select.select([sys.stdin], [], [], 0.01)
                    if dr:
                        user_input = sys.stdin.buffer.read(1)
                        if user_input:
                            ser.write(user_input)
        except KeyboardInterrupt:
            print("\nExiting.")
            
        ser.close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Lisp FPGA UART Bootloader")
    parser.add_argument('port', help="COM port (e.g. COM6)")
    parser.add_argument('file', help="Input .asm or .bin file")
    parser.add_argument('--baud', type=int, default=115200, help="Baud rate (default 115200)")
    
    args = parser.parse_args()
    
    input_file = args.file
    
    # Auto-assemble if .asm
    if input_file.endswith('.asm'):
        print(f"Assembling {input_file}...")
        bin_file = input_file.replace('.asm', '.bin')
        res = os.system(f"python assembler.py {input_file} -o {bin_file}")
        if res != 0:
            print("Assembly failed.")
            sys.exit(1)
        input_file = bin_file
        
    upload_program(args.port, args.baud, input_file)
