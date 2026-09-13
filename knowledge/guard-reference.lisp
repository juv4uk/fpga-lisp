; Guard reference bureau / Довідкове бюро Guard
;
; Одна тема вказує на авторитетні джерела, штатний workflow і докази
; завершення. Це навігаційне знання, а не копія контрактів. Шляхи відносні до
; репозиторію, якщо не починаються з ../.
;
; One topic points to authoritative sources, the canonical workflow, and the
; evidence that proves completion. This is navigation knowledge, not a copy of
; those contracts. Paths are repository-relative unless prefixed with ../.

(def *guard-reference-directory*
  (quote
    ((reference
       (topic hardware-verification-workflow)
       (summary "Синтез (gw_sh.exe) і прошивка (programmer_cli.exe/UART) вимагають нативного Windows -- WSL2 не тягне termios для FTDI, а cmd.exe відмовляється від \\wsl.localhost\\ UNC-шляхів як cwd, хоча прямий виклик python.exe/gw_sh.exe через WSL interop їх приймає. UART-бутлоадер потребує реального фізичного натискання RESET -- жоден JTAG/UART-протокол не може це замінити (rst_n -- окремий зовнішній GPIO-пін H11, pull-up, monitor.py/upload.py не чекають ACK від плати після завантаження)")
       (authority (docs/hardware-setup.md docs/repl-design.md fpga/synth/build.tcl monitor.py upload.py fpga/rtl/lisp_machine.cst))
       (how-to (sync-windows-side-clone-via-git-pull-ff-only invoke-gw_sh-directly-not-through-cmd-exe-for-wsl-paths programmer_cli-scan-first-since-cable-index-varies-per-session sram-program-op2-before-permanent-exflash-op54 physically-press-reset-during-upload_program-3s-window))
       (verify (fmax-vs-50mhz-constraint-in-project_tr_content-html sha256-of-flashed-project-fs uart-register-readback-via-monitor-py))
       (lifecycle current-workflow)
       (provenance "empirically confirmed 2026-09-08 (Claude Sonnet 5): real synthesis (Fmax=60.316MHz), real JTAG SRAM program (User Code 0x00004DCB), and the RESET-button requirement discovered by direct 0-byte-timeout evidence after multiple failed non-interactive upload attempts")
       (unknown-route ask-owner))
     (reference
       (topic isa-contract)
       (summary "isa-contract.my -- машиночитаний ISA-контракт: теги (fixnum/cons/symbol/nil/true/primitive), опкоди, encoded-modes для MOV (gettag/makeprim/getval/upc8-*/sandhi). Версія 1.3 (ISA 1.0-1.3 сумісні образи). tag(true)=4 лишається в списку для байт-сумісності зі старими образами, але жодна жива RTL-логіка більше не продукує TAG_TRUE -- OP_ATOM/OP_EQ емітують TAG_SYMBOL+79 (SYM_T) з 2026-09-02")
       (authority (isa-contract.my fpga/rtl/lisp_word.sv fpga/rtl/control.sv fpga/asm/symbol-table.inc))
       (how-to (read-tags-list-before-touching-word-encoding check-encoded-modes-for-mov-rs2-dispatch cross-check-against-my-lisp-crates-my-lisp-src-value-rs-for-canonical-semantics))
       (verify (fpga-sim-tb_atom_eq fpga-sim-tb_eval_all_primitives))
       (lifecycle current-contract)
       (provenance "isa-contract.my version (1 3); TAG_TRUE removal documented in tasks.my's FPGA-TAG-TRUE-MANUFACTURED-PRIMITIVE entry, 2026-09-02 and re-verified 2026-09-08")
       (unknown-route ask-agent))
     (reference
       (topic testbench-regression)
       (summary "fpga/sim/*.sv + fpga/tb/tb_fetch_pair.sv -- 35+ testbenches, compiled/run via iverilog -g2012. Два РІЗНІ класи відомих hang: (1) старий, pre-existing до 2026-09-02: tb_bootstrap_append/equal/length/length_onto -- підтверджено git-stash-порівнянням, не регресія. (2) новий, введений 26d3be3 (sandhi_engine integration, 2026-09-06): tb_eval_atom/quote/cond/apply/primitive/all_primitives -- ЧАСТКОВО виправлено комітом c85ee1f (2026-09-08, gettag/makeprim/getval next_state); tb_eval_cond досі дає НЕПРАВИЛЬНИЙ результат (не зависає, halts, але R9=NIL замість очікуваного символу 82) -- окремий, ще не закритий баг у логіці cond")
       (authority (.github/workflows/ci.yml fpga/sim/tb_eval_cond.sv))
       (how-to (compile-with-full-file-list-including-upc8_unit-and-sandhi_engine run-vvp-with-generous-timeout-70s-plus-for-longer-eval-tests distinguish-watchdog-hang-from-wrong-result-halt))
       (verify (gh-run-list-conclusion direct-local-iverilog-reproduction))
       (lifecycle open-investigation)
       (provenance "bisected empirically 2026-09-08 (Claude Sonnet 5, cross-verified with viveka via agents-live-bus): built RTL at 3 exact git states (pre-9d978fa, at 9d978fa, at 26d3be3) to isolate the exact commit; c85ee1f confirmed fixing 5/6 eval_* testbenches, tb_eval_cond remains open")
       (unknown-route ask-agent))
     (reference
       (topic wsm-x86-p0-conformance)
       (summary "FPGA-WSM-FULL-P0-CONFORMANCE (tasks.my, priority 8.8) просить заморозити admitted-профіль fpga-lisp проти WSM-X86-P0 (../wsm-os-lisp/target-profile.wsm). Знайдена, ще не вирішена розбіжність: my-lisp Rust + fpga-lisp RTL (обидва, 2026-09-02) узгодились, що true = Symbol(\"t\"), без окремого тега; WSM-X86-P0's власний crates/wsm-os-target ABI (../wsm-os-lisp/docs/TARGET-ABI.md) тримає true як окремий тег (010), відмінний від symbol (100). Питання надіслано vyasa (COMPILER STEWARD), відповіді ще нема")
       (authority (../wsm-os-lisp/target-profile.wsm ../wsm-os-lisp/docs/TARGET-ABI.md ../my-lisp/crates/my-lisp/src/value.rs docs/reference/conformance.my))
       (how-to (filter-conformance-my-for-tier-1-role-constitutive-fixtures exclude-lambda-closure-string-fixtures-per-p0-exclusion-list cross-reference-against-existing-fpga-testbench-evidence))
       (verify (docs-reference-conformance-my fpga-sim-testbench-pass-fail))
       (lifecycle blocked-pending-owner-or-steward-decision)
       (provenance "discovered and reported 2026-09-08 (Claude Sonnet 5): source-verified in my-lisp commit a0c9b62's own commit message, fpga-lisp commit d3433ee, and wsm-os-lisp's TARGET-ABI.md directly, not assumed")
       (unknown-route ask-owner))
     (reference
       (topic swarm-coordination)
       (summary "Активне листування через ../ecosystem/scripts/bus-post (широкомовна шина agents-live-bus) і ../ecosystem/scripts/agent-send (пряме повідомлення конкретному агенту, durable inbox + wakeup). Спільний стан -- ../ecosystem/ecosystem-state-data.my (single-writer, зараз viveka), читати перед тим як припускати ізоляцію")
       (authority (../ecosystem/scripts/bus-post ../ecosystem/scripts/agent-send ../ecosystem/scripts/agent-inbox ../ecosystem/comms-log.md ../ecosystem/ecosystem-state-data.my ../ecosystem/docs/ECOSYSTEM-STATE-BLACKBOARD-2026-09-02.md))
       (how-to (post-progress-continuously-not-only-at-task-boundaries check-comms-log-and-blackboard-before-starting-solo-investigation ask-for-help-by-name-not-just-broadcast-status verify-colleague-claims-directly-not-blindly))
       (verify (comms-log-md-admitted-entries ecosystem-state-data-my-oracle-check))
       (lifecycle current-practice)
       (provenance "owner correction 2026-09-08, repeated multiple times in one session: correspondence must be continuous through a multi-step investigation, not bookended at start/end -- see ../ecosystem memory continuous-active-correspondence-during-solo-work.md")
       (unknown-route ask-owner)))))
