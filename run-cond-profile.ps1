<#
.SYNOPSIS
    Profile and analyze COND dispatch compilation on SBCL and CCL.

.DESCRIPTION
    Runs disassembly and performance analysis on both implementations,
    highlighting compilation strategy differences.
#>

param(
    [switch]$Verbose,
    [switch]$SaveOutput
)

$ErrorActionPreference = 'Stop'

# Paths
$sbcl_exe = "sbcl"
$ccl_exe = "C:\Users\frank\AppData\Local\Programs\ccl\ccl\wx86cl64.exe"
$profile_script = "C:\Users\frank\Projects\FOL\fol\profile-cond-dispatch.lisp"

function Run-Profile {
    param(
        [string]$Lisp,
        [string]$ExePath
    )

    Write-Host "`n>>> Profiling $Lisp..." -ForegroundColor Cyan

    try {
        if ($Lisp -eq 'SBCL') {
            & $ExePath --noinform --non-interactive --load $profile_script 2>&1
        } else {
            & $ExePath -l $profile_script 2>&1
        }
    } catch {
        Write-Host "ERROR: Failed to run profile on $Lisp" -ForegroundColor Red
        Write-Host $_ -ForegroundColor Red
    }
}

# Main execution
Write-Host "=== COND Dispatch Compilation Profile ===" -ForegroundColor Cyan
Write-Host "Profile script: $profile_script`n"

# Verify installations
Write-Host "Verifying Lisp implementations..." -ForegroundColor Yellow

$sbcl_ok = try { & $sbcl_exe --version 2>&1 | Out-Null; $true } catch { $false }
if ($sbcl_ok) {
    Write-Host "  ✓ SBCL available" -ForegroundColor Green
} else {
    Write-Host "  ✗ SBCL not available" -ForegroundColor Red
}

$ccl_ok = try { & $ccl_exe -V 2>&1 | Out-Null; $true } catch { $false }
if ($ccl_ok) {
    Write-Host "  ✓ CCL available" -ForegroundColor Green
} else {
    Write-Host "  ✗ CCL not available" -ForegroundColor Red
}

if (-not ($sbcl_ok -and $ccl_ok)) {
    Write-Host "`nERROR: Not all Lisp implementations available" -ForegroundColor Red
    exit 1
}

# Run profiles
if ($sbcl_ok) {
    Write-Host "`n" + ("="*60) -ForegroundColor Cyan
    Run-Profile -Lisp 'SBCL' -ExePath $sbcl_exe
}

if ($ccl_ok) {
    Write-Host "`n" + ("="*60) -ForegroundColor Cyan
    Run-Profile -Lisp 'CCL' -ExePath $ccl_exe
}

Write-Host "`n" + ("="*60) -ForegroundColor Cyan
Write-Host "Profile Analysis Complete" -ForegroundColor Green
Write-Host "`nKey Observations:" -ForegroundColor Yellow
Write-Host "  • SBCL: Look for tight x86-64 instruction sequences with CMP/JCC" -ForegroundColor Gray
Write-Host "  • CCL: May show different register allocation or call patterns" -ForegroundColor Gray
Write-Host "  • Compare per-call overhead across implementations" -ForegroundColor Gray
Write-Host "  • Note differences in branch prediction strategies" -ForegroundColor Gray
