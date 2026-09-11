# FPGA shared-oracle parity 1 — physical readback, 2026-09-11

## Українська

### Твердження

Два exact cases із того самого pinned `my-lisp` compiler corpus, що вже
мають RTL evidence, виконано на фізичній платі GW5A-25A. Обидва повернули
канонічне FPGA-представлення семантичного `t`: `TAG_SYMBOL` з payload `79`.

Semantic expected не створювався в FPGA. Він уже зафіксований у
[`../rtl-sim-2026-09-11/result.json`](rtl-sim-2026-09-11/result.json) з
upstream `my-lisp@4a5dba0d1d61103385406ef2821d76661442621c`.

### Bitstream і transport provenance

Перед запуском JTAG завантажив у **volatile SRAM** свіжий `project.fs`,
зібраний із дерева `fpga-lisp` на цьому кроці:

```text
board:             GW5A-25A
JTAG cable/index:  USB Debugger A / 4
JTAG location:     449
operation:         SRAM Program (operation_index 2)
bitstream SHA-256: DDBEDD2BF2DFCD8726D736959ADFEF6B9380709584F1066B7F6D1CDCC85A4950
```

`operation_index 2` не пише зовнішню Flash: це саме тимчасовий SRAM-образ.
Нативний Windows `monitor.py` відкрив FT2232 UART `COM4` на 115200 baud.
Власник натиснув фізичний Reset у трисекундному вікні перед кожним upload;
UART не може встановити `rst_n` замість кнопки.

### Спостереження

| Corpus ordinal | Source | Image SHA-256 | Upload | Actual readback | Semantic result |
| --- | --- | --- | ---: | --- | --- |
| 2 | `(atom (quote radio))` | `561f78e98cf5074aaba1842152bbb913c7c8b4b260a814f127f8520dc4c8566c` | 7 instructions | `R15 = SYMBOL(79) [0x2000004F]` | `t` |
| 3 | `(eq (quote radio) (quote radio))` | `1c72de5b5d653259b5c476da3122e25743f3642c20524ef2d540a0bf94522373` | 11 instructions | `R15 = SYMBOL(79) [0x2000004F]` | `t` |

Raw monitor transcript for each run:

```text
Uploading <7|11> instructions from corpus-0<2|3>.bin...
Upload complete. Waiting for HALT ...
R15 = SYMBOL(79)  [0x2000004F]
```

`TAG_SYMBOL=2` походить з `fpga/rtl/lisp_word.sv`; `SYM_T=79` — з
`fpga/asm/symbol-table.inc`. Це target representation, а не друге джерело
очікуваної Lisp-семантики.

### Межі доказу

Це два physical board witnesses для конкретних CML-produced images. Вони не
доводять повну FPGA conformance, нову numeric semantics, rationals або
permanent Flash programming. Mutation witness належить RTL gate і лишається
зафіксованим у його `result.json`; цей документ не підміняє його новим
компаратором. Наступний корисний зріз — G2/G8 через існуючий gate без нового
opcode чи tag.

## English

The two exact cases already covered by the pinned upstream corpus RTL gate
were also loaded and observed on the physical GW5A-25A board. Both returned
`R15 = SYMBOL(79) [0x2000004F]`, the target representation of the upstream
semantic expected value `t`. The image, SRAM bitstream, cable/location,
transport, and readback are recorded above. This is physical evidence for
two images only; it is neither a claim of complete conformance nor of
persistent Flash programming.
