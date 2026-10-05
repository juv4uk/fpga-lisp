#!/usr/bin/env python3
"""WSL-side client for the single-owner native-Windows FPGA runner bridge."""

import argparse
import base64
import json
import os
import pathlib
import socket
import struct
import subprocess


def default_host():
    override = os.environ.get("FPGA_BRIDGE_HOST")
    if override:
        return override
    output = subprocess.check_output(
        ["ip", "route", "show", "default"], text=True, timeout=2
    )
    fields = output.split()
    try:
        return fields[fields.index("via") + 1]
    except (ValueError, IndexError) as error:
        raise RuntimeError(
            f"cannot resolve WSL Windows-host gateway from: {output!r}"
        ) from error


def transact(host, port, payload, timeout):
    wire = (json.dumps(payload, sort_keys=True) + "\n").encode("utf-8")
    with socket.create_connection((host, port), timeout=timeout) as sock:
        sock.settimeout(timeout)
        sock.sendall(wire)
        chunks = bytearray()
        while b"\n" not in chunks:
            chunk = sock.recv(4096)
            if not chunk:
                break
            chunks.extend(chunk)
    if not chunks:
        raise RuntimeError("FPGA bridge returned no response")
    response = json.loads(bytes(chunks).split(b"\n", 1)[0].decode("utf-8"))
    if response.get("ok") is not True:
        raise RuntimeError(response.get("error", f"FPGA bridge rejected request: {response}"))
    return response


def add_common(payload, args):
    payload["port"] = args.serial_port
    payload["baud"] = args.baud
    payload["timeout"] = args.serial_timeout
    return payload


def command_ping(args):
    return transact(args.host, args.bridge_port, {"op": "ping"}, args.bridge_timeout)


def command_probe(args):
    return transact(
        args.host,
        args.bridge_port,
        add_common({"op": "probe"}, args),
        args.bridge_timeout,
    )


def command_monitor(args):
    return transact(
        args.host,
        args.bridge_port,
        add_common({"op": "monitor", "register": args.register}, args),
        args.bridge_timeout,
    )


def command_execute_bin(args):
    data = pathlib.Path(args.file).read_bytes()
    if not data or len(data) % 4:
        raise RuntimeError("binary must be a non-empty sequence of 32-bit words")
    word_count = len(data) // 4
    if word_count > 4095:
        raise RuntimeError(f"program too long: {word_count} words")

    request = b"CMLJ" + struct.pack("<HBBH", 1, args.register, 0, word_count) + data
    payload = add_common(
        {
            "op": "execute",
            "request_b64": base64.b64encode(request).decode("ascii"),
            "reset_wait": args.reset_wait,
            "halt_wait": args.halt_wait,
            "soft_rearm": args.soft_rearm,
            "rearm_wait": args.rearm_wait,
        },
        args,
    )
    result = transact(args.host, args.bridge_port, payload, args.bridge_timeout)
    result.setdefault("program_words", word_count)
    result.setdefault("program", str(args.file))
    return result


def main():
    parser = argparse.ArgumentParser(
        description="WSL client for the native Windows COM4 FPGA runner bridge"
    )
    parser.add_argument("--host", default=default_host())
    parser.add_argument(
        "--bridge-port",
        type=int,
        default=int(os.environ.get("FPGA_BRIDGE_PORT", "8765")),
    )
    parser.add_argument("--bridge-timeout", type=float, default=10.0)
    parser.add_argument("--port", dest="serial_port", default="COM4")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--timeout", dest="serial_timeout", type=float, default=2.0)

    sub = parser.add_subparsers(dest="command", required=True)

    command = sub.add_parser("ping")
    command.set_defaults(func=command_ping)

    command = sub.add_parser("probe")
    command.set_defaults(func=command_probe)

    command = sub.add_parser("monitor")
    command.add_argument("--register", type=int, default=9, choices=range(16))
    command.set_defaults(func=command_monitor)

    command = sub.add_parser("execute-bin")
    command.add_argument("--file", required=True)
    command.add_argument("--register", type=int, default=9, choices=range(16))
    command.add_argument("--reset-wait", type=float, default=3.0)
    command.add_argument("--halt-wait", type=float, default=2.0)
    command.add_argument("--soft-rearm", action="store_true")
    command.add_argument("--rearm-wait", type=float, default=0.05)
    command.set_defaults(func=command_execute_bin)

    args = parser.parse_args()
    print(json.dumps(args.func(args), sort_keys=True))


if __name__ == "__main__":
    main()
