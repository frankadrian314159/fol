Remove-Item -Recurse -Force 'C:\Users\frank\.cache\common-lisp' -ErrorAction SilentlyContinue
Set-Location 'C:\Users\frank\Projects\FOL\fol\src'
\ = (& sbcl --noinform --non-interactive --load '..\run-tests.lisp' 2>&1)
\ | Select-Object -Last 80
