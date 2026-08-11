# ISA contract · Контракт ISA · ISA-Vertrag

## English

[`isa-contract.my`](../isa-contract.my) is the machine-readable boundary owned by `fpga-lisp`. It records what assemblers and compilers may rely on without depending on RTL layout or a repository release number. Version `0.2` adds the backward-compatible `R0` complete-argument-list convention used by variadic compiled lambdas.

A major version changes the meaning of an existing valid image or calling sequence. A minor version adds a backward-compatible tag, instruction mode, primitive ID, or capability. Refactoring RTL, changing synthesis constraints, or optimizing the heap without observable ISA change does not bump it.

The 16 physical opcodes are not the whole interface. `GETTAG`, `MAKEPRIM`, and `GETVAL` are modes of `MOV`; `CALL` and `RET` are modes of `JMP`; bootstrap-only `SETCDR` is a mode of `ATOM`. These encoded modes, the tagged-word layout, register convention, primitive IDs, and little-endian program image are therefore contractual too.

`cml` should consume or validate this manifest and publish the exact ISA version plus tested fpga-lisp SHA in its own `compatibility.my`. The manifest describes the machine; it does not claim full my-lisp language conformance.

**Known deviation from my-lisp's G8 axiom**: G8 says only `NIL` is falsy — fixnum `0` is truthy. The hardware `JF` opcode (`fpga/rtl/control.sv`'s `OP_JF` branch) instead treats `tag==NIL || (tag==FIXNUM && value==0)` as false (`isa-contract.my`'s `truth.jf-also-treats-zero-fixnum-as-false`). Any `cond`/`if` test that evaluates to fixnum `0` is branched on incorrectly relative to G8. Confirmed present as of `447ee0e` (2026-08-11), not yet fixed — a compiler targeting this ISA (`cml`) must account for it rather than assume G8 holds end to end.

## Українська

[`isa-contract.my`](../isa-contract.my) — машинно-читана межа, якою володіє `fpga-lisp`. Вона фіксує, на що можуть покладатися assembler і compiler без залежності від внутрішнього RTL layout чи номера релізу репозиторію. Версія `0.2` сумісно додає convention повного списку аргументів у `R0` для compiled variadic lambdas.

Major-версія змінює значення раніше валідного image або calling sequence. Minor додає сумісний tag, instruction mode, primitive ID чи capability. Рефакторинг RTL, зміна synthesis constraints або оптимізація heap без спостережуваної зміни ISA версію не піднімає.

Шістнадцять фізичних opcode — не весь interface. `GETTAG`, `MAKEPRIM` і `GETVAL` є режимами `MOV`; `CALL` і `RET` — режимами `JMP`; внутрішній bootstrap `SETCDR` — режимом `ATOM`. Тому encoded modes, tagged-word layout, register convention, primitive IDs і little-endian program image також є контрактом.

`cml` має читати або валідувати цей manifest і публікувати точну версію ISA та перевірений SHA fpga-lisp у власному `compatibility.my`. Manifest описує машину, але не заявляє повну conformance мові my-lisp.

**Відома розбіжність з G8-аксіомою my-lisp**: G8 каже, що лише `NIL` — falsy, fixnum `0` — truthy. Апаратний опкод `JF` (`fpga/rtl/control.sv`, гілка `OP_JF`) натомість трактує `tag==NIL || (tag==FIXNUM && value==0)` як false (`isa-contract.my`'s `truth.jf-also-treats-zero-fixnum-as-false`). Будь-який тест `cond`/`if`, що обчислюється в fixnum `0`, розгалужується неправильно відносно G8. Підтверджено станом на `447ee0e` (2026-08-11), ще не виправлено — компілятор для цього ISA (`cml`) має це врахувати, а не покладатись на те, що G8 виконується наскрізно.

## Deutsch

[`isa-contract.my`](../isa-contract.my) ist die maschinenlesbare, von `fpga-lisp` verantwortete Grenze. Sie hält fest, worauf Assembler und Compiler bauen dürfen, ohne von internem RTL-Layout oder einer Repository-Releaseversion abzuhängen. Version `0.2` ergänzt kompatibel die vollständige Argumentliste in `R0` für kompilierte variadische Lambdas.

Eine Major-Version ändert die Bedeutung eines zuvor gültigen Images oder einer Aufrufsequenz. Eine Minor-Version ergänzt kompatibel ein Tag, einen Instruktionsmodus, eine Primitive-ID oder Fähigkeit. RTL-Refactoring, geänderte Synthese-Constraints oder Heap-Optimierung ohne beobachtbare ISA-Änderung erhöhen sie nicht.

Die 16 physischen Opcodes sind nicht die gesamte Schnittstelle. `GETTAG`, `MAKEPRIM` und `GETVAL` sind Modi von `MOV`; `CALL` und `RET` sind Modi von `JMP`; das interne Bootstrap-`SETCDR` ist ein Modus von `ATOM`. Daher gehören auch diese Modi, Tagged-Word-Layout, Registerkonvention, Primitive-IDs und Little-Endian-Program-Image zum Vertrag.

`cml` sollte dieses Manifest lesen oder validieren und die genaue ISA-Version samt geprüftem fpga-lisp-SHA in seinem `compatibility.my` veröffentlichen. Das Manifest beschreibt die Maschine; es behauptet keine vollständige my-lisp-Sprachkonformität.

**Bekannte Abweichung von my-lisps G8-Axiom**: G8 besagt, nur `NIL` sei falsy — Fixnum `0` ist truthy. Der Hardware-Opcode `JF` (`fpga/rtl/control.sv`, `OP_JF`-Zweig) behandelt stattdessen `tag==NIL || (tag==FIXNUM && value==0)` als false (`isa-contract.my`'s `truth.jf-also-treats-zero-fixnum-as-false`). Jeder `cond`/`if`-Test, der zu Fixnum `0` auswertet, verzweigt entgegen G8 falsch. Bestätigt seit `447ee0e` (2026-08-11), noch nicht behoben — ein Compiler für dieses ISA (`cml`) muss dies berücksichtigen, statt durchgängige G8-Gültigkeit anzunehmen.
