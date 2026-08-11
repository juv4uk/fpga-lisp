# ISA contract · Контракт ISA · ISA-Vertrag

## English

[`isa-contract.my`](../isa-contract.my) is the machine-readable boundary owned by `fpga-lisp`. It records what assemblers and compilers may rely on without depending on RTL layout or a repository release number. Version `1.0` makes `JF` conform to my-lisp's G8 axiom: only `NIL` is falsy, while fixnum `0` is truthy. This is a major version because it changes the control flow of an existing valid instruction sequence.

A major version changes the meaning of an existing valid image or calling sequence. A minor version adds a backward-compatible tag, instruction mode, primitive ID, or capability. Refactoring RTL, changing synthesis constraints, or optimizing the heap without observable ISA change does not bump it.

The 16 physical opcodes are not the whole interface. `GETTAG`, `MAKEPRIM`, and `GETVAL` are modes of `MOV`; `CALL` and `RET` are modes of `JMP`; bootstrap-only `SETCDR` is a mode of `ATOM`. These encoded modes, the tagged-word layout, register convention, primitive IDs, and little-endian program image are therefore contractual too.

`cml` should consume or validate this manifest and publish the exact ISA version plus tested fpga-lisp SHA in its own `compatibility.my`. The manifest describes the machine; it does not claim full my-lisp language conformance.

**G8 truth contract**: the hardware `JF` opcode (`fpga/rtl/control.sv`'s `OP_JF` branch) jumps only when its operand has `TAG_NIL`. [`tb_jf_truthiness.sv`](../fpga/sim/tb_jf_truthiness.sv) proves both required cases through the bootloader and RTL: fixnum `0` falls through and `NIL` branches.

## Українська

[`isa-contract.my`](../isa-contract.my) — машинно-читана межа, якою володіє `fpga-lisp`. Вона фіксує, на що можуть покладатися assembler і compiler без залежності від внутрішнього RTL layout чи номера релізу репозиторію. Версія `1.0` узгоджує `JF` з аксіомою G8 мови my-lisp: лише `NIL` є falsy, а fixnum `0` є truthy. Це major-версія, бо вона змінює control flow раніше валідної послідовності інструкцій.

Major-версія змінює значення раніше валідного image або calling sequence. Minor додає сумісний tag, instruction mode, primitive ID чи capability. Рефакторинг RTL, зміна synthesis constraints або оптимізація heap без спостережуваної зміни ISA версію не піднімає.

Шістнадцять фізичних opcode — не весь interface. `GETTAG`, `MAKEPRIM` і `GETVAL` є режимами `MOV`; `CALL` і `RET` — режимами `JMP`; внутрішній bootstrap `SETCDR` — режимом `ATOM`. Тому encoded modes, tagged-word layout, register convention, primitive IDs і little-endian program image також є контрактом.

`cml` має читати або валідувати цей manifest і публікувати точну версію ISA та перевірений SHA fpga-lisp у власному `compatibility.my`. Manifest описує машину, але не заявляє повну conformance мові my-lisp.

**G8-контракт істинності**: апаратний опкод `JF` (`fpga/rtl/control.sv`, гілка `OP_JF`) переходить лише тоді, коли операнд має `TAG_NIL`. [`tb_jf_truthiness.sv`](../fpga/sim/tb_jf_truthiness.sv) через bootloader і RTL доводить обидва обов'язкові випадки: fixnum `0` не виконує перехід, а `NIL` виконує.

## Deutsch

[`isa-contract.my`](../isa-contract.my) ist die maschinenlesbare, von `fpga-lisp` verantwortete Grenze. Sie hält fest, worauf Assembler und Compiler bauen dürfen, ohne von internem RTL-Layout oder einer Repository-Releaseversion abzuhängen. Version `1.0` bringt `JF` mit my-lisps G8-Axiom in Einklang: Nur `NIL` ist falsy, Fixnum `0` ist truthy. Dies ist eine Major-Version, weil sie den Kontrollfluss einer zuvor gültigen Instruktionsfolge ändert.

Eine Major-Version ändert die Bedeutung eines zuvor gültigen Images oder einer Aufrufsequenz. Eine Minor-Version ergänzt kompatibel ein Tag, einen Instruktionsmodus, eine Primitive-ID oder Fähigkeit. RTL-Refactoring, geänderte Synthese-Constraints oder Heap-Optimierung ohne beobachtbare ISA-Änderung erhöhen sie nicht.

Die 16 physischen Opcodes sind nicht die gesamte Schnittstelle. `GETTAG`, `MAKEPRIM` und `GETVAL` sind Modi von `MOV`; `CALL` und `RET` sind Modi von `JMP`; das interne Bootstrap-`SETCDR` ist ein Modus von `ATOM`. Daher gehören auch diese Modi, Tagged-Word-Layout, Registerkonvention, Primitive-IDs und Little-Endian-Program-Image zum Vertrag.

`cml` sollte dieses Manifest lesen oder validieren und die genaue ISA-Version samt geprüftem fpga-lisp-SHA in seinem `compatibility.my` veröffentlichen. Das Manifest beschreibt die Maschine; es behauptet keine vollständige my-lisp-Sprachkonformität.

**G8-Wahrheitsvertrag**: Der Hardware-Opcode `JF` (`fpga/rtl/control.sv`, `OP_JF`-Zweig) springt nur bei einem Operanden mit `TAG_NIL`. [`tb_jf_truthiness.sv`](../fpga/sim/tb_jf_truthiness.sv) beweist beide erforderlichen Fälle durch Bootloader und RTL: Fixnum `0` fällt durch, `NIL` verzweigt.
