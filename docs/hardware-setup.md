# Real hardware setup: Tang Primer 25K, Gowin toolchain, Windows/WSL2

Notes from actually flashing and debugging the board (2026-08-13), so a
future session doesn't rediscover this from scratch. Written mid-debug
-- the JTAG driver conflict below is **not yet resolved**; this
document records what's been tried and ruled out, not a working
recipe end to end.

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

## JTAG programming -- BLOCKED as of this writing, root cause identified but not fixed

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

## Open item

Actual board flash-and-verify of M17-M32 (the other half of
`FPGA-HARDWARE-VERIFY-M17-M32`) is still blocked on the JTAG issue
above. UART-only verification (bypassing JTAG, if the board already
has *some* bitstream loaded from a previous session) was attempted but
got no response from the board (`No reply from board: Expected 4
bytes, got 0`) -- inconclusive on its own whether that's because no
compatible bitstream was ever actually programmed, or a reset-timing
issue unrelated to JTAG.
