param(
    [Parameter(Mandatory = $true, Position = 0)][string]$OutputFile,
    [Parameter(Mandatory = $true, Position = 1)][string]$FunctionName,
    [Parameter(Mandatory = $true, Position = 2)][int]$CountN,
    [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)][string[]]$LispFiles
)

$Boilerplate = Join-Path $PSScriptRoot "boilerplate.lisp"
$TempFile = Join-Path $env:TEMP "fol_bench_one_$(Get-Random).lisp"

try {
    # Concatenate boilerplate and user files
    Get-Content $Boilerplate -Raw | Set-Content $TempFile
    foreach ($File in $LispFiles) {
        Add-Content $TempFile "`n"
        Get-Content (Resolve-Path $File).Path -Raw | Add-Content $TempFile
    }

    # Prepare SBCL command
    # We call run-one from the fol.benchmarks package.
    # We use string-upcase on a quoted symbol to avoid complex quote escaping in the shell.
    $EvalCmd = "(progn (fol.benchmarks:run-one (cl:symbol-function (cl:find-symbol (cl:string (cl:quote $FunctionName)) :fol.benchmarks)) $CountN :name (cl:string (cl:quote $FunctionName))) (sb-ext:exit))"
    
    # Run SBCL and capture output
    # Using Out-File -Encoding ascii to ensure the file is readable by standard tools.
    sbcl --noinform --load $TempFile --eval $EvalCmd 2>&1 | Set-Content -Path $OutputFile -Encoding Ascii
}
finally {
    if (Test-Path $TempFile) {
        Remove-Item $TempFile
    }
}
