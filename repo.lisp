; repo.my — Swarm Contract v0.1 scope declaration for fpga-lisp.
; See my-lisp/docs/swarm-mesh-v2.md for the full spec. Format confirmed
; by example against my-lisp-panini/repo.my (per
; shiva-sutras/docs/cross-repo-ecosystem-findings-2026-08-18.md's
; scope-check on this same task, SHIVA-SWARM-CONTRACT-01).
;
; A declaration of scope, not an authorization grant -- authorities/
; non-authorities state what this repo is and is not the source of
; truth for, so other repos' agents don't have to re-derive it.

(repository
  (id fpga-lisp)
  (role hardware-backend)
  (exports isa-contract fetch-pair-rtl bootstrap-milestones evidence)
  (imports language-contract compatibility)
  (capabilities verilog isa-design fpga iverilog assembly-testing fpga-lisp)
  (authorities fpga-isa hardware-implementation rtl-verification)
  (non-authorities language-semantics sanskrit-ontology shiva-canon compiler-middle-end))
