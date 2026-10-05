#!/usr/bin/env python3
"""Native-Windows bridge that owns physical FPGA serial I/O for WSL runners."""

import base64
import inspect
import ipaddress
import json
import os
import pathlib
import socketserver
import struct
import subprocess
import sys
import threading
import time

import serial
import serial.tools.list_ports


HOST = "0.0.0.0"
PORT = int(os.environ.get("FPGA_RUNNER_BRIDGE_PORT", "8765"))
SERIAL_LOCK = threading.Lock()
FPGA_REPO = pathlib.Path(
    os.environ.get("FPGA_LISP_WINDOWS_REPO", r"C:\GitHub\fpga-lisp")
)
sys.path.insert(0, str(FPGA_REPO))


def current_wsl_network():
    command = (
        "$x=Get-NetIPAddress -AddressFamily IPv4 | "
        "Where-Object {$_.InterfaceAlias -like 'vEthernet (WSL*'} | "
        "Select-Object -First 1; "
        "if ($x) { Write-Output ($x.IPAddress + '/' + $x.PrefixLength) }"
    )
    try:
        value = subprocess.check_output(
            ["powershell.exe", "-NoProfile", "-Command", command],
            text=True,
            timeout=2,
            creationflags=0x08000000,
        ).strip()
        if value:
            return ipaddress.ip_network(value, strict=False)
    except Exception:
        pass
    return None


def peer_allowed(peer_text):
    peer = ipaddress.ip_address(peer_text)
    if peer.is_loopback:
        return True
    network = current_wsl_network()
    return network is not None and peer in network


def read_exact(port, size):
    data = bytearray()
    while len(data) < size:
        chunk = port.read(size - len(data))
        if not chunk:
            raise TimeoutError(f"expected {size} bytes, got {len(data)}")
        data.extend(chunk)
    return bytes(data)


def probe(req):
    port_name = req.get("port", "COM4")
    baud = int(req.get("baud", 115200))
    timeout = float(req.get("timeout", 2.0))
    ports = {
        p.device: {"description": p.description, "hwid": p.hwid}
        for p in serial.tools.list_ports.comports()
    }
    info = ports.get(port_name)
    if info is None:
        raise RuntimeError(f"{port_name} not present")
    started = time.perf_counter_ns()
    with serial.Serial(
        port_name, baud, timeout=timeout, write_timeout=timeout
    ) as port:
        opened = port.is_open
    return {
        "ok": bool(opened),
        "op": "probe",
        "port": port_name,
        "baud": baud,
        "description": info["description"],
        "hwid": info["hwid"],
        "open_close_us": round(
            (time.perf_counter_ns() - started) / 1000.0, 1
        ),
    }


def monitor(req):
    port_name = req.get("port", "COM4")
    baud = int(req.get("baud", 115200))
    timeout = float(req.get("timeout", 2.0))
    register = int(req.get("register", 9))
    if not 0 <= register <= 15:
        raise ValueError("register must be 0..15")

    with serial.Serial(
        port_name, baud, timeout=timeout, write_timeout=timeout
    ) as port:
        port.reset_input_buffer()
        started = time.perf_counter_ns()
        port.write(bytes([0x01, register]))
        port.flush()
        result_word = struct.unpack("<I", read_exact(port, 4))[0]
        register_read_us = (time.perf_counter_ns() - started) / 1000.0

        started = time.perf_counter_ns()
        port.write(bytes([0x04]))
        port.flush()
        error_status = struct.unpack("<I", read_exact(port, 4))[0]
        error_read_us = (time.perf_counter_ns() - started) / 1000.0

    return {
        "ok": error_status == 0,
        "op": "monitor",
        "port": port_name,
        "register": register,
        "result_word": result_word,
        "error_status": error_status,
        "register_read_us": round(register_read_us, 1),
        "error_read_us": round(error_read_us, 1),
    }


def execute(req):
    try:
        import job_transport
    except ImportError as error:
        raise RuntimeError(
            f"cannot import {FPGA_REPO / 'job_transport.py'}"
        ) from error

    request = base64.b64decode(req["request_b64"], validate=True)
    port_name = req.get("port", "COM4")
    baud = int(req.get("baud", 115200))
    timeout = float(req.get("timeout", 2.0))
    reset_wait = float(req.get("reset_wait", 3.0))
    halt_wait = float(req.get("halt_wait", 2.0))
    soft_rearm = bool(req.get("soft_rearm", False))
    rearm_wait = float(req.get("rearm_wait", 0.05))

    kwargs = {}
    signature = inspect.signature(job_transport.execute)
    if soft_rearm:
        if "soft_rearm" not in signature.parameters:
            raise RuntimeError(
                "installed job_transport.py does not support soft rearm yet"
            )
        kwargs["soft_rearm"] = True
        kwargs["rearm_wait"] = rearm_wait

    started = time.perf_counter_ns()
    response = job_transport.execute(
        port_name,
        baud,
        timeout,
        reset_wait,
        halt_wait,
        request,
        **kwargs,
    )
    elapsed_ms = (time.perf_counter_ns() - started) / 1_000_000.0

    if len(response) != 14 or response[:4] != b"CMLR":
        raise RuntimeError(f"bad CMLR response: {response.hex()}")
    version, result_word, error_status = struct.unpack("<HII", response[4:])
    if version != 1:
        raise RuntimeError(f"unsupported CMLR version {version}")

    return {
        "ok": error_status == 0,
        "op": "execute",
        "protocol_version": version,
        "result_word": result_word,
        "error_status": error_status,
        "elapsed_ms": round(elapsed_ms, 3),
        "soft_rearm": soft_rearm,
    }


def handle_request(req):
    op = req.get("op")
    if op == "ping":
        return {
            "ok": True,
            "op": "ping",
            "bridge": "fpga-runner-bridge-v2",
        }
    if op == "probe":
        with SERIAL_LOCK:
            return probe(req)
    if op == "monitor":
        with SERIAL_LOCK:
            return monitor(req)
    if op == "execute":
        with SERIAL_LOCK:
            return execute(req)
    raise ValueError(f"unsupported op {op!r}")


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        if not peer_allowed(self.client_address[0]):
            self.wfile.write(
                b'{"ok":false,"error":"peer not allowed"}\n'
            )
            self.wfile.flush()
            return

        try:
            line = self.rfile.readline(16 * 1024 * 1024)
            if not line:
                return
            req = json.loads(line.decode("utf-8"))
            result = handle_request(req)
        except Exception as error:
            result = {
                "ok": False,
                "error": f"{type(error).__name__}: {error}",
            }

        self.wfile.write(
            (json.dumps(result, sort_keys=True) + "\n").encode("utf-8")
        )
        self.wfile.flush()


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    with Server((HOST, PORT), Handler) as server:
        server.serve_forever(poll_interval=0.2)
