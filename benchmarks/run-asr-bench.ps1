# Run the aggregate scalar replacement (ASR) benchmark suite.
#
# Thin wrapper around the SBCL driver benchmarks/run-asr-bench.lisp, which is the
# real harness: it compiles each benchmark with *scalar-replacement* off and on,
# runs five trials, and reports wall time, per-iteration allocation, GC stats,
# speedup, and a native mutable-defstruct ceiling. Benchmarks are registered in
# that driver's MAIN.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Driver = Join-Path $ScriptDir "run-asr-bench.lisp"

if (-not (Get-Command sbcl -ErrorAction SilentlyContinue)) {
    Write-Error "sbcl not found on PATH."
    exit 1
}

sbcl --noinform --non-interactive --load $Driver
