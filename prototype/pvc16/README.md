# PVC-16: 16-Bit Phonetic Vector Code for FPGA Lisp

## Overview
PVC-16 is a hardware-optimized 16-bit articulatory bit-vector representation for phonemes. Unlike flat 8-bit sequential character sets, PVC-16 encodes phonetic features (Sthāna, Prayatna, Svara, Modifiers) directly into specific bit positions.

## Bit Layout
```
 15  14  13  12 │ 11  10   9   8 │  7   6   5   4 │  3   2   1   0
┌───┬───┬───┬───┼───┬───┬───┬───┼───┬───┬───┬───┼───┬───┬───┬───┐
│Mod│Acc│Len│Len│Gh │Mh │Sp │Asp│Ka │Ta │Mu │Da │Os │Na │Pl │Vow│
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
```

## Single-Cycle Hardware Features
1. **Sūtra 1.1.9 (`tulyāsyaprayatnaṁ savarṇam`):** Computed in 1 clock cycle using simple combinational logic (`is_savarna`).
2. **Voicing / Devoicing:** `sound ^ GHOSHA_MASK` in 1 clock cycle.
3. **Synthesis:** Requires fewer than 8 FPGA LUTs for full Savarṇa comparison.

## Running Tests in Guix
```bash
guix shell --pure -m manifest.scm -- python3 -m unittest test_pvc16.py
guix shell --pure -m manifest.scm -- iverilog -o pvc16_sim pvc16.v pvc16_tb.v && vvp pvc16_sim
```

---

# PVC-16: 16-бітний фонетичний векторний код для FPGA Lisp (Ukrainian)

## Огляд
PVC-16 — це апаратно-оптимізоване 16-бітне артикуляційне біт-векторне представлення для 
фонем. На відміну від пласких 8-бітних послідовних наборів символів, PVC-16 кодує 
фонетичні ознаки (Стхана, Праятна, Свара, Модифікатори) безпосередньо у специфічні бітові позиції.

## Розташування бітів
```
 15  14  13  12 │ 11  10   9   8 │  7   6   5   4 │  3   2   1   0
┌───┬───┬───┬───┼───┬───┬───┬───┼───┬───┬───┬───┼───┬───┬───┬───┐
│Mod│Acc│Len│Len│Gh │Mh │Sp │Asp│Ka │Ta │Mu │Da │Os │Na │Pl │Vow│
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
```

## Апаратні можливості за один такт (Single-Cycle)
1. **Сутра 1.1.9 (`tulyāsyaprayatnaṁ savarṇam`):** Обчислюється за 1 такт за допомогою 
   простої комбінаційної логіки (`is_savarna`).
2. **Одзвінчення / Оглушення (Voicing / Devoicing):** `sound ^ GHOSHA_MASK` за 1 такт.
3. **Синтез:** Потребує менше 8 FPGA LUT для повного порівняння Саварна.

## Запуск тестів у Guix
```bash
guix shell --pure -m manifest.scm -- python3 -m unittest test_pvc16.py
guix shell --pure -m manifest.scm -- iverilog -o pvc16_sim pvc16.v pvc16_tb.v && vvp pvc16_sim
```
