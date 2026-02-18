Set-Location 'C:\Users\frank\Projects\FOL\fol'
$Output = (& sbcl --noinform --non-interactive --load 'run-lsim.lisp' 2>&1)
$Output | Select-Object -Last 100
if ($LASTEXITCODE -ne 0) { exit 1 }
