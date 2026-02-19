;;; Transpiled from test.fol
(in-package :fol.core)

(DEFUN FOO (X)
  (DECLARE (SPECIAL BAR))
  (IF (FBOUNDP 'BAR)
      (BAR . #1=(X))
      (LET ((#2=#:VAL271 BAR))
        (COND ((TYPEP #2# '<DICT>) (GET #2# . #1#))
              ((TYPEP #2# '<VECTOR>) (NTH #2# . #1#))
              ((TYPEP #2# '<SET>) (GET #2# . #1#))
              (T (ERROR "~S is not a function or collection" 'BAR))))))
