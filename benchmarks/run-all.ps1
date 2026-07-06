# Run all aggregate scalar replacement (ASR) benchmarks.
#
# Delegates to run-asr-bench.ps1, which runs the SBCL driver over every
# benchmark registered in run-asr-bench.lisp: particle, rotation, ballistic,
# two-body, mandelbrot, kalman, biquad, co-moments, and lorenz.
#
# To add another benchmark, drop an asr-*.fol into fol-code/, then add a native
# baseline and a (bench ...) call to run-asr-bench.lisp's MAIN; it will run here
# automatically.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "Running all ASR benchmarks..." -ForegroundColor Cyan
& (Join-Path $ScriptDir "run-asr-bench.ps1")
Write-Host "All benchmarks complete." -ForegroundColor Green
