# Real hardware setup: Tang Primer 25K, Gowin toolchain, Windows/WSL2

Notes from actually flashing and debugging the board (2026-08-13 through
2026-08-24), so a future session doesn't rediscover this from scratch. The
JTAG driver conflict described below was resolved on 2026-08-24; the failed
attempts remain as provenance for the working recipe.

## Toolchain locations

- Gowin IDE + Programmer: `C:\Gowin\Gowin_V1.9.12.03_x64\`
  - Synthesis (headless): `IDE\bin\gw_sh.exe`
  - JTAG programmer (headless): `Programmer\bin\programmer_cli.exe`
- Synthesis script: `fpga/synth/build.tcl` (Gowin-proprietary TCL API --
  `set_device`/`add_file`/`run all` -- not yosys; this repo's `manifest.scm`
  yosys entry is for other purposes, not this flow)

## Synthesis (works)

```
"C:\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe" "fpga/synth/build.tcl"
```

Run from the repo root (paths in `build.tcl` are relative to it).
**Use forward slashes for the script path** even on Windows -- Git
Bash swallows backslashes before Gowin's own TCL parser sees them,
producing `couldn't read file "fpgasynthbuild.tcl"` (concatenated,
backslashes stripped) instead of a real path.

Outputs land in `impl/` (gitignored): `impl/gwsynthesis/project.vg`
(netlist), `impl/pnr/project.fs` (bitstream), `impl/pnr/project.rpt.txt`
(resource usage), `impl/pnr/project_tr_content.html` (timing report --
search for `MHz` and `Total Negative Slack Summary`).

Verified 2026-08-13 against the current RTL (through M32): synthesis,
place-and-route, bitstream generation all complete cleanly. `Fmax =
60.801 MHz` vs the `50 MHz` constraint (`lisp_machine.sdc`), zero
negative slack. BSRAM 24/56 (43%), matching the number
`docs/lisp-machine-plan.md` already derived from real synthesis at
M18's imem expansion.

### Current FPGA resource snapshot (ISA 1.1, commit `092aa3b`)

The permanently flashed 2026-08-24 build uses:

| Resource | Used | Utilization | Remaining |
|---|---:|---:|---:|
| Logic | 1,935 / 23,040 | 9% | 21,105 |
| LUT | 1,692 | about 7% of logic capacity | substantial |
| ALU | 243 | included in Logic | - |
| Registers | 1,207 / 23,280 | 6% | 22,073 |
| CLS | 1,605 / 11,520 | 14% | 9,915 |
| BSRAM | 24 / 56 | 43% | 32 blocks |
| I/O ports | 5 / 86 | 6% | 81 |
| Primary clocks | 1 / 8 | 13% | 7 |
| Local-wire clocks | 5 / 8 | 63% | 3 |

The 50 MHz clock constraint closes cleanly at an actual Fmax of
66.727 MHz: setup and hold TNS are both `0.000`, with no violated
endpoints. This is about 33% frequency headroom over the operating clock.

The practical near-term constraint is BSRAM, not logic: roughly 91% of the
logic and 94% of the registers remain free, while only 57% of block RAM
remains. New execution logic, control paths and hardware operations therefore
have ample fabric headroom. Heap, instruction-memory and bulk-buffer growth
should be budgeted deliberately; larger data capacity may eventually need
external-memory or host-staged designs rather than consuming BSRAM without a
plan.

## UART (upload.py / monitor.py) -- works, with two gotchas

**Run from native Windows Python, not WSL.** WSL2's `/dev/ttyS*` legacy
COM-port bridge (`COM<n>` -> `/dev/ttyS(n-1)`) does not support full
`termios` configuration for USB-serial (FTDI) devices -- opening the
port succeeds, but `pyserial` fails with `termios.error: (5,
'Input/output error')` when it tries to configure baud/parity/etc.
This is a WSL2 platform limitation, not a bug in this repo's tooling.

Install on native Windows:
```
winget install -e --id Python.Python.3.12
python -m pip install pyserial
```

