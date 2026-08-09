import sys
import time
import struct
import argparse

import serial

TAG_NAMES = {
    0: "FIXNUM",
    1: "CONS",
    2: "SYMBOL",
    3: "NIL",
    4: "TRUE",
}


def fmt_word(word):
    tag = (word >> 28) & 0xF
    value = word & 0x0FFFFFFF
    tag_name = TAG_NAMES.get(tag, f"TAG{tag}")
    return f"{tag_name}({value})  [0x{word:08X}]"


def upload_program(ser, binary_file):
    with open(binary_file, "rb") as f:
        data = f.read()
    instructions = [struct.unpack("<I", data[i:i + 4])[0] for i in range(0, len(data), 4)]
    if len(instructions) > 4095:
        print("Program too long! Max 4095 instructions.")
        sys.exit(1)

    print("==================================================")
    print(" [!] PRESS THE RESET BUTTON ON THE BOARD NOW! [!]")
    print("==================================================")
    time.sleep(3)

    ser.reset_input_buffer()
    length = len(instructions)
    print(f"Uploading {length} instructions from {binary_file}...")
    ser.write(struct.pack("<H", length))  # 2 bytes, little-endian
    for instr in instructions:
        ser.write(struct.pack("<I", instr))
    print("Upload complete. Waiting for HALT (press Enter once the board should be halted)...")


def read_exact(ser, n):
    buf = b""
    while len(buf) < n:
        chunk = ser.read(n - len(buf))
        if not chunk:
            raise TimeoutError(f"Expected {n} bytes, got {len(buf)}")
        buf += chunk
    return buf


def cmd_reg(ser, idx):
    ser.write(bytes([0x01, idx]))
    word = struct.unpack("<I", read_exact(ser, 4))[0]
    print(f"R{idx} = {fmt_word(word)}")


def cmd_hp(ser):
    ser.write(bytes([0x03]))
    hp = struct.unpack("<I", read_exact(ser, 4))[0]
    print(f"HP = {hp}")


def cmd_heap(ser, addr):
    ser.write(bytes([0x02, addr & 0xFF, (addr >> 8) & 0xFF]))
    car, cdr = struct.unpack("<II", read_exact(ser, 8))
    print(f"HEAP[{addr}] = ({fmt_word(car)} . {fmt_word(cdr)})")


def cmd_err(ser):
    ser.write(bytes([0x04]))
    word = struct.unpack("<I", read_exact(ser, 4))[0]
    err_flag = (word >> 12) & 1
    err_pc = word & 0xFFF
    if err_flag:
        print(f"ERR: type error at pc={err_pc} (CAR/CDR/CONS on a non-CONS)")
    else:
        print("ERR: no error (halted normally via HALT)")


def repl(ser):
    print("Monitor ready. Commands: reg <n> | heap <addr> | hp | err | quit")
    while True:
        try:
            line = input("> ").strip()
        except EOFError:
            break
        if not line:
            continue
        parts = line.split()
        cmd = parts[0].lower()
        try:
            if cmd == "reg" and len(parts) == 2:
                cmd_reg(ser, int(parts[1]))
            elif cmd == "heap" and len(parts) == 2:
                cmd_heap(ser, int(parts[1]))
            elif cmd == "hp":
                cmd_hp(ser)
            elif cmd == "err":
                cmd_err(ser)
            elif cmd in ("quit", "exit"):
                break
            else:
                print("Unknown command. Use: reg <n> | heap <addr> | hp | err | quit")
        except TimeoutError as e:
            print(f"No reply from board: {e}")


def main():
    parser = argparse.ArgumentParser(description="Lisp FPGA post-HALT debug monitor")
    parser.add_argument("port", help="COM port (e.g. COM3)")
    parser.add_argument("file", nargs="?", help="Optional .bin to upload before entering the monitor")
    parser.add_argument("--baud", type=int, default=115200)
    args = parser.parse_args()

    with serial.Serial(args.port, args.baud, timeout=2) as ser:
        if args.file:
            upload_program(ser, args.file)
            # pyserial's reset_input_buffer() can be a no-op if the OS
            # driver hasn't caught up yet (pyserial#344); sleep briefly
            # so any bytes in flight land, then actually discard them,
            # so a stale byte from upload/reset doesn't throw off every
            # subsequent 4-byte reply by a fixed offset.
            time.sleep(0.2)
            ser.reset_input_buffer()
            input("Press Enter once the board has halted... ")
        repl(ser)


if __name__ == "__main__":
    main()
