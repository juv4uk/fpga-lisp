# Copies the locally built my-lisp.exe (Rust host REPL/interpreter) from a
# sibling my-lisp checkout into this project's root, so it's on hand for
# quick cross-checks against fpga-lisp's bootstrap functions (see
# docs/lisp-machine-plan.md's M19+ bootstrap series) without a separate
# `cargo build --release` step each time.
#
# my-lisp.exe itself is gitignored (build artifact, rebuild from source in
# the my-lisp repo) -- this script just refreshes the local copy.

param(
    [string]$MyLispRepo = "C:\Users\juv4u\Documents\my-lisp"
)

$src = Join-Path $MyLispRepo "target\release\my-lisp.exe"
$dst = Join-Path $PSScriptRoot "my-lisp.exe"

if (-not (Test-Path $src)) {
    Write-Error "my-lisp.exe not found at $src -- run 'cargo build --release' in $MyLispRepo first."
    exit 1
}

Copy-Item -Path $src -Destination $dst -Force
Write-Output "Synced $src -> $dst"
& $dst --version
