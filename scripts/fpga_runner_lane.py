#!/usr/bin/env python3
"""Native-Windows serial helper for the shared local FPGA runner lane."""

import argparse
import json
import pathlib
import struct
import sys
import time

import serial
import serial.tools.list_ports


def read_exact(port, size):
    data = bytearray()
    while len(data) < size:
        chunk = port.read(size - len(data))
        if not chunk:
            raise TimeoutError(f"expected {size} bytes, got {len(data)}")
        data.extend(chunk)
    return bytes(data)


def probe(args):
    ports = {
        p.device: {"description": p.description, "hwid": p.hwid}
        for p in serial.tools.list_ports.comports()
    }
    info = ports.get(args.port)
    if info is None:
        raise RuntimeError(f"{args.port} not present")
    started = time.perf_counter_ns()
    with serial.Serial(
        args.port,
        args.baud,
        timeout=args.timeout,
        write_timeout=args.timeout,
    ) as port:
        opened = port.is_open
    elapsed_us = (time.perf_counter_ns() - started) / 1000.0
    print(
        json.dumps(
            {
                "ok": bool(opened),
                "port": args.port,
                "baud": args.baud,
                "description": info["description"],
                "hwid": info["hwid"],
                "open_close_us": round(elapsed_us, 1),
            },
            sort_keys=True,
        )
    )


def monitor(args):
    with serial.Serial(
        args.port,
        args.baud,
        timeout=args.timeout,
        write_timeout=args.timeout,
    ) as port:
        port.reset_input_buffer()
        started = time.perf_counter_ns()
        port.write(bytes([0x01, args.register]))
        port.flush()
        value = struct.unpack("<I", read_exact(port, 4))[0]
        register_us = (time.perf_counter_ns() - started) / 1000.0

        started = time.perf_counter_ns()
        port.write(bytes([0x04]))
        port.flush()
        error_status = struct.unpack("<I", read_exact(port, 4))[0]
        error_us = (time.perf_counter_ns() - started) / 1000.0

    print(
        json.dumps(
            {
                "ok": error_status == 0,
                "port": args.port,
                "register": args.register,
                "result_word": value,
                "error_status": error_status,
                "register_read_us": round(register_us, 1),
                "error_read_us": round(error_us, 1),
            },
            sort_keys=True,
        )
    )
    if error_status != 0:
        raise SystemExit(2)


def execute_bin(args):
    repo = pathlib.Path(args.repo)
    sys.path.insert(0, str(repo))
    import job_transport

    data = pathlib.Path(args.file).read_bytes()
    if not data or len(data) % 4:
        raise RuntimeError("binary must be a non-empty sequence of 32-bit words")
    count = len(data) // 4
    if count > 4095:
        raise RuntimeError(f"program too long: {count} words")

    request = b"CMLJ" + struct.pack("<HBBH", 1, args.register, 0, count) + data
    started = time.perf_counter_ns()
    response = job_transport.execute(
        args.port,
        args.baud,
        args.timeout,
        args.reset_wait,
        args.halt_wait,
        request,
    )
    elapsed_ms = (time.perf_counter_ns() - started) / 1_000_000.0

    if len(response) != 14 or response[:4] != b"CMLR":
        raise RuntimeError(f"bad bridge response: {response.hex()}")
    version, value, error_status = struct.unpack("<HII", response[4:])
    print(
        json.dumps(
            {
                "ok": version == 1 and error_status == 0,
                "port": args.port,
                "program": str(args.file),
                "program_words": count,
                "protocol_version": version,
                "result_word": value,
                "error_status": error_status,
                "elapsed_ms": round(elapsed_ms, 3),
            },
            sort_keys=True,
        )
    )
    if version != 1 or error_status != 0:
        raise SystemExit(2)


def main():
    parser = argparse.ArgumentParser(
        description="Native Windows UART side of the single-owner FPGA runner lane"
    )
    parser.add_argument("--port", default="COM4")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--timeout", type=float, default=2.0)
    sub = parser.add_subparsers(dest="command", required=True)

    command = sub.add_parser("probe")
    command.set_defaults(func=probe)

    command = sub.add_parser("monitor")
    command.add_argument("--register", type=int, default=9, choices=range(16))
    command.set_defaults(func=monitor)

    command = sub.add_parser("execute-bin")
    command.add_argument("--repo", default=r"C:\GitHub\fpga-lisp")
    command.add_argument("--file", required=True)
    command.add_argument("--register", type=int, default=9, choices=range(16))
    command.add_argument("--reset-wait", type=float, default=3.0)
    command.add_argument("--halt-wait", type=float, default=2.0)
    command.set_defaults(func=execute_bin)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
