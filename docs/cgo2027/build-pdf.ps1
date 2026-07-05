<#
.SYNOPSIS
    Compiles the OCG 2027 LaTeX paper using MiKTeX.
.DESCRIPTION
    Runs the standard LaTeX build sequence (PDFLaTeX -> BibTeX -> PDFLaTeX x2)
    to resolve citations and references for the OCG 2027 paper.
.PARAMETER FileName
    The name of the LaTeX file (without .tex extension) to compile. Defaults to "ocg2027".
#>

param(
    [string]$FileName = "cgo2027"
)

# --- Configuration ---
$project = $FileName
$miktexRoot = "C:\Users\frank\AppData\Local\Programs\MiKTeX"

# MiKTeX binaries are usually located in the \miktex\bin\x64 subdirectory of the install root
$miktexBin = Join-Path $miktexRoot "miktex\bin\x64"

# --- Setup Environment ---
if (-not (Test-Path $miktexBin)) {
    Write-Warning "Could not find standard binary folder at: $miktexBin"
    Write-Warning "Attempting to use root path provided..."
    $miktexBin = $miktexRoot
}

# Add MiKTeX to the current session path so we can call 'pdflatex'
$env:Path = "$miktexBin;$env:Path"

# Verify installation
if (-not (Get-Command "pdflatex" -ErrorAction SilentlyContinue)) {
    Write-Error "pdflatex.exe not found. Please verify the MiKTeX path."
    exit 1
}

# Change to the script's directory to ensure files are found
Push-Location (Split-Path -Parent $MyInvocation.MyCommand.Definition)

# --- Compilation Sequence ---
Write-Host "--- Compiling $project.tex ---" -ForegroundColor Yellow

Write-Host "Pass 1: PDFLaTeX (Initial)" -ForegroundColor Cyan
pdflatex -interaction=nonstopmode "$project.tex"

Write-Host "Pass 2: BibTeX (Bibliography)" -ForegroundColor Cyan
bibtex "$project"

Write-Host "Pass 3: PDFLaTeX (Linking Citations)" -ForegroundColor Cyan
pdflatex -interaction=nonstopmode "$project.tex"

Write-Host "Pass 4: PDFLaTeX (Final Layout)" -ForegroundColor Cyan
pdflatex -interaction=nonstopmode "$project.tex"

# --- Completion ---
if (Test-Path "$project.pdf") {
    Write-Host "`nSuccess! Output generated at: $PWD\$project.pdf" -ForegroundColor Green
    # Optional: Open the PDF immediately
    # Invoke-Item "$project.pdf"
} else {
    Write-Error "Compilation failed. Check $project.log for details."
}

# Return to the original directory
Pop-Location