param(
    [Parameter(Mandatory = $true, Position = 0)][string]$BenchmarkName,
    [Parameter(Mandatory = $true, Position = 1)][string]$FolFile,
    [Parameter(Mandatory = $true, Position = 2)][string]$BaselineFn,
    [Parameter(Mandatory = $true, Position = 3)][string]$AsrFn,
    [Parameter(Mandatory = $true, Position = 4)][int]$CountN
)

$OutputFile = "results\${BenchmarkName}.txt"

Write-Host "Running ASR benchmark: $BenchmarkName"
.\boilerplate\run-two.ps1 -OutputFile $OutputFile -Function1 $BaselineFn -Function2 $AsrFn -CountN $CountN -LispFiles $FolFile