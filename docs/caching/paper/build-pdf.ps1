<#
.SYNOPSIS
    Compiles a LaTeX paper using MiKTeX.
.DESCRIPTION
    Runs the standard LaTeX build sequence (PDFLaTeX -> BibTeX -> PDFLaTeX x2)
    to resolve citations and references.
.PARAMETER file_name
    The name of the LaTeX file (without .tex extension) to compile. Defaults to "caching".
#>

param(
    [string]$file_name = "caching2"
)

# --- Configuration ---
$project = $file_name
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

# --- Compilation Sequence ---

# 1. First Pass (Generates .aux file for BibTeX)
Write-Host "--- Pass 1: PDFLaTeX (Initial) ---" -ForegroundColor Cyan
pdflatex -interaction=nonstopmode "$project.tex"

# 2. BibTeX (Generates .bbl from .aux)
if (Test-Path "$project.aux") {
    Write-Host "`n--- Pass 2: BibTeX (Bibliography) ---" -ForegroundColor Cyan
    bibtex "$project"
}

# 3. Second Pass (Incorporates Bibliography)
Write-Host "`n--- Pass 3: PDFLaTeX (Linking Citations) ---" -ForegroundColor Cyan
pdflatex -interaction=nonstopmode "$project.tex" | Out-Null

# 4. Third Pass (Finalizing Cross-references and Formatting)
Write-Host "`n--- Pass 4: PDFLaTeX (Final Layout) ---" -ForegroundColor Cyan
pdflatex -interaction=nonstopmode "$project.tex" | Out-Null

# --- Completion ---
if (Test-Path "$project.pdf") {
    Write-Host "`nSuccess! Output generated at: $PWD\$project.pdf" -ForegroundColor Green
    # Optional: Open the PDF immediately
    # Invoke-Item "$project.pdf"
} else {
    Write-Error "Compilation failed. Check $project.log for details."
}