**Group/permission note (WSL2 only, if you go that route anyway):**
`/dev/ttyS*` is owned by group `dialout`; a fresh per-repo WSL user
isn't in it by default (`Permission denied` until `sudo usermod -aG
dialout <user>` + re-login for the new group to take effect). Not
relevant once running from native Windows, but worth knowing if WSL2's
termios limitation above ever gets fixed upstream.

**Which physical COM port is UART:** the board's FT2232 exposes two
channels, enumerated as `USB Serial Converter A`/`B` -> `COM3`/`COM4`
(port numbers will vary machine to machine). Channel B (`COM4` in this
setup) is the one `upload.py`/`monitor.py` actually talk to
successfully -- confirmed by a real upload completing without error
and the board's own `PRESS RESET` prompt timing lining up. Channel A is
the JTAG interface (see below) -- don't point the UART tools at it.

## JTAG programming -- RESOLVED 2026-08-24

After reconnecting the board with the child VCP for Channel A disabled, while
the parent `USB Serial Converter A` remained enabled, Gowin enumerated two
`USB Debugger A` locations. Location `449` was the JTAG endpoint:

```text
programmer_cli.exe --cable-index 4 --location 449 --scan
→ GW5A-25A family, ID 0x0001281B, one device
```

Volatile SRAM programming then completed successfully:

```text
programmer_cli.exe --cable-index 4 --location 449 \
  --device GW5A-25A --operation_index 2 \
  --fsFile C:/GitHub/fpga-lisp/impl/pnr/project.fs
→ 100%, User Code 0x00008DFD, Status 0x70026020, Finished
```

Bitstream SHA-256:
`557bbe28190611e3785475a2755a717d5be6a50c25ff88acb0002da6182dfe3a`.
Operation 2 changes SRAM only; power cycling removes the image.

### Permanent external-flash programming -- verified 2026-08-24

The current ISA 1.1 RTL at commit `092aa3b` was synthesized with Gowin EDA
and written to the board's external SPI NOR with the Arora V operation:

```text
programmer_cli.exe --cable-index 4 --location 449 \
  --device GW5A-25A --operation_index 54 --frequency 2.5MHz \
  --fsFile C:/GitHub/fpga-lisp/impl/pnr/project.fs
