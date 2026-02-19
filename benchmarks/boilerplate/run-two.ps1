param(
    [Parameter(Mandatory = $true, Position = 0)][string]$OutputFile,
    [Parameter(Mandatory = $true, Position = 1)][string]$Function1,
    [Parameter(Mandatory = $true, Position = 2)][string]$Function2,
    [Parameter(Mandatory = $true, Position = 3)][int]$CountN,
    [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)][string[]]$LispFiles
)

$Boilerplate = Join-Path $PSScriptRoot "boilerplate.lisp"
$TempFile = Join-Path $env:TEMP "fol_bench_two_$(Get-Random).lisp"

try {
    # Concatenate boilerplate and user files
    Get-Content $Boilerplate -Raw | Set-Content $TempFile
    foreach ($File in $LispFiles) {
        Add-Content $TempFile "`n"
        Get-Content (Resolve-Path $File).Path -Raw | Add-Content $TempFile
    }

    # Prepare SBCL command
    # We call run-two from the fol.benchmarks package.
    $S1 = "(cl:symbol-function (cl:find-symbol (cl:string (cl:quote $Function1)) :fol.benchmarks))"
    $S2 = "(cl:symbol-function (cl:find-symbol (cl:string (cl:quote $Function2)) :fol.benchmarks))"
    $Name1 = "(cl:string (cl:quote $Function1))"
    $Name2 = "(cl:string (cl:quote $Function2))"
    $EvalCmd = "(progn (fol.benchmarks:run-two $S1 $S2 $CountN :name1 $Name1 :name2 $Name2) (sb-ext:exit))"
    
    # Run SBCL and capture output
    # Using Out-File -Encoding ascii to ensure the file is readable by standard tools.
    sbcl --noinform --load $TempFile --eval $EvalCmd 2>&1 | Set-Content -Path $OutputFile -Encoding Ascii
}
finally {
    if (Test-Path $TempFile) {
        Remove-Item $TempFile
    }
}
