Remove-Item -Recurse -Force 'C:\Users\frank\.cache\common-lisp' -ErrorAction SilentlyContinue
Set-Location 'C:\Users\frank\Projects\FOL\fol\src'
$Output = (& sbcl --noinform --non-interactive --load '..\run-tests.lisp' 2>&1)
$Output | Select-Object -Last 80
if ($LASTEXITCODE -ne 0) { exit 1 }
