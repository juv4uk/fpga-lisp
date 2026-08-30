# FPGA GC Design — Trace-Based Mark-and-Sweep

Status: design document, not implemented. Depends on nothing; blocks
`FPGA-EXTERNAL-MEMORY-SDRAM` (needs GC root-set/sweep design before
extending heap across BRAM + external memory tiers).

## 1. Why Not Reference Counting

`SETCDR` (bootstrap-only, `lisp_data_unit.sv:119-133`) lets a closure
backpatch its own environment link for `letrec`-style self-reference.
This creates **real reference cycles**: closure A captures env → env
references A's binding → A's CDR points back into env. Reference
counting never collects cycles. Mark-and-sweep does.

## 2. Current Heap Model

```
HEAP_ADDR_WIDTH = 12 → 4096 cons cells
BRAM cost: 24/56 blocks (43%) including imem
Allocator: bump only (hp++), no free
```

`heap.sv`: dual-port CAR/CDR BRAMs, independent write enables per
field (enables in-place SETCDR without touching CAR).
`lisp_data_unit.sv`: `hp` register, bump on CONS, no reclaim path.

## 3. Root Set

The GC must find every reachable cons cell. Roots live in:

| Root source | Location | Width | Notes |
|---|---|---|---|
| Stack frames | `lisp_data_unit.sv` | up to `STACK_DEPTH` | Each frame holds saved env + continuation |
| Environment | `lisp_data_unit.sv` | variable depth | Chain of frames, each frame is a cons list |
| Accumulator (result) | `lisp_data_unit.sv` | 1 word | Current working value |
| Registers | `registers.sv` | 16 words | R0–R15, some may hold CONS pointers |
| Bootloader globals | `bootloader.sv` | fixed | Boot-time root definitions |

A dedicated `root_scan` FSM enumerates all roots and pushes their
cons-cell addresses (extracted from TAG_CONS values) into a small
**mark stack** (BRAM, 128–256 entries — see §6).

## 4. Mark Phase

### Algorithm
```
mark_stack = roots (from root_scan)
while mark_stack not empty:
    cell = pop(mark_stack)
    if cell is marked: continue
    mark(cell)
    push(car(cell) if TAG_CONS)
    push(cdr(cell) if TAG_CONS)
```

### Hardware Shape

- **Mark bitmap**: 4096 bits = 128 BRAM blocks × 36-bit = ~512
  bytes. One bit per cons cell. Stored in a dedicated BRAM block
  (or packed into existing imem space if available).
- **Mark FSM**: idle → root_scan → mark → sweep → idle. Runs on
  clock domain, stalls CPU via `gc_stall` signal during mark+sweep.
- **Mark stack depth**: 128 entries is sufficient for balanced trees;
  for deeply unbalanced lists (worst case 4096-deep), the mark stack
  spills to a small dedicated BRAM "overflow" region (same BRAM
  budget, just a second port on the mark bitmap BRAM).

### Timing

Mark phase walks the heap graph. Worst case: 4096 cells visited,
each visit = 1 cycle (read CAR + CDR in parallel from dual-port
BRAM). Worst-case mark time: ~4096 cycles. At 48 MHz: ~85 µs.
Acceptable for a stop-the-world GC on an embedded Lisp.

## 5. Sweep Phase

After mark completes, sweep reclaims unmarked cells.

### Free List Approach

Walk cell 0..4095:
```
if !marked(i):
    append i to free_list
clear marked bit
```

**Free list head** stored in a register (12-bit address). CONS
becomes: pop from free_list if available, else bump `hp` (same as
today when free list is empty).

### CONS Modified

```
if free_list non-empty:
    cell = pop(free_list)
    write CAR, CDR to cell
    return cell
else:
    cell = hp
    hp++
    write CAR, CDR to cell
    return cell
```

This is **backward compatible**: when free list is empty, behavior
is identical to current bump allocator. No existing code breaks.

## 6. BRAM Budget

