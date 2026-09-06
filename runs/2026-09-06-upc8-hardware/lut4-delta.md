# LUT4 Delta: ISA 1.1 → ISA 1.2 with unified UPC-8 (2026-09-06)

**Завдання:** виміряти реальний апаратний кошт `upc8_unit` на FPGA
через порівняльний синтез (controlling: один tool, один день, один set constraints).

**Джерело даних:** два synthesis reports, згенеровані тим самим `gw_sh.exe`
(Gowin V1.9.12.03, GW5A-25A, `lisp_machine.sdc` constraint 50 MHz):

- База: `git worktree /tmp/fpga-baseline @015c68a`, `impl/pnr/project.rpt.txt`
- З upc8: HEAD `04a4f6a`, `impl/pnr/project.rpt.txt`

## Результати

| Показник | 015c68a (ISA 1.1) | 04a4f6a (ISA 1.2) | Дельта |
|---|---|---|---|
| Logic | 1862 | 2068 | +206 |
| — LUT | 1619 | 1825 | +206 |
| — ALU | 243 | 243 | 0 |
| — ROM16 | 0 | 0 | 0 |
| Register (FF) | 1207 | 1207 | 0 |
| BSRAM | 24/56 | 24/56 | 0 |
| Logic Level | 11 | 13 | +2 |
| Fmax | 65.827 MHz | 62.842 MHz | −2.985 MHz |
| TNS | 0.000 ns | 0.000 ns | 0 |
| Constraint | 50.000 MHz | 50.000 MHz | — |

## Інтерпретація

- **+206 LUT** — чисто комбінаційне логічне дерево: upc8 decode (~14 LUT
  for opcodes), 7 transform-операцій (toggle-length/nasal, next/prev-row,
  guna, voice, aspirate), predicate (4-bit), reserved-check, error-mux.
- **ALU 0** — transform реалізований мультиплексорами, не ALU-операціями
  ( Gowin ALU ≠ LUT-based mux у datasheet).
- **Register 0** — комбінаційний пас, без pipeline-регистрів.
- **+2 Logic Level** — додаткові глибина шляху, зменшили Fmax на ~3 MHz;
  обидві конфігурації стабільні (TNS = 0, 0 endpoints).
- Попередня оцінка ~75 LUT4 була **недооцінкою в 2.7×**. Реальний апаратний
  кошт значно більший за теоретичну мінімальну оцінку через:
  (a) overflow protection + reserved-row апаратну перевірку;
  (b) transform_error та transform_valid мультиплексори;
  (c) guna_matrix (4 input × 4 output LUT-матриця);
  (d) поєднання 8 opcode-класів з audio-feature логікою.
