(do-external-symbols (s :sb-ext) (when (search "GC" (symbol-name s)) (print s)))
(cl:finish-output)