| Component | BRAM blocks | Notes |
|---|---|---|
| CAR BRAM | 12 | 4096 × 28-bit |
| CDR BRAM | 12 | 4096 × 28-bit |
| imem | varies | Program storage |
| Mark bitmap | 2 | 4096 bits packed into 2 × 36×9 = 648 bytes (fits 2 blocks) |
| Mark stack | 1 | 256 × 12-bit = 384 bytes (1 block) |
| Free list | 0 | Head is a register; list is implicit in bitmap |
| **Total GC overhead** | **3** | Mark bitmap + mark stack |

Current total: 24/56 (43%). GC adds 3 blocks → 27/56 (48%). Leaves
29 blocks for future growth.

## 7. Trigger Strategy

### When to Collect

Collect when CONS would fail (hp == HEAP_MAX):

```
gc_trigger = (hp == HEAP_MAX - 1)
```

This is a stop-the-world collector: CPU stalls, GC runs, CPU
resumes. No incremental or concurrent collection — too complex for
4096 cells.

### GC Entry Protocol

1. CPU detects `gc_trigger`
2. CPU asserts `gc_start`, enters `ST_GC` state
3. Root scan FSM runs (stalls CPU, ~N cycles for N roots)
4. Mark phase runs (~4096 cycles worst case)
5. Sweep phase runs (~4096 cycles worst case)
6. CPU deasserts `gc_start`, resumes
7. CONS now succeeds (free list populated)

## 8. Overflow to External Memory

When external memory is added (FPGA-EXTERNAL-MEMORY-SDRAM), the
generational split becomes:

- **Young generation** (BRAM): fast, small, bump-allocated
- **Old generation** (external): overflow capacity

GC promotes surviving young cells to old generation after N
collections. Old generation uses same mark-and-sweep but walks
external memory via SDRAM controller. Root set extends to include
old→young pointers (tracked via a remembered set, ~128 entries in
BRAM).

**This is future work.** The current design intentionally uses a
single-generation mark-and-sweep that works identically on BRAM
only. Extending to two tiers is a separate, smaller step after
the single-tier design is proven.

## 9. Integration Points

### RTL Changes Required

1. `lisp_data_unit.sv`: Add `gc_start`, `gc_done`, `gc_stall`
   signals. CONS checks free list before bump.
2. `heap.sv`: Add read port for mark bitmap access (or separate
   mark bitmap module).
3. New module `gc_unit.sv`: Root scan FSM, mark FSM, sweep FSM,
   mark bitmap BRAM, mark stack BRAM.
4. `control.sv`: Add `ST_GC` state, route `gc_trigger` from LDU.

### Lisp-Level Changes

None. GC is invisible to Lisp code. The only observable effect is a
pause during collection. No finalizers, no weak references, no
user-visible GC hooks — this is a minimal embedded system.

## 10. Testing Strategy

1. **Mark correctness**: Write programs that allocate N cells, drop
   references to some, trigger GC, verify reclaimed count matches
   expectations.
2. **Cycle collection**: `letrec` closure that references itself →
   mark-and-sweep collects it; reference counting would not.
3. **Root set completeness**: Programs using all stack depths,
   register file, nested environments — verify no live cells are
   incorrectly swept.
4. **Free list correctness**: Allocate → GC → allocate again →
   verify reuses freed cells before bump.
5. **Backward compatibility**: All existing testbenches pass
   unchanged (GC trigger never fires until heap is full).

## 11. Non-Goals

- Incremental/concurrent collection (too complex for 4096 cells)
- Generational collection (future, after external memory)
- Compaction/defragmentation (not needed; free list handles it)
- User-facing GC hooks or finalizers
- Performance optimization before correctness is proven

---

# Дизайн збирача сміття (GC) для FPGA — Trace-Based Mark-and-Sweep (Ukrainian)

