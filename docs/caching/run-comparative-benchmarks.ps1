<#
.SYNOPSIS
    Run dispatch caching benchmarks on both SBCL and CCL, comparing results.

.DESCRIPTION
    Executes the same benchmarks on both Common Lisp implementations and produces
    a comparative analysis of dispatch overhead.
#>

param(
    [ValidateSet('hetero', 'homo', 'method', 'all')]
    [string]$Benchmark = 'all',

    [int]$Iterations = 3,
    [switch]$ShowAssembly,
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Paths
$sbcl_exe = "sbcl"
$ccl_exe = "C:\Users\frank\AppData\Local\Programs\ccl\ccl\wx86cl64.exe"
$benchmark_dir = "C:\Users\frank\Projects\FOL\fol"

# Benchmark specifications
$benchmarks = @{
    'hetero' = @{
        'sbcl'   = 'hetero-micro-bench.lisp'
        'ccl'    = 'hetero-micro-bench-ccl.lisp'
        'label'  = 'Heterogeneous Types (5-Type Cycle)'
    }
    'homo' = @{
        'sbcl'   = 'simple-micro-bench.lisp'
        'ccl'    = 'simple-micro-bench-ccl.lisp'
        'label'  = 'Homogeneous Types (Fixnum Only)'
    }
    'method' = @{
        'sbcl'   = 'method-dispatch-bench.lisp'
        'ccl'    = 'method-dispatch-bench-ccl.lisp'
        'label'  = 'Generic Function Dispatch'
    }
}

function Test-Executable {
    param([string]$exe)

    try {
        if ($exe -eq 'sbcl') {
            $result = & $exe --version 2>&1
            return $result -match 'SBCL'
        } else {
            $result = & $exe -V 2>&1
            return $result -match 'Clozure'
        }
    } catch {
        return $false
    }
}

function Run-Benchmark {
    param(
        [string]$Lisp,
        [string]$ExePath,
        [string]$Script,
        [string]$Label
    )

    $script_path = Join-Path $benchmark_dir $Script

    if (-not (Test-Path $script_path)) {
        Write-Host "ERROR: Benchmark script not found: $script_path" -ForegroundColor Red
        return $null
    }

    Write-Host "`n>>> Running $Label on $Lisp..." -ForegroundColor Cyan
    Write-Host "    Script: $Script"
    Write-Host "    Iterations: $Iterations"

    $output_file = "$env:TEMP\bench-$Lisp-$(Get-Random).log"

    try {
        if ($Lisp -eq 'SBCL') {
            & $ExePath --noinform --non-interactive --load $script_path 2>&1 | Tee-Object -FilePath $output_file
        } else {
            & $ExePath -l $script_path 2>&1 | Tee-Object -FilePath $output_file
        }

        return $output_file
    } catch {
        Write-Host "ERROR running benchmark: $_" -ForegroundColor Red
        return $null
    }
}

function Parse-BenchmarkOutput {
    param(
        [string]$OutputFile,
        [string]$Lisp
    )

    if (-not (Test-Path $OutputFile)) {
        return $null
    }

    $content = Get-Content $OutputFile -Raw

    $result = @{
        'Lisp' = $Lisp
        'UncachedTime' = $null
        'CachedTime' = $null
        'CacheHitRate' = $null
        'Speedup' = $null
    }

    # Extract timing information from 'Evaluation took:' lines
    $timings = @()
    $content -split "`n" | ForEach-Object {
        if ($_ -match 'Evaluation took:\s+([\d.]+) seconds') {
            $timings += [double]$matches[1]
        }
        if ($_ -match 'Hit rate:\s+([\d.]+)%') {
            $result['CacheHitRate'] = [double]$matches[1]
        }
    }

    if ($timings.Count -ge 3) {
        $result['UncachedTime'] = $timings[0]
        $result['CachedTime'] = $timings[3]
        $result['Speedup'] = $result['UncachedTime'] / $result['CachedTime']
    }

    return $result
}

function Compare-Results {
    param(
        [PSCustomObject]$SBCL,
        [PSCustomObject]$CCL,
        [string]$Label
    )

    Write-Host "`n=== Comparative Analysis: $Label ===" -ForegroundColor Green

    if ($null -eq $SBCL -or $null -eq $CCL) {
        Write-Host "Incomplete results, skipping comparison" -ForegroundColor Yellow
        return
    }

    $fmt = "{0,-20} {1,12} {2,12}"
    Write-Host ($fmt -f "Metric", "SBCL", "CCL")
    Write-Host ($fmt -f "-------", "----", "---")

    if ($SBCL['UncachedTime'] -and $CCL['UncachedTime']) {
        Write-Host ($fmt -f "Uncached (sec)", ("{0:F3}" -f $SBCL['UncachedTime']), ("{0:F3}" -f $CCL['UncachedTime']))
        $ratio = $CCL['UncachedTime'] / $SBCL['UncachedTime']
        Write-Host "  → CCL baseline: $("{0:F1}x" -f $ratio) vs SBCL" -ForegroundColor Gray
    }

    if ($SBCL['CachedTime'] -and $CCL['CachedTime']) {
        Write-Host ($fmt -f "Cached (sec)", ("{0:F3}" -f $SBCL['CachedTime']), ("{0:F3}" -f $CCL['CachedTime']))
        $ratio = $CCL['CachedTime'] / $SBCL['CachedTime']
        Write-Host "  → CCL cached: $("{0:F1}x" -f $ratio) vs SBCL" -ForegroundColor Gray
    }

    if ($SBCL['Speedup'] -and $CCL['Speedup']) {
        Write-Host ($fmt -f "Speedup", ("{0:F2}x" -f $SBCL['Speedup']), ("{0:F2}x" -f $CCL['Speedup']))
        if ($SBCL['Speedup'] -gt 1) {
            Write-Host "  ✓ SBCL: Caching HELPS" -ForegroundColor Green
        } else {
            Write-Host "  ✗ SBCL: Caching HURTS ($("{0:F2}x" -f (1/$SBCL['Speedup'])) slower)" -ForegroundColor Red
        }

        if ($CCL['Speedup'] -gt 1) {
            Write-Host "  ✓ CCL: Caching HELPS" -ForegroundColor Green
        } else {
            Write-Host "  ✗ CCL: Caching HURTS ($("{0:F2}x" -f (1/$CCL['Speedup'])) slower)" -ForegroundColor Red
        }
    }

    if ($SBCL['CacheHitRate'] -and $CCL['CacheHitRate']) {
        Write-Host ($fmt -f "Hit Rate", ("{0:F4}%" -f $SBCL['CacheHitRate']), ("{0:F4}%" -f $CCL['CacheHitRate']))
    }
}

# Main execution
Write-Host "=== Comparative Dispatch Caching Benchmarks ===" -ForegroundColor Cyan
Write-Host "SBCL: $sbcl_exe"
Write-Host "CCL:  $ccl_exe`n"

# Verify installations
Write-Host "Verifying Lisp implementations..." -ForegroundColor Yellow
if (-not (Test-Executable 'sbcl')) {
    Write-Host "ERROR: SBCL not found or not functional" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ SBCL found" -ForegroundColor Green

if (-not (Test-Executable $ccl_exe)) {
    Write-Host "ERROR: CCL not found or not functional" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ CCL found" -ForegroundColor Green

# Determine which benchmarks to run
$bench_list = @()
if ($Benchmark -eq 'all') {
    $bench_list = @('hetero', 'homo', 'method')
} else {
    $bench_list = @($Benchmark)
}

# Run benchmarks
$results = @{}

foreach ($bench_name in $bench_list) {
    if (-not $benchmarks.ContainsKey($bench_name)) {
        Write-Host "Unknown benchmark: $bench_name" -ForegroundColor Red
        continue
    }

    $bench = $benchmarks[$bench_name]
    $results[$bench_name] = @{}

    # Run on SBCL
    $sbcl_output = Run-Benchmark -Lisp 'SBCL' -ExePath $sbcl_exe `
                                 -Script $bench['sbcl'] `
                                 -Label $bench['label']
    if ($sbcl_output) {
        $results[$bench_name]['SBCL'] = Parse-BenchmarkOutput -OutputFile $sbcl_output -Lisp 'SBCL'
    }

    # Run on CCL
    $ccl_output = Run-Benchmark -Lisp 'CCL' -ExePath $ccl_exe `
                                -Script $bench['ccl'] `
                                -Label $bench['label']
    if ($ccl_output) {
        $results[$bench_name]['CCL'] = Parse-BenchmarkOutput -OutputFile $ccl_output -Lisp 'CCL'
    }

    # Compare
    Compare-Results -SBCL $results[$bench_name]['SBCL'] `
                    -CCL $results[$bench_name]['CCL'] `
                    -Label $bench['label']
}

Write-Host "`n=== Benchmark Complete ===" -ForegroundColor Cyan
