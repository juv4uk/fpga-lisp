# FPGA shared-oracle parity 1 — permanent Flash cold boot, 2026-09-11

## Українська

### Твердження

Поточний `fpga-lisp` bitstream записано у зовнішню SPI Flash GW5A-25A й
перевірено після повного cold boot. Це окремий доказ від SRAM-запису та
окремий від RTL simulation.

### Постійний образ

```text
bitstream:          impl/pnr/project.fs
SHA-256:            DDBEDD2BF2DFCD8726D736959ADFEF6B9380709584F1066B7F6D1CDCC85A4950
board:              GW5A-25A (device ID 0x0001281B)
JTAG cable/location USB Debugger A / 4 / 449
operation:          exFlash Erase, Program, Verify Arora V (operation_index 54)
SPI Flash ID:       0x0B4017
```

Власник повністю відключив і знову підключив плату. Після цього native
Windows `monitor.py` відкрив `COM4` на 115200 baud. Власник натиснув Reset
у трисекундному upload-вікні, і завантажувач, що прийшов саме з Flash-boot
образу, прийняв 7-інструкційний `corpus-02.bin`.

### Readback

```text
Uploading 7 instructions from corpus-02.bin...
Upload complete. Waiting for HALT ...
R15 = SYMBOL(79)  [0x2000004F]
ERR: no error (halted normally via HALT)
```

`corpus-02.bin` має SHA-256
`561f78e98cf5074aaba1842152bbb913c7c8b4b260a814f127f8520dc4c8566c` і
є CML-produced image для pinned upstream corpus case
`(atom (quote radio))`. Semantic expected `t` та повна source/CML/RTL
provenance лишаються в
[`rtl-sim-2026-09-11/result.json`](rtl-sim-2026-09-11/result.json).

### Межа доказу

Це доводить, що **цей** permanent Flash image успішно cold-boot-иться і
запускає конкретний UART-loaded oracle image. Воно не доводить повну
conformance, усі corpus fixtures чи властивості майбутніх Flash images.

## English

The current bitstream was permanently programmed into the GW5A-25A external
SPI Flash, then the board was physically power-cycled. The Flash-booted
machine accepted the CML-generated `corpus-02.bin` over COM4 and returned
`R15 = SYMBOL(79) [0x2000004F]` with no error. This proves cold boot and one
specific physical oracle path for this bitstream only; it is not blanket
language conformance.