**Статус:** документ проєктування, не реалізовано. Ні від чого не залежить; 
блокує `FPGA-EXTERNAL-MEMORY-SDRAM` (оскільки перед розширенням купи на BRAM + 
зовнішню пам'ять потрібен дизайн кореневої множини/збирання сміття).

## 1. Чому не підрахунок посилань (Reference Counting)
`SETCDR` дозволяє замиканню змінювати власне посилання на середовище (для 
самопосилань у стилі `letrec`). Це створює **справжні циклічні посилання**. 
Підрахунок посилань ніколи не збирає цикли. Алгоритм Mark-and-sweep — збирає.

## 2. Поточна модель купи (Heap)
Купа містить 4096 комірок cons (12-бітна адреса). Використовує двопортову 
BRAM для незалежного доступу до CAR/CDR. Алокатор наразі лише збільшує 
вказівник (`hp++`), без можливості звільнення.

## 3. Коренева множина (Root Set)
GC повинен знайти всі досяжні комірки cons. Корені знаходяться у:
- Фреймах стека (включаючи збережене середовище + продовження).
- Поточному середовищі (ланцюг фреймів).
- Акумуляторі (робоче значення).
- Регістрах (R0–R15).
- Глобальних змінних завантажувача.

Виділений автомат (FSM) `root_scan` перебирає всі корені і пушить їхні 
адреси (витягнуті з `TAG_CONS`) у невеликий **стек позначок** (mark stack) 
у BRAM.

## 4. Фаза позначення (Mark Phase)
Алгоритм стандартний: беремо комірку зі стека, якщо непозначена — позначаємо, 
пушимо її CAR та CDR (якщо це `TAG_CONS`).
- **Бітмап позначок:** 4096 біт = ~512 байтів (поміщається у 2 блоки BRAM).
- **Стек позначок:** 128 записів (1 блок BRAM), достатньо для збалансованих дерев.
- **Час виконання:** У найгіршому випадку ~4096 тактів (близько 85 мкс на 48 МГц), 
  що прийнятно для GC із зупинкою світу (stop-the-world).

## 5. Фаза очищення (Sweep Phase)
Після позначення система проходить усі комірки від 0 до 4095. Якщо комірка 
не позначена, вона додається до **списку вільних комірок** (free list). 
Операція `CONS` спочатку намагається взяти комірку з `free_list`, і лише якщо 
він порожній — збільшує `hp`. Це гарантує зворотну сумісність із поточним кодом.

## 6. Бюджет BRAM
GC додає лише **3 блоки BRAM** (2 для бітмапа, 1 для стека позначок). 
Загальне використання зросте з 24 до 27 блоків із 56 доступних, залишаючи 
простір для розширення.

## 7. Стратегія запуску
GC запускається (stop-the-world), коли `CONS` ось-ось провалиться 
(`hp == HEAP_MAX - 1`). Процесор зупиняється (`gc_stall`), проходить 
сканування коренів, позначення та очищення, після чого відновлює роботу, 
а `CONS` успішно бере комірку з вільного списку.

## 8. Розширення на зовнішню пам'ять (Future Work)
Коли буде додано зовнішню пам'ять (SDRAM), архітектура стане генераційною:
- **Молоде покоління** (BRAM): швидке, мале, bump-алокація.
- **Старе покоління** (зовнішня пам'ять): переповнення, збирається тим 
  самим алгоритмом Mark-and-sweep.

Наразі це **майбутня робота**. Поточний дизайн спеціально орієнтований на 
одне покоління (лише BRAM) для спрощення перевірки.

## 9. Інтеграція
Зміни стосуватимуться RTL (`lisp_data_unit.sv`, `heap.sv`, новий `gc_unit.sv` 
та `control.sv`). **Зміни на рівні Lisp відсутні:** GC повністю прозорий для 
коду користувача, немає ніяких хуків чи фіналізаторів.

## 10. Стратегія тестування
- Перевірка коректності позначення та очищення.
- Перевірка збирання циклів (самопосилання через `letrec`).
- Повнота кореневої множини.
- Коректність використання списку вільних комірок.
- Зворотна сумісність існуючих тестбенчів.
