# Main runner script for all benchmarks

Write-Host "Running all ASR benchmarks..."

.\run-asr-bench.ps1 "mandelbrot" "mandelbrot.fol" "run-mandelbrot-base" "run-mandelbrot-asr" 1
.\run-asr-bench.ps1 "kalman" "kalman.fol" "run-kalman-filter-base" "run-kalman-filter-asr" 5000000
.\run-asr-bench.ps1 "biquad" "biquad.fol" "run-biquad-filter-base" "run-biquad-filter-asr" 10000000
.\run-asr-bench.ps1 "comoments" "comoments.fol" "run-co-moments-base" "run-co-moments-asr" 10000000

# Existing physics benchmarks
.\run-asr-bench.ps1 "particle" "particle.fol" "run-particle-base" "run-particle-asr" 5000000
.\run-asr-bench.ps1 "rotation" "rotation.fol" "run-rotation-base" "run-rotation-asr" 5000000
.\run-asr-bench.ps1 "ballistic" "ballistic.fol" "run-ballistic-base" "run-ballistic-asr" 5000000
.\run-asr-bench.ps1 "twobody" "twobody.fol" "run-two-body-base" "run-two-body-asr" 5000000
..\run-asr-bench.ps1 "lorenz" "lorenz.fol" "run-lorenz-base" "run-lorenz-asr" 5000000

Write-Host "All benchmarks complete."