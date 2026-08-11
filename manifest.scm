;; guix shell -m manifest.scm
;; Toolchain for fpga-lisp: SystemVerilog simulation/synthesis plus the
;; Python/Rust tooling used by the assembler and bootstrap demos.
(specifications->manifest
 '("iverilog"
   "verilator"
   "yosys"
   "python"
   "rust"
   "rust:cargo"
   "nss-certs"
   "git"))
