# Hardware Verification: Unified UPC-8 on Tang Primer 25K (2026-09-06)

**Мета:** фізична перевірка інтегрованого UPC-8 рушія (ISA 1.2, MOV rs2=4/5/6)
на реальній платі Tang Primer 25K (GW5A-25A, board ID 0x0001281B).

**Статус: АПАРАТНИЙ PASS.**

---

## Flash-прошивка (перманентна ISA 1.2) — перевірено 2026-09-06

### Операція 54 (exFlash Erase, Program, Verify, Arora V)

```text
programmer_cli.exe --cable-index 1 --location 449 --device GW5A-25A \
  --operation_index 54 --frequency 2.5MHz \
  --fsFile \\wsl.localhost\Ubuntu\...\impl\pnr\project.fs
→ SPI flash ID 0x0B4017
→ Program and Verify Flash successfully.
→ Cost 41.5 second(s)
```

- Останній попередній Flash-образ був `092aa3b` (ISA 1.1, 2026-08-24). Тепер
  Flash містить ISA 1.2 (SHA `0535bc34...`, User Code `0x00005A25`).
- **Permanence перевірено фактом** (не лише за звітом інструмента): повне
  відключення USB-живлення на ~10 с, повторне підключення, `--scan` →
  ID `0x0001281B`; cold-boot UART-тест `bootstrap_add_demo.bin` →
  **R9 = FIXNUM 7, ERR=0**; потім SRAM-reload + upc8_smoke → усі
  регістри PASS. ISA 1.2 переживає знеструмлення і завантажується з Flash.

### Урок з помилки (чесність > красивый звіт)

Перша спроба operation 54 провалилась через пайплайн: вивід
`programmer_cli.exe` був пропущений через `head -30`, який закрив stdout,
процес отримав SIGPIPE і вмер **посередині** запису Flash (лог — 14× "0%").
Flash лишився у проміжному стані, FPGA-ланцюг перестав відповідати на JTAG
(`Error: No Gowin devices found!`, SRAM-операція теж fail, EXIT=3).
Відновлення — повне знеструмлення плати на ~5–10 с (штатний рецепт з
`docs/hardware-setup.md`), після чого пристрій повернувся (ID `0x0001281B`),
а повторна операція 54 пройшла успішно. **Правило: ніколи не пропускати
вивід programmer_cli через head/tail без збереження повного логу у файл.**

---

## Прошитий бітстрім

- Джерело: `impl/pnr/project.fs` (свіжий синтез, **Sep 6 20:16**, 6 765 345 байт,
  SHA-256 `0535bc34f609ce25c65b2d05ec41d76ce37c4913ffa761c603b21f547538bb7e`).
- Прошивка: `programmer_cli.exe --cable-index 1 --location 449 --device GW5A-25A
  --operation_index 2 --fsFile \\wsl.localhost\Ubuntu\...\impl\pnr\project.fs`
  (SRAM, operation 2). User Code на платі: `0x00005A25`.
- **Важлива помилка, виявлена й виправлена:** початково fsFile вказував на
  `C:/GitHub/fpga-lisp/impl/pnr/project.fs` — це **окремий Windows-checkout**
  (HEAD `092aa3b`, ISA 1.1), бітстрім Aug 24 (6 604 065 байт), HASH
  `4a5ba486...`. Тобто перша прошивка містила **старий ISA 1.1**. Виправлено
  повторною прошивкою з правильної (шойно синтезованої) WSL-локації.

## Тест 1: UPC-8 наскрізний (upc8_smoke.bin)

8 інструкцій, ідентичні `fpga/sim/tb_upc8_machine.sv`:

```
0x11000083  LOADI R1, 0x83
0x22140000  MOV R2,R1,rs2=4   ; decode  0x83 -> 0x183
0x11000183  LOADI R1, 0x183   ; op=001 (toggle length), code=0x83
0x23150000  MOV R3,R1,rs2=5   ; transform -> 0x2182
0x11000080  LOADI R1, 0x80
0x24140000  MOV R4,R1,rs2=4   ; decode  0x80 -> 0x780
0x25160000  MOV R5,R1,rs2=6   ; predicate -> 0x007
0xB0000000  HALT
```

**Результат на платі (CHEZ COM4 через monitor-протокол):**

| Регістр | Очікування | Плата | Sim (tb_upc8_machine) |
|---|---|---|---|
| R2 | 0x183 | TAG:0 VAL:0x0000183 | PASS |
| R3 | 0x2182 | TAG:0 VAL:0x0002182 | PASS |
| R4 | 0x780 | TAG:0 VAL:0x0000780 | PASS |
| R5 | 0x007 | TAG:0 VAL:0x0000007 | PASS |
| ERR | 0 | flag=0 pc=0 | PASS |

## Тест 2: smoke основної машини (bootstrap_add_demo.bin)

`(add 3 4)` через full bootstrap (280 інструкцій) — регресія, що
оцінювальні зміни в `control.sv` (u_upc8 + encoded-mode MOV) не зламали ядро.

**Результат на платі:** `R9 = TAG:0 VAL:0x0000007` (FIXNUM 7), ERR=0.

Збігається з iverilog: `tb_bootstrap_add.sv` → "M27 PASSED: PRIM_ADD dispatch
through eval works".

## Протокол і умови

- UART: FT2232 channel B = COM4 (115200 8N1), channel A VCP вимкнено (JTAG).
- Завантаження програми: 2-байтовий length LE + 32-бітні інструкції LE.
- **Вимога:** після попереднього HALT плата не приймає нову програму —
  потрібен скид машини. Найнадійніший спосіб зі скриптів: повторне SRAM-
  програмування (операція 2, ~8 s), яке повертає машину в початковий стан.
  (Програма не містить апаратного reset-каналу в monitor-протоколі.)
- HALT детектується опитуванням: читати reg 0, поки не поверне 4 байти.

## Артефакти

- `evidence/upc8-hardware-2026-09-06/upc8_smoke.bin`
- `evidence/upc8-hardware-2026-09-06/upc8_smoke_driver.py` (Windows Python 3.12,
  тільки pyserial; одна точка вʼїзду: `python upc8_smoke_driver.py <bin>`).
- Цей звіт: `runs/2026-09-06-upc8-hardware/README.md`
- `runs/2026-09-06-upc8-hardware/lut4-delta.md` — порівняльний синтез
  (baseline `015c68a` vs `04a4f6a`, +206 LUT, +2 logic level).