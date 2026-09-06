import sys, time, struct, serial

PORT = "COM4"
BAUD = 115200
BIN = sys.argv[1]

with open(BIN, "rb") as f:
    data = f.read()
instr = [struct.unpack("<I", data[i:i+4])[0] for i in range(0, len(data), 4)]

def wait_byte(ser, timeout_s):
    ser.timeout = timeout_s
    b = ser.read(1)
    return b

with serial.Serial(PORT, BAUD, timeout=0.2) as ser:
    time.sleep(0.2)
    ser.reset_input_buffer()
    ser.write(struct.pack("<H", len(instr)))
    for w in instr:
        ser.write(struct.pack("<I", w))

    # Poll for HALT: post prog, machine only enters monitor (responds to
    # reg read) once the program halts. Probe reg 0 until we get 4 bytes.
    halted = False
    for _ in range(100):
        ser.flushInput()
        ser.write(bytes([0x01, 0x00]))
        raw = ser.read(4)
        if len(raw) == 4:
            halted = True
            break
    if not halted:
        print("TIMEOUT waiting for HALT")
        sys.exit(2)
    print(f"Machine HALTed after poll {_+1}")

    def rd(n):
        ser.timeout = 0.5
        ser.write(bytes([0x01, n]))
        raw = ser.read(4)
        if len(raw) != 4:
            return None
        return struct.unpack("<I", raw)[0]

    for n in range(10):
        v = rd(n)
        tag = None if v is None else (v >> 28) & 0xF
        val = None if v is None else v & 0x0FFFFFFF
        print(f"R{n} = {('TIMEOUT' if v is None else f'TAG:{tag} VAL:0x{val:07X}')}")

    ser.write(bytes([0x04]))
    raw = ser.read(4)
    if len(raw) == 4:
        w = struct.unpack("<I", raw)[0]
        errf = (w >> 12) & 1
        errpc = w & 0xFFF
        print(f"ERR = 0x{w:08X} flag={errf} pc={errpc}")
    else:
        print("ERR = TIMEOUT")