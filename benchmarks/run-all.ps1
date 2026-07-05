# Run all aggregate scalar replacement (ASR) benchmarks.
#
# Delegates to run-asr-bench.ps1, which runs the SBCL driver over every
# benchmark registered in run-asr-bench.lisp (currently particle, rotation,
# ballistic, two-body).
#
# To add a benchmark -- e.g. the planned real-world kernels lorenz, mandelbrot,
# kalman, biquad, co-moments -- drop an asr-*.fol into fol-code/, then add a
# native baseline and a (bench ...) call to run-asr-bench.lisp's MAIN; it will
# run here automatically.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "Running all ASR benchmarks..." -ForegroundColor Cyan
& (Join-Path $ScriptDir "run-asr-bench.ps1")
Write-Host "All benchmarks complete." -ForegroundColor Green
