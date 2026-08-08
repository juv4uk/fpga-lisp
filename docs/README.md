# Documentation

This directory contains the documentation for Gowin EDA and the Sipeed Tang Primer 25K FPGA board.

## Gowin EDA
The Gowin EDA user guides, release notes, and IP core manuals have been copied here from the local Gowin installation. Key documents include:
- `SUG100-*.pdf`: Gowin Software User Guide (Main IDE usage)
- `SUG935-*.pdf`: Design Physical Constraints User Guide (Pinout assignments)
- `SUG113-*.pdf`: Gowin FPGA Design User Guide
- `UG289-*.pdf`: Programmable IO (GPIO) User Guide

## Tang Primer 25K (Hardware)
Due to Sipeed's download protection, PDF schematics and board datasheets cannot be downloaded directly via terminal scripts. 

You can download the board schematics, pinout maps, and the GW5A-25A datasheet manually from the Sipeed Wiki:
**[Sipeed Tang Primer 25K Download Station](https://wiki.sipeed.com/hardware/en/tang/Tang-Primer-25K/primer-25k.html)**

We have also cloned the official `TangPrimer-25K-example` repository here, which contains reference Verilog code for various peripherals (UART, HDMI, SDRAM, etc).