→ SPI flash ID 0x0B4017
→ Program and Verify Flash successfully.
→ Finished. Cost 35.12 seconds.
```

The programmed `project.fs` is 6,604,065 bytes with SHA-256
`4a5ba486c4592c75db9d261641b219d9f2608706abbc8dacc53931099dffdb9b`.
Its place-and-route report gives `Fmax = 66.727 MHz` for the 50 MHz
constraint, setup/hold TNS `0.000`, BSRAM 24/56, 1,692 LUTs and 1,207
registers.

Permanence was tested rather than inferred from the programmer's success:
the board was fully disconnected from USB power for at least five seconds
and reconnected. A fresh JTAG scan found the same device ID `0x0001281B`.
Native Windows `monitor.py` then uploaded the 280-instruction
`bootstrap_add_demo.bin` over COM4; the cold-booted design returned
`R9 = FIXNUM(7) [0x00000007]` and `ERR: no error`. This proves external-flash
boot for this exact bitstream and one `(plus 3 4)` execution path, not blanket
hardware conformance.

The second enumerated location (`450`) did not return from `--scan` and left a
`programmer_cli` process holding Channel B/COM4. Terminating only that scan
process released the UART port. Do not probe both locations sequentially
without an explicit timeout; use the confirmed JTAG location `449` while the
USB topology remains unchanged.

The first physical smoke after programming uploaded `bootstrap_add_demo.bin`
(280 instructions) through native Windows Python/pyserial on COM4. The board
halted normally with `R9 = FIXNUM(7) [0x00000007]` and `ERR: no error`, proving
the `(plus 3 4)` eval path on the physical FPGA for this bitstream.

### CML command bridge

`job_transport.py` is the non-interactive native-Windows transport used by
CML's `CommandFpgaTransport`. It reads a versioned binary job on stdin, owns
COM4/reset/HALT timing and exact monitor reads, and returns only a fixed binary
result on stdout. Diagnostics and the reset prompt go to stderr. This is a
host-I/O adapter, not a new Lisp primitive or a second ISA protocol.

The CML live integration test supplies a ten-second reset window and runs the
same `bootstrap_add_demo.bin` expectation through the heterogeneous Execution
Graph. Device presence alone is not a pass: the test must return raw tagged
word `0x00000007` and a clear hardware-error status.

That stronger test passed on 2026-08-24 in 13.37 seconds: CML registered the
physical board as `fpga-lisp:com4`, uploaded the 280-word program, received R9
as `0x00000007`, observed no hardware error, and published
`GraphValue::LispWord(7)`. This verifies the command bridge plus one real graph
program path; it does not generalize to all FPGA programs.

The next live CML test placed the same physical FPGA after real CPU and CUDA
nodes in one dependency graph. It passed in 14.61 seconds with execution order
CPU → CUDA → FPGA: the numeric buffer evolved `[1,2,3] → [2,3,4] → [3,4,5]`,
then COM4 returned `GraphValue::LispWord(7)`. This proves coordinated physical
scheduling, not direct GPU-to-FPGA payload transfer; the FPGA node still owns
its independent preassembled program image.

### Earlier blocked state and diagnosis

**Symptom:** `programmer_cli.exe --scan` (or any `--operation_index`)
against Channel A's cable fails: `Error: Cable failed to open via the
channel.` / `No Gowin devices found!`.

**Root cause (confirmed):** Windows auto-binds a VCP (COM-port) driver
to *both* FT2232 channels by default. Gowin's JTAG access goes through
FTDI's D2XX interface instead (see the bundled `ftd2xx.dll` under
`Programmer\bin\data\DLL\ftdi\`), which needs *exclusive* access to the
channel -- the VCP driver holding it blocks D2XX from opening it at
all. This is a well-known FTDI VCP-vs-D2XX exclusivity conflict, not
specific to this board or this repo.

**What's been tried, and didn't fully resolve it:**

1. Disabling the whole `USB Serial Converter A` device (Device
   Manager, parent composite device) -- this removes the channel from
   USB enumeration *entirely*, so it also disappears from
   `programmer_cli.exe --scan-cables`'s results. Too blunt: it doesn't
   free the channel for D2XX, it just hides it from everything.
2. Disabling only the child `USB Serial Port (COM3)` device (the VCP
   layer specifically, leaving the parent `USB Serial Converter A`
   enabled) -- more surgical, and `Get-CimInstance Win32_PnPEntity`
   confirms `ConfigManagerErrorCode: 22` (disabled) on COM3 while
   Converter A stays `0` (enabled) -- but `--scan` still fails
   identically afterward. Windows's USB driver stack likely needs a
   reboot to fully release whatever handle `ftdibus.sys`/`ftdiport.sys`
   held before the D2XX layer can claim exclusive access; a live
   Device Manager toggle doesn't force that at the kernel level.

**Not yet tried:** a full Windows reboot after the COM3-disable step
(the standard fix for USB driver-stack rebind issues that don't take
effect live). Whoever picks this up next should try that first before
any further driver surgery.

**Also not yet ruled out:** whether `cable-index` stays stable across
these changes -- `--scan-cables` re-enumerates and re-numbers cables
each time a channel disappears/reappears from Windows's USB tree
(observed going from 2 cables at indices 0/1 down to 1 cable at index
0 after disabling Converter A). Always re-run `--scan-cables` right
before using a `--cable-index`, don't assume a previously-observed
index is still valid.

## Earlier open item — now partially closed

The JTAG and UART transport blocker is closed by the live evidence above.
`bootstrap_add_demo` is hardware-confirmed. This does not by itself verify
every M17-M32 program; each additional claimed behavior still needs its own
uploaded binary and observed register/heap/error result.
