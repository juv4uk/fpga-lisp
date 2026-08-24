#!/usr/bin/env python3
"""Binary CML job bridge for the physical fpga-lisp UART monitor.

The process reads one versioned job from stdin and writes one fixed-size
response to stdout. Human-facing reset instructions and failures go to stderr
so stdout remains a machine-only channel.
"""

import argparse
import struct
import sys
import time

import serial


REQUEST_MAGIC = b"CMLJ"
RESPONSE_MAGIC = b"CMLR"
PROTOCOL_VERSION = 1
MAX_PROGRAM_WORDS = 4095
MONITOR_REG = 0x01
MONITOR_ERROR = 0x04


def read_exact(port, size):
    data = bytearray()
    while len(data) < size:
        chunk = port.read(size - len(data))
        if not chunk:
            raise TimeoutError(f"expected {size} bytes, got {len(data)}")
        data.extend(chunk)
    return bytes(data)


def parse_request(data):
    if len(data) < 10:
        raise ValueError("request is shorter than the bridge header and word count")
    if data[:4] != REQUEST_MAGIC:
        raise ValueError("request magic mismatch")
    version, result_register, reserved, raw_header = struct.unpack("<HBBH", data[4:10])
    if version != PROTOCOL_VERSION:
        raise ValueError(f"unsupported protocol version {version}")
    if reserved != 0:
        raise ValueError("reserved request byte must be zero")
    if result_register > 15:
        raise ValueError(f"invalid result register {result_register}")
    if raw_header & 0x7000:
        raise ValueError("boot header reserved bits 12..14 must be zero")
    extended = bool(raw_header & 0x8000)
    word_count = raw_header & 0x0FFF
    if not 1 <= word_count <= MAX_PROGRAM_WORDS:
        raise ValueError(f"invalid program length {word_count}")
    if extended:
        if len(data) < 11:
            raise ValueError("extended request is missing register input count")
        input_count = data[10]
        if not 1 <= input_count <= 16:
            raise ValueError(f"invalid register input count {input_count}")
        registers = [data[11 + index * 5] for index in range(input_count)]
        if any(register > 15 for register in registers):
            raise ValueError("register input address exceeds R15")
        if len(set(registers)) != len(registers):
            raise ValueError("duplicate register input")
        expected = 11 + input_count * 5 + word_count * 4
    else:
        expected = 10 + word_count * 4
    if len(data) != expected:
        raise ValueError(f"request has {len(data)} bytes, expected {expected}")
    return result_register, data[8:]


def execute(port_name, baud, timeout, reset_wait, halt_wait, request):
    result_register, bootloader_frame = parse_request(request)
    print(
        f"CML FPGA job ready for {port_name}; press the board RESET button now",
        file=sys.stderr,
        flush=True,
    )
    time.sleep(reset_wait)

    with serial.Serial(port_name, baud, timeout=timeout, write_timeout=timeout) as port:
        port.reset_input_buffer()
        port.write(bootloader_frame)
        port.flush()
        time.sleep(halt_wait)

        # Let any bytes already in the Windows driver arrive before discarding
        # them; this preserves monitor.py's proven pyserial#344 workaround.
        time.sleep(0.2)
        port.reset_input_buffer()

        port.write(bytes([MONITOR_REG, result_register]))
        port.flush()
        result_word = struct.unpack("<I", read_exact(port, 4))[0]

        port.write(bytes([MONITOR_ERROR]))
        port.flush()
        error_status = struct.unpack("<I", read_exact(port, 4))[0]

    return RESPONSE_MAGIC + struct.pack(
        "<HII", PROTOCOL_VERSION, result_word, error_status
    )


def main():
    parser = argparse.ArgumentParser(description="CML to fpga-lisp UART job bridge")
    parser.add_argument("--port", default="COM4")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--timeout", type=float, default=2.0)
    parser.add_argument("--reset-wait", type=float, default=3.0)
    parser.add_argument("--halt-wait", type=float, default=2.0)
    args = parser.parse_args()

    try:
        response = execute(
            args.port,
            args.baud,
            args.timeout,
            args.reset_wait,
            args.halt_wait,
            sys.stdin.buffer.read(),
        )
    except Exception as error:
        print(f"FPGA bridge failed: {error}", file=sys.stderr)
        return 1

    sys.stdout.buffer.write(response)
    sys.stdout.buffer.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
