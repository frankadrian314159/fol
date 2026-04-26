;;; Transpiled from ast-optimizer-balanced.fol
(in-package :fol.core)

(DEFPACKAGE "AST-OPT-BALANCED"
  (:USE "FOL.CORE" "CL")
  (:SHADOWING-IMPORT-FROM :FOL.CORE
                          "+"
                          "-"
                          "*"
                          "/"
                          "<"
                          ">"
                          "<="
                          ">="
                          "="
                          "/="
                          "MIN"
                          "MAX"
                          "NOT"
                          "AND"
                          "OR"
                          "IDENTITY"
                          "CONSTANTLY"
                          "COMPLEMENT"
                          "APPLY"
                          "REPLACE"
                          "FIRST"
                          "REST"
                          "NTH"
                          "PUSH"
                          "POP"
                          "FIND"
                          "SUBSEQ"
                          "UNION"
                          "INTERSECTION"
                          "SORT"
                          "REVERSE"
                          "LIST"
                          "LIST*"
                          "VECTOR"
                          "MAP"
                          "REDUCE"
                          "REMOVE"
                          "SOME"
                          "EVERY"
                          "THIRD"
                          "SECOND"
                          "LAST"
                          "BUTLAST"
                          "INTERN"
                          "CHAR"
                          "FORMAT"
                          "COMPILE-FILE"
                          "MACROEXPAND-1"
                          "MACROEXPAND"
                          "DEFMACRO"
                          "DEFCLASS"
                          "DEFGENERIC"
                          "DEFMETHOD"
                          "LOOP"
                          "QUOTE"
                          "IF"
                          "DO"
                          "COND"
                          "CASE"
                          "WHEN"
                          "DOTIMES"
                          "TIME"
                          "ASSERT"
                          "ASSOC"
                          "DISSOC"
                          "CONJ"
                          "UPDATE"
                          "COUNT"
                          "MERGE"
                          "GET"
                          "PRINT"
                          "PPRINT"
                          "READ"
                          "READ-LINE"
                          "CLOSE"
                          "DELETE-FILE"
                          "ATOM"
                          "MAKE"
                          "NIL?"
                          "INC"
                          "DEC"
                          "RANGE"
                          "REPEAT"
                          "REPEATEDLY"
                          "ITERATE"
                          "ITERATION"
                          "INTERLEAVE"
                          "INTERPOSE"
                          "CYCLE"
                          "CONS"
                          "CONCAT"
                          "INTO"
                          "FILTER"
                          "FILTERV"
                          "MAPV"
                          "PMAP"
                          "MAPCAT"
                          "TAKE"
                          "DROP"
                          "TAKE-WHILE"
                          "DROP-WHILE"
                          "PARTITION"
                          "PARTITION-BY"
                          "GROUP-BY"
                          "DISTINCT"
                          "DEDUPE"
                          "FLATTEN"
                          "ZIPMAP"
                          "REDUCTIONS"
                          "REALIZED?"
                          "DORUN"
                          "DOALL"
                          "RUN!"
                          "RAND-NTH"
                          "VEC"
                          "SEQ"
                          "STR"
                          "SUBS"
                          "SPLIT"
                          "JOIN"
                          "TRIM"
                          "UPPER-CASE"
                          "LOWER-CASE"
                          "CAPITALIZE"
                          "CONTAINS?"
                          "EMPTY?"
                          "EVERY?"
                          "DISTINCT?"
                          "NOT-EVERY?"
                          "NOT-ANY?"
                          "PERSISTENT-CLASS"
                          "<PERSISTENT-OBJECT>"
                          "TRUTHY?"
                          "PRINTLN"
                          "DICT"
                          "SET"
                          "EXP"
                          "SYMBOL"
                          "KEYWORD")
  (:EXPORT #:RUN-BENCH #:BUILD-BALANCED #:WALK))

(DEFPACKAGE "AST-OPT-BALANCED"
  (:USE "FOL.CORE" "CL")
  (:SHADOWING-IMPORT-FROM :FOL.CORE
                          "+"
                          "-"
                          "*"
                          "/"
                          "<"
                          ">"
                          "<="
                          ">="
                          "="
                          "/="
                          "MIN"
                          "MAX"
                          "NOT"
                          "AND"
                          "OR"
                          "IDENTITY"
                          "CONSTANTLY"
                          "COMPLEMENT"
                          "APPLY"
                          "REPLACE"
                          "FIRST"
                          "REST"
                          "NTH"
                          "PUSH"
                          "POP"
                          "FIND"
                          "SUBSEQ"
                          "UNION"
                          "INTERSECTION"
                          "SORT"
                          "REVERSE"
                          "LIST"
                          "LIST*"
                          "VECTOR"
                          "MAP"
                          "REDUCE"
                          "REMOVE"
                          "SOME"
                          "EVERY"
                          "THIRD"
                          "SECOND"
                          "LAST"
                          "BUTLAST"
                          "INTERN"
                          "CHAR"
                          "FORMAT"
                          "COMPILE-FILE"
                          "MACROEXPAND-1"
                          "MACROEXPAND"
                          "DEFMACRO"
                          "DEFCLASS"
                          "DEFGENERIC"
                          "DEFMETHOD"
                          "LOOP"
                          "QUOTE"
                          "IF"
                          "DO"
                          "COND"
                          "CASE"
                          "WHEN"
                          "DOTIMES"
                          "TIME"
                          "ASSERT"
                          "ASSOC"
                          "DISSOC"
                          "CONJ"
                          "UPDATE"
                          "COUNT"
                          "MERGE"
                          "GET"
                          "PRINT"
                          "PPRINT"
                          "READ"
                          "READ-LINE"
                          "CLOSE"
                          "DELETE-FILE"
                          "ATOM"
                          "MAKE"
                          "NIL?"
                          "INC"
                          "DEC"
                          "RANGE"
                          "REPEAT"
                          "REPEATEDLY"
                          "ITERATE"
                          "ITERATION"
                          "INTERLEAVE"
                          "INTERPOSE"
                          "CYCLE"
                          "CONS"
                          "CONCAT"
                          "INTO"
                          "FILTER"
                          "FILTERV"
                          "MAPV"
                          "PMAP"
                          "MAPCAT"
                          "TAKE"
                          "DROP"
                          "TAKE-WHILE"
                          "DROP-WHILE"
                          "PARTITION"
                          "PARTITION-BY"
                          "GROUP-BY"
                          "DISTINCT"
                          "DEDUPE"
                          "FLATTEN"
                          "ZIPMAP"
                          "REDUCTIONS"
                          "REALIZED?"
                          "DORUN"
                          "DOALL"
                          "RUN!"
                          "RAND-NTH"
                          "VEC"
                          "SEQ"
                          "STR"
                          "SUBS"
                          "SPLIT"
                          "JOIN"
                          "TRIM"
                          "UPPER-CASE"
                          "LOWER-CASE"
                          "CAPITALIZE"
                          "CONTAINS?"
                          "EMPTY?"
                          "EVERY?"
                          "DISTINCT?"
                          "NOT-EVERY?"
                          "NOT-ANY?"
                          "PERSISTENT-CLASS"
                          "<PERSISTENT-OBJECT>"
                          "TRUTHY?"
                          "PRINTLN"
                          "DICT"
                          "SET"
                          "EXP"
                          "SYMBOL"
                          "KEYWORD"))

(IN-PACKAGE "AST-OPT-BALANCED")

(DEFCLASS <AST-NODE> (FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>) NIL
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<AST-NODE> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<AST-NODE>)) . #1#))

'<AST-NODE>

(DEFCLASS <OP-LIT> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((VAL :INITARG :VAL))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-LIT> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-LIT>)) . #1#))

'<OP-LIT>

(DEFCLASS <OP-VAR> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((NAME :INITARG :NAME))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-VAR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-VAR>)) . #1#))

'<OP-VAR>

(DEFCLASS <OP-ADD> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-ADD> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-ADD>)) . #1#))

'<OP-ADD>

(DEFCLASS <OP-SUB> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-SUB> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-SUB>)) . #1#))

'<OP-SUB>

(DEFCLASS <OP-MUL> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-MUL> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-MUL>)) . #1#))

'<OP-MUL>

(DEFCLASS <OP-DIV> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-DIV> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-DIV>)) . #1#))

'<OP-DIV>

(DEFCLASS <OP-REM> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-REM> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-REM>)) . #1#))

'<OP-REM>

(DEFCLASS <OP-POW> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-POW> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-POW>)) . #1#))

'<OP-POW>

(DEFCLASS <OP-BAND> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-BAND> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-BAND>)) . #1#))

'<OP-BAND>

(DEFCLASS <OP-BOR> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-BOR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-BOR>)) . #1#))

'<OP-BOR>

(DEFCLASS <OP-BXOR> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-BXOR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-BXOR>)) . #1#))

'<OP-BXOR>

(DEFCLASS <OP-SHL> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-SHL> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-SHL>)) . #1#))

'<OP-SHL>

(DEFCLASS <OP-SHR> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-SHR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-SHR>)) . #1#))

'<OP-SHR>

(DEFCLASS <OP-EQ> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-EQ> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-EQ>)) . #1#))

'<OP-EQ>

(DEFCLASS <OP-NEQ> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-NEQ> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-NEQ>)) . #1#))

'<OP-NEQ>

(DEFCLASS <OP-LT> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-LT> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-LT>)) . #1#))

'<OP-LT>

(DEFCLASS <OP-GT> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-GT> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-GT>)) . #1#))

'<OP-GT>

(DEFCLASS <OP-LE> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-LE> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-LE>)) . #1#))

'<OP-LE>

(DEFCLASS <OP-GE> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-GE> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-GE>)) . #1#))

'<OP-GE>

(DEFCLASS <OP-AND> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-AND> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-AND>)) . #1#))

'<OP-AND>

(DEFCLASS <OP-OR> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-OR> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-OR>)) . #1#))

'<OP-OR>

(DEFCLASS <OP-CONCAT> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-CONCAT> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-CONCAT>)) . #1#))

'<OP-CONCAT>

(DEFCLASS <OP-SPLIT> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-SPLIT> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-SPLIT>)) . #1#))

'<OP-SPLIT>

(DEFCLASS <OP-JOIN> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-JOIN> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-JOIN>)) . #1#))

'<OP-JOIN>

(DEFCLASS <OP-MAP> (<AST-NODE> FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>)
          ((LEFT :INITARG :LEFT) (RIGHT :INITARG :RIGHT))
          (:METACLASS FOL.COMPILER.PERSISTENT:PERSISTENT-CLASS))

(DEFUN MAKE-<OP-MAP> (&REST . #1=(FOL.COMPILER::%CTOR-ARGS))
  (APPLY #'FOL.COMPILER.PERSISTENT:%MAKE-PERSISTENT
         (LOAD-TIME-VALUE (FIND-CLASS '<OP-MAP>)) . #1#))

'<OP-MAP>

(DEFGENERIC AST-OPTIMIZE
    (NODE))

(DEFMETHOD AST-OPTIMIZE #1=(A0)
  (DECLARE (SPECIAL N L R))
  (COND
   ((AND (TYPEP A0 '<OP-ADD>)
         (TYPEP #2=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #2# :VAL) 0))
    (LET* ((#3=#:DESTR268 A0)
           (#:DESTR269 (FOL.COMPILER.COLLECTIONS:GET #3# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #3# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-ADD>)
         (TYPEP #4=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #4# :VAL) 0))
    (LET* ((#5=#:DESTR270 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #5# :LEFT))
           (#:DESTR271 (FOL.COMPILER.COLLECTIONS:GET #5# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-SUB>)
         (TYPEP #6=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #6# :VAL) 0))
    (LET* ((#7=#:DESTR272 A0)
           (#:DESTR273 (FOL.COMPILER.COLLECTIONS:GET #7# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #7# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-SUB>)
         (TYPEP #8=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #8# :VAL) 0))
    (LET* ((#9=#:DESTR274 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #9# :LEFT))
           (#:DESTR275 (FOL.COMPILER.COLLECTIONS:GET #9# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-MUL>)
         (TYPEP #10=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #10# :VAL) 0))
    (LET* ((#11=#:DESTR276 A0)
           (#:DESTR277 (FOL.COMPILER.COLLECTIONS:GET #11# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #11# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-MUL>)
         (TYPEP #12=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #12# :VAL) 0))
    (LET* ((#13=#:DESTR278 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #13# :LEFT))
           (#:DESTR279 (FOL.COMPILER.COLLECTIONS:GET #13# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-DIV>)
         (TYPEP #14=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #14# :VAL) 0))
    (LET* ((#15=#:DESTR280 A0)
           (#:DESTR281 (FOL.COMPILER.COLLECTIONS:GET #15# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #15# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-DIV>)
         (TYPEP #16=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #16# :VAL) 0))
    (LET* ((#17=#:DESTR282 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #17# :LEFT))
           (#:DESTR283 (FOL.COMPILER.COLLECTIONS:GET #17# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-REM>)
         (TYPEP #18=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #18# :VAL) 0))
    (LET* ((#19=#:DESTR284 A0)
           (#:DESTR285 (FOL.COMPILER.COLLECTIONS:GET #19# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #19# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-REM>)
         (TYPEP #20=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #20# :VAL) 0))
    (LET* ((#21=#:DESTR286 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #21# :LEFT))
           (#:DESTR287 (FOL.COMPILER.COLLECTIONS:GET #21# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-POW>)
         (TYPEP #22=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #22# :VAL) 0))
    (LET* ((#23=#:DESTR288 A0)
           (#:DESTR289 (FOL.COMPILER.COLLECTIONS:GET #23# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #23# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-POW>)
         (TYPEP #24=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #24# :VAL) 0))
    (LET* ((#25=#:DESTR290 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #25# :LEFT))
           (#:DESTR291 (FOL.COMPILER.COLLECTIONS:GET #25# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-BAND>)
         (TYPEP #26=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #26# :VAL) 0))
    (LET* ((#27=#:DESTR292 A0)
           (#:DESTR293 (FOL.COMPILER.COLLECTIONS:GET #27# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #27# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-BAND>)
         (TYPEP #28=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #28# :VAL) 0))
    (LET* ((#29=#:DESTR294 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #29# :LEFT))
           (#:DESTR295 (FOL.COMPILER.COLLECTIONS:GET #29# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-BOR>)
         (TYPEP #30=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #30# :VAL) 0))
    (LET* ((#31=#:DESTR296 A0)
           (#:DESTR297 (FOL.COMPILER.COLLECTIONS:GET #31# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #31# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-BOR>)
         (TYPEP #32=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #32# :VAL) 0))
    (LET* ((#33=#:DESTR298 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #33# :LEFT))
           (#:DESTR299 (FOL.COMPILER.COLLECTIONS:GET #33# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-BXOR>)
         (TYPEP #34=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #34# :VAL) 0))
    (LET* ((#35=#:DESTR300 A0)
           (#:DESTR301 (FOL.COMPILER.COLLECTIONS:GET #35# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #35# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-BXOR>)
         (TYPEP #36=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #36# :VAL) 0))
    (LET* ((#37=#:DESTR302 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #37# :LEFT))
           (#:DESTR303 (FOL.COMPILER.COLLECTIONS:GET #37# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-SHL>)
         (TYPEP #38=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #38# :VAL) 0))
    (LET* ((#39=#:DESTR304 A0)
           (#:DESTR305 (FOL.COMPILER.COLLECTIONS:GET #39# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #39# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-SHL>)
         (TYPEP #40=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #40# :VAL) 0))
    (LET* ((#41=#:DESTR306 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #41# :LEFT))
           (#:DESTR307 (FOL.COMPILER.COLLECTIONS:GET #41# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-SHR>)
         (TYPEP #42=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #42# :VAL) 0))
    (LET* ((#43=#:DESTR308 A0)
           (#:DESTR309 (FOL.COMPILER.COLLECTIONS:GET #43# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #43# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-SHR>)
         (TYPEP #44=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #44# :VAL) 0))
    (LET* ((#45=#:DESTR310 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #45# :LEFT))
           (#:DESTR311 (FOL.COMPILER.COLLECTIONS:GET #45# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-EQ>)
         (TYPEP #46=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #46# :VAL) 0))
    (LET* ((#47=#:DESTR312 A0)
           (#:DESTR313 (FOL.COMPILER.COLLECTIONS:GET #47# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #47# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-EQ>)
         (TYPEP #48=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #48# :VAL) 0))
    (LET* ((#49=#:DESTR314 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #49# :LEFT))
           (#:DESTR315 (FOL.COMPILER.COLLECTIONS:GET #49# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-NEQ>)
         (TYPEP #50=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #50# :VAL) 0))
    (LET* ((#51=#:DESTR316 A0)
           (#:DESTR317 (FOL.COMPILER.COLLECTIONS:GET #51# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #51# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-NEQ>)
         (TYPEP #52=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #52# :VAL) 0))
    (LET* ((#53=#:DESTR318 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #53# :LEFT))
           (#:DESTR319 (FOL.COMPILER.COLLECTIONS:GET #53# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-LT>)
         (TYPEP #54=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #54# :VAL) 0))
    (LET* ((#55=#:DESTR320 A0)
           (#:DESTR321 (FOL.COMPILER.COLLECTIONS:GET #55# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #55# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-LT>)
         (TYPEP #56=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #56# :VAL) 0))
    (LET* ((#57=#:DESTR322 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #57# :LEFT))
           (#:DESTR323 (FOL.COMPILER.COLLECTIONS:GET #57# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-GT>)
         (TYPEP #58=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #58# :VAL) 0))
    (LET* ((#59=#:DESTR324 A0)
           (#:DESTR325 (FOL.COMPILER.COLLECTIONS:GET #59# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #59# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-GT>)
         (TYPEP #60=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #60# :VAL) 0))
    (LET* ((#61=#:DESTR326 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #61# :LEFT))
           (#:DESTR327 (FOL.COMPILER.COLLECTIONS:GET #61# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-LE>)
         (TYPEP #62=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #62# :VAL) 0))
    (LET* ((#63=#:DESTR328 A0)
           (#:DESTR329 (FOL.COMPILER.COLLECTIONS:GET #63# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #63# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-LE>)
         (TYPEP #64=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #64# :VAL) 0))
    (LET* ((#65=#:DESTR330 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #65# :LEFT))
           (#:DESTR331 (FOL.COMPILER.COLLECTIONS:GET #65# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-GE>)
         (TYPEP #66=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #66# :VAL) 0))
    (LET* ((#67=#:DESTR332 A0)
           (#:DESTR333 (FOL.COMPILER.COLLECTIONS:GET #67# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #67# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-GE>)
         (TYPEP #68=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #68# :VAL) 0))
    (LET* ((#69=#:DESTR334 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #69# :LEFT))
           (#:DESTR335 (FOL.COMPILER.COLLECTIONS:GET #69# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-AND>)
         (TYPEP #70=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #70# :VAL) 0))
    (LET* ((#71=#:DESTR336 A0)
           (#:DESTR337 (FOL.COMPILER.COLLECTIONS:GET #71# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #71# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-AND>)
         (TYPEP #72=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #72# :VAL) 0))
    (LET* ((#73=#:DESTR338 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #73# :LEFT))
           (#:DESTR339 (FOL.COMPILER.COLLECTIONS:GET #73# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-OR>)
         (TYPEP #74=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #74# :VAL) 0))
    (LET* ((#75=#:DESTR340 A0)
           (#:DESTR341 (FOL.COMPILER.COLLECTIONS:GET #75# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #75# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-OR>)
         (TYPEP #76=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #76# :VAL) 0))
    (LET* ((#77=#:DESTR342 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #77# :LEFT))
           (#:DESTR343 (FOL.COMPILER.COLLECTIONS:GET #77# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-CONCAT>)
         (TYPEP #78=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #78# :VAL) 0))
    (LET* ((#79=#:DESTR344 A0)
           (#:DESTR345 (FOL.COMPILER.COLLECTIONS:GET #79# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #79# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-CONCAT>)
         (TYPEP #80=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #80# :VAL) 0))
    (LET* ((#81=#:DESTR346 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #81# :LEFT))
           (#:DESTR347 (FOL.COMPILER.COLLECTIONS:GET #81# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-SPLIT>)
         (TYPEP #82=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #82# :VAL) 0))
    (LET* ((#83=#:DESTR348 A0)
           (#:DESTR349 (FOL.COMPILER.COLLECTIONS:GET #83# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #83# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-SPLIT>)
         (TYPEP #84=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #84# :VAL) 0))
    (LET* ((#85=#:DESTR350 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #85# :LEFT))
           (#:DESTR351 (FOL.COMPILER.COLLECTIONS:GET #85# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-JOIN>)
         (TYPEP #86=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #86# :VAL) 0))
    (LET* ((#87=#:DESTR352 A0)
           (#:DESTR353 (FOL.COMPILER.COLLECTIONS:GET #87# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #87# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-JOIN>)
         (TYPEP #88=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #88# :VAL) 0))
    (LET* ((#89=#:DESTR354 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #89# :LEFT))
           (#:DESTR355 (FOL.COMPILER.COLLECTIONS:GET #89# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-MAP>)
         (TYPEP #90=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #90# :VAL) 0))
    (LET* ((#91=#:DESTR356 A0)
           (#:DESTR357 (FOL.COMPILER.COLLECTIONS:GET #91# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #91# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-MAP>)
         (TYPEP #92=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #92# :VAL) 0))
    (LET* ((#93=#:DESTR358 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #93# :LEFT))
           (#:DESTR359 (FOL.COMPILER.COLLECTIONS:GET #93# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-MUL>)
         (TYPEP #94=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #94# :VAL) 1))
    (LET* ((#95=#:DESTR360 A0)
           (#:DESTR361 (FOL.COMPILER.COLLECTIONS:GET #95# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #95# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-MUL>)
         (TYPEP #96=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #96# :VAL) 1))
    (LET* ((#97=#:DESTR362 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #97# :LEFT))
           (#:DESTR363 (FOL.COMPILER.COLLECTIONS:GET #97# :RIGHT)))
      L))
   ((AND (TYPEP A0 '<OP-DIV>)
         (TYPEP #98=(FOL.COMPILER.COLLECTIONS:GET A0 :LEFT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #98# :VAL) 1))
    (LET* ((#99=#:DESTR364 A0)
           (#:DESTR365 (FOL.COMPILER.COLLECTIONS:GET #99# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #99# :RIGHT)))
      R))
   ((AND (TYPEP A0 '<OP-DIV>)
         (TYPEP #100=(FOL.COMPILER.COLLECTIONS:GET A0 :RIGHT) '<OP-LIT>)
         (EQL (FOL.COMPILER.COLLECTIONS:GET #100# :VAL) 1))
    (LET* ((#101=#:DESTR366 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #101# :LEFT))
           (#:DESTR367 (FOL.COMPILER.COLLECTIONS:GET #101# :RIGHT)))
      L))
   (T
    (LET* ((N A0))
      N))
   (T
    (ERROR "No matching method clause for ~A with arguments: ~S" 'AST-OPTIMIZE
           (LIST . #1#)))))

(DEFGENERIC WALK
    (NODE))

(DEFMETHOD WALK #1=(A0)
  (DECLARE
   (SPECIAL MAKE-<OP-MAP> MAKE-<OP-JOIN> MAKE-<OP-SPLIT> MAKE-<OP-CONCAT>
    MAKE-<OP-OR> MAKE-<OP-AND> MAKE-<OP-GE> MAKE-<OP-LE> MAKE-<OP-GT>
    MAKE-<OP-LT> MAKE-<OP-NEQ> MAKE-<OP-EQ> MAKE-<OP-SHR> MAKE-<OP-SHL>
    MAKE-<OP-BXOR> MAKE-<OP-BOR> MAKE-<OP-BAND> MAKE-<OP-POW> MAKE-<OP-REM>
    MAKE-<OP-DIV> MAKE-<OP-MUL> MAKE-<OP-SUB> MAKE-<OP-ADD> R L N))
  (COND
   ((TYPEP A0 '<OP-LIT>)
    (LET* ((N A0))
      N))
   ((TYPEP A0 '<OP-ADD>)
    (LET* ((#2=#:DESTR368 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #2# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #2# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-ADD>)
           (MAKE-<OP-ADD> . #3=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#4=#:VAL369 MAKE-<OP-ADD>))
             (COND ((FUNCTIONP #4#) (FUNCALL #4# . #3#))
                   (T
                    (ERROR #5="~S is not a function or collection"
                           'MAKE-<OP-ADD>))))))))
   ((TYPEP A0 '<OP-SUB>)
    (LET* ((#6=#:DESTR370 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #6# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #6# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-SUB>)
           (MAKE-<OP-SUB> . #7=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#8=#:VAL371 MAKE-<OP-SUB>))
             (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                   (T (ERROR #5# 'MAKE-<OP-SUB>))))))))
   ((TYPEP A0 '<OP-MUL>)
    (LET* ((#9=#:DESTR372 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #9# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #9# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-MUL>)
           (MAKE-<OP-MUL> . #10=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#11=#:VAL373 MAKE-<OP-MUL>))
             (COND ((FUNCTIONP #11#) (FUNCALL #11# . #10#))
                   (T (ERROR #5# 'MAKE-<OP-MUL>))))))))
   ((TYPEP A0 '<OP-DIV>)
    (LET* ((#12=#:DESTR374 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #12# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #12# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-DIV>)
           (MAKE-<OP-DIV> . #13=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#14=#:VAL375 MAKE-<OP-DIV>))
             (COND ((FUNCTIONP #14#) (FUNCALL #14# . #13#))
                   (T (ERROR #5# 'MAKE-<OP-DIV>))))))))
   ((TYPEP A0 '<OP-REM>)
    (LET* ((#15=#:DESTR376 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #15# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #15# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-REM>)
           (MAKE-<OP-REM> . #16=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#17=#:VAL377 MAKE-<OP-REM>))
             (COND ((FUNCTIONP #17#) (FUNCALL #17# . #16#))
                   (T (ERROR #5# 'MAKE-<OP-REM>))))))))
   ((TYPEP A0 '<OP-POW>)
    (LET* ((#18=#:DESTR378 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #18# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #18# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-POW>)
           (MAKE-<OP-POW> . #19=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#20=#:VAL379 MAKE-<OP-POW>))
             (COND ((FUNCTIONP #20#) (FUNCALL #20# . #19#))
                   (T (ERROR #5# 'MAKE-<OP-POW>))))))))
   ((TYPEP A0 '<OP-BAND>)
    (LET* ((#21=#:DESTR380 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #21# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #21# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-BAND>)
           (MAKE-<OP-BAND> . #22=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#23=#:VAL381 MAKE-<OP-BAND>))
             (COND ((FUNCTIONP #23#) (FUNCALL #23# . #22#))
                   (T (ERROR #5# 'MAKE-<OP-BAND>))))))))
   ((TYPEP A0 '<OP-BOR>)
    (LET* ((#24=#:DESTR382 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #24# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #24# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-BOR>)
           (MAKE-<OP-BOR> . #25=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#26=#:VAL383 MAKE-<OP-BOR>))
             (COND ((FUNCTIONP #26#) (FUNCALL #26# . #25#))
                   (T (ERROR #5# 'MAKE-<OP-BOR>))))))))
   ((TYPEP A0 '<OP-BXOR>)
    (LET* ((#27=#:DESTR384 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #27# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #27# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-BXOR>)
           (MAKE-<OP-BXOR> . #28=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#29=#:VAL385 MAKE-<OP-BXOR>))
             (COND ((FUNCTIONP #29#) (FUNCALL #29# . #28#))
                   (T (ERROR #5# 'MAKE-<OP-BXOR>))))))))
   ((TYPEP A0 '<OP-SHL>)
    (LET* ((#30=#:DESTR386 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #30# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #30# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-SHL>)
           (MAKE-<OP-SHL> . #31=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#32=#:VAL387 MAKE-<OP-SHL>))
             (COND ((FUNCTIONP #32#) (FUNCALL #32# . #31#))
                   (T (ERROR #5# 'MAKE-<OP-SHL>))))))))
   ((TYPEP A0 '<OP-SHR>)
    (LET* ((#33=#:DESTR388 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #33# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #33# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-SHR>)
           (MAKE-<OP-SHR> . #34=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#35=#:VAL389 MAKE-<OP-SHR>))
             (COND ((FUNCTIONP #35#) (FUNCALL #35# . #34#))
                   (T (ERROR #5# 'MAKE-<OP-SHR>))))))))
   ((TYPEP A0 '<OP-EQ>)
    (LET* ((#36=#:DESTR390 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #36# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #36# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-EQ>)
           (MAKE-<OP-EQ> . #37=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#38=#:VAL391 MAKE-<OP-EQ>))
             (COND ((FUNCTIONP #38#) (FUNCALL #38# . #37#))
                   (T (ERROR #5# 'MAKE-<OP-EQ>))))))))
   ((TYPEP A0 '<OP-NEQ>)
    (LET* ((#39=#:DESTR392 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #39# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #39# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-NEQ>)
           (MAKE-<OP-NEQ> . #40=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#41=#:VAL393 MAKE-<OP-NEQ>))
             (COND ((FUNCTIONP #41#) (FUNCALL #41# . #40#))
                   (T (ERROR #5# 'MAKE-<OP-NEQ>))))))))
   ((TYPEP A0 '<OP-LT>)
    (LET* ((#42=#:DESTR394 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #42# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #42# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-LT>)
           (MAKE-<OP-LT> . #43=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#44=#:VAL395 MAKE-<OP-LT>))
             (COND ((FUNCTIONP #44#) (FUNCALL #44# . #43#))
                   (T (ERROR #5# 'MAKE-<OP-LT>))))))))
   ((TYPEP A0 '<OP-GT>)
    (LET* ((#45=#:DESTR396 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #45# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #45# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-GT>)
           (MAKE-<OP-GT> . #46=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#47=#:VAL397 MAKE-<OP-GT>))
             (COND ((FUNCTIONP #47#) (FUNCALL #47# . #46#))
                   (T (ERROR #5# 'MAKE-<OP-GT>))))))))
   ((TYPEP A0 '<OP-LE>)
    (LET* ((#48=#:DESTR398 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #48# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #48# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-LE>)
           (MAKE-<OP-LE> . #49=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#50=#:VAL399 MAKE-<OP-LE>))
             (COND ((FUNCTIONP #50#) (FUNCALL #50# . #49#))
                   (T (ERROR #5# 'MAKE-<OP-LE>))))))))
   ((TYPEP A0 '<OP-GE>)
    (LET* ((#51=#:DESTR400 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #51# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #51# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-GE>)
           (MAKE-<OP-GE> . #52=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#53=#:VAL401 MAKE-<OP-GE>))
             (COND ((FUNCTIONP #53#) (FUNCALL #53# . #52#))
                   (T (ERROR #5# 'MAKE-<OP-GE>))))))))
   ((TYPEP A0 '<OP-AND>)
    (LET* ((#54=#:DESTR402 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #54# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #54# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-AND>)
           (MAKE-<OP-AND> . #55=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#56=#:VAL403 MAKE-<OP-AND>))
             (COND ((FUNCTIONP #56#) (FUNCALL #56# . #55#))
                   (T (ERROR #5# 'MAKE-<OP-AND>))))))))
   ((TYPEP A0 '<OP-OR>)
    (LET* ((#57=#:DESTR404 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #57# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #57# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-OR>)
           (MAKE-<OP-OR> . #58=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#59=#:VAL405 MAKE-<OP-OR>))
             (COND ((FUNCTIONP #59#) (FUNCALL #59# . #58#))
                   (T (ERROR #5# 'MAKE-<OP-OR>))))))))
   ((TYPEP A0 '<OP-CONCAT>)
    (LET* ((#60=#:DESTR406 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #60# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #60# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-CONCAT>)
           (MAKE-<OP-CONCAT> . #61=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#62=#:VAL407 MAKE-<OP-CONCAT>))
             (COND ((FUNCTIONP #62#) (FUNCALL #62# . #61#))
                   (T (ERROR #5# 'MAKE-<OP-CONCAT>))))))))
   ((TYPEP A0 '<OP-SPLIT>)
    (LET* ((#63=#:DESTR408 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #63# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #63# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-SPLIT>)
           (MAKE-<OP-SPLIT> . #64=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#65=#:VAL409 MAKE-<OP-SPLIT>))
             (COND ((FUNCTIONP #65#) (FUNCALL #65# . #64#))
                   (T (ERROR #5# 'MAKE-<OP-SPLIT>))))))))
   ((TYPEP A0 '<OP-JOIN>)
    (LET* ((#66=#:DESTR410 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #66# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #66# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-JOIN>)
           (MAKE-<OP-JOIN> . #67=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#68=#:VAL411 MAKE-<OP-JOIN>))
             (COND ((FUNCTIONP #68#) (FUNCALL #68# . #67#))
                   (T (ERROR #5# 'MAKE-<OP-JOIN>))))))))
   ((TYPEP A0 '<OP-MAP>)
    (LET* ((#69=#:DESTR412 A0)
           (L (FOL.COMPILER.COLLECTIONS:GET #69# :LEFT))
           (R (FOL.COMPILER.COLLECTIONS:GET #69# :RIGHT)))
      (AST-OPTIMIZE
       (IF (FBOUNDP 'MAKE-<OP-MAP>)
           (MAKE-<OP-MAP> . #70=(:LEFT (WALK L) :RIGHT (WALK R)))
           (LET ((#71=#:VAL413 MAKE-<OP-MAP>))
             (COND ((FUNCTIONP #71#) (FUNCALL #71# . #70#))
                   (T (ERROR #5# 'MAKE-<OP-MAP>))))))))
   (T
    (LET* ((N A0))
      N))
   (T
    (ERROR "No matching method clause for ~A with arguments: ~S" 'WALK
           (LIST . #1#)))))

(DEFUN MAKE-OP (IDX LEFT RIGHT)
  (DECLARE
   (SPECIAL MAKE-<OP-MAP> MAKE-<OP-JOIN> MAKE-<OP-SPLIT> MAKE-<OP-CONCAT>
    MAKE-<OP-OR> MAKE-<OP-AND> MAKE-<OP-GE> MAKE-<OP-LE> MAKE-<OP-GT>
    MAKE-<OP-LT> MAKE-<OP-NEQ> MAKE-<OP-EQ> MAKE-<OP-SHR> MAKE-<OP-SHL>
    MAKE-<OP-BXOR> MAKE-<OP-BOR> MAKE-<OP-BAND> MAKE-<OP-POW> MAKE-<OP-REM>
    MAKE-<OP-DIV> MAKE-<OP-MUL> MAKE-<OP-SUB> MAKE-<OP-ADD>))
  (LET ((K (MOD IDX 23)))
    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (= K 0))
        (IF (FBOUNDP 'MAKE-<OP-ADD>)
            (MAKE-<OP-ADD> . #1=(:LEFT LEFT :RIGHT RIGHT))
            (LET ((#2=#:VAL414 MAKE-<OP-ADD>))
              (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                    (T
                     (ERROR #3="~S is not a function or collection"
                            'MAKE-<OP-ADD>)))))
        (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (= K 1))
            (IF (FBOUNDP 'MAKE-<OP-SUB>)
                (MAKE-<OP-SUB> . #4=(:LEFT LEFT :RIGHT RIGHT))
                (LET ((#5=#:VAL415 MAKE-<OP-SUB>))
                  (COND ((FUNCTIONP #5#) (FUNCALL #5# . #4#))
                        (T (ERROR #3# 'MAKE-<OP-SUB>)))))
            (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (= K 2))
                (IF (FBOUNDP 'MAKE-<OP-MUL>)
                    (MAKE-<OP-MUL> . #6=(:LEFT LEFT :RIGHT RIGHT))
                    (LET ((#7=#:VAL416 MAKE-<OP-MUL>))
                      (COND ((FUNCTIONP #7#) (FUNCALL #7# . #6#))
                            (T (ERROR #3# 'MAKE-<OP-MUL>)))))
                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (= K 3))
                    (IF (FBOUNDP 'MAKE-<OP-DIV>)
                        (MAKE-<OP-DIV> . #8=(:LEFT LEFT :RIGHT RIGHT))
                        (LET ((#9=#:VAL417 MAKE-<OP-DIV>))
                          (COND ((FUNCTIONP #9#) (FUNCALL #9# . #8#))
                                (T (ERROR #3# 'MAKE-<OP-DIV>)))))
                    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (= K 4))
                        (IF (FBOUNDP 'MAKE-<OP-REM>)
                            (MAKE-<OP-REM> . #10=(:LEFT LEFT :RIGHT RIGHT))
                            (LET ((#11=#:VAL418 MAKE-<OP-REM>))
                              (COND ((FUNCTIONP #11#) (FUNCALL #11# . #10#))
                                    (T (ERROR #3# 'MAKE-<OP-REM>)))))
                        (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (= K 5))
                            (IF (FBOUNDP 'MAKE-<OP-POW>)
                                (MAKE-<OP-POW> . #12=(:LEFT LEFT :RIGHT RIGHT))
                                (LET ((#13=#:VAL419 MAKE-<OP-POW>))
                                  (COND
                                   ((FUNCTIONP #13#) (FUNCALL #13# . #12#))
                                   (T (ERROR #3# 'MAKE-<OP-POW>)))))
                            (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (= K 6))
                                (IF (FBOUNDP 'MAKE-<OP-BAND>)
                                    (MAKE-<OP-BAND>
                                     . #14=(:LEFT LEFT :RIGHT RIGHT))
                                    (LET ((#15=#:VAL420 MAKE-<OP-BAND>))
                                      (COND
                                       ((FUNCTIONP #15#) (FUNCALL #15# . #14#))
                                       (T (ERROR #3# 'MAKE-<OP-BAND>)))))
                                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (= K 7))
                                    (IF (FBOUNDP 'MAKE-<OP-BOR>)
                                        (MAKE-<OP-BOR>
                                         . #16=(:LEFT LEFT :RIGHT RIGHT))
                                        (LET ((#17=#:VAL421 MAKE-<OP-BOR>))
                                          (COND
                                           ((FUNCTIONP #17#)
                                            (FUNCALL #17# . #16#))
                                           (T (ERROR #3# 'MAKE-<OP-BOR>)))))
                                    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                         (= K 8))
                                        (IF (FBOUNDP 'MAKE-<OP-BXOR>)
                                            (MAKE-<OP-BXOR>
                                             . #18=(:LEFT LEFT :RIGHT RIGHT))
                                            (LET ((#19=#:VAL422 MAKE-<OP-BXOR>))
                                              (COND
                                               ((FUNCTIONP #19#)
                                                (FUNCALL #19# . #18#))
                                               (T
                                                (ERROR #3# 'MAKE-<OP-BXOR>)))))
                                        (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                             (= K 9))
                                            (IF (FBOUNDP 'MAKE-<OP-SHL>)
                                                (MAKE-<OP-SHL>
                                                 . #20=(:LEFT LEFT :RIGHT
                                                        RIGHT))
                                                (LET ((#21=#:VAL423
                                                       MAKE-<OP-SHL>))
                                                  (COND
                                                   ((FUNCTIONP #21#)
                                                    (FUNCALL #21# . #20#))
                                                   (T
                                                    (ERROR #3#
                                                           'MAKE-<OP-SHL>)))))
                                            (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                 (= K 10))
                                                (IF (FBOUNDP 'MAKE-<OP-SHR>)
                                                    (MAKE-<OP-SHR>
                                                     . #22=(:LEFT LEFT :RIGHT
                                                            RIGHT))
                                                    (LET ((#23=#:VAL424
                                                           MAKE-<OP-SHR>))
                                                      (COND
                                                       ((FUNCTIONP #23#)
                                                        (FUNCALL #23# . #22#))
                                                       (T
                                                        (ERROR #3#
                                                               'MAKE-<OP-SHR>)))))
                                                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                     (= K 11))
                                                    (IF (FBOUNDP 'MAKE-<OP-EQ>)
                                                        (MAKE-<OP-EQ>
                                                         . #24=(:LEFT LEFT
                                                                :RIGHT RIGHT))
                                                        (LET ((#25=#:VAL425
                                                               MAKE-<OP-EQ>))
                                                          (COND
                                                           ((FUNCTIONP #25#)
                                                            (FUNCALL #25#
                                                                     . #24#))
                                                           (T
                                                            (ERROR #3#
                                                                   'MAKE-<OP-EQ>)))))
                                                    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                         (= K 12))
                                                        (IF (FBOUNDP
                                                             'MAKE-<OP-NEQ>)
                                                            (MAKE-<OP-NEQ>
                                                             . #26=(:LEFT LEFT
                                                                    :RIGHT
                                                                    RIGHT))
                                                            (LET ((#27=#:VAL426
                                                                   MAKE-<OP-NEQ>))
                                                              (COND
                                                               ((FUNCTIONP
                                                                 #27#)
                                                                (FUNCALL #27#
                                                                         . #26#))
                                                               (T
                                                                (ERROR #3#
                                                                       'MAKE-<OP-NEQ>)))))
                                                        (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                             (= K 13))
                                                            (IF (FBOUNDP
                                                                 'MAKE-<OP-LT>)
                                                                (MAKE-<OP-LT>
                                                                 . #28=(:LEFT
                                                                        LEFT
                                                                        :RIGHT
                                                                        RIGHT))
                                                                (LET ((#29=#:VAL427
                                                                       MAKE-<OP-LT>))
                                                                  (COND
                                                                   ((FUNCTIONP
                                                                     #29#)
                                                                    (FUNCALL
                                                                     #29#
                                                                     . #28#))
                                                                   (T
                                                                    (ERROR #3#
                                                                           'MAKE-<OP-LT>)))))
                                                            (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                 (= K 14))
                                                                (IF (FBOUNDP
                                                                     'MAKE-<OP-GT>)
                                                                    (MAKE-<OP-GT>
                                                                     . #30=(:LEFT
                                                                            LEFT
                                                                            :RIGHT
                                                                            RIGHT))
                                                                    (LET ((#31=#:VAL428
                                                                           MAKE-<OP-GT>))
                                                                      (COND
                                                                       ((FUNCTIONP
                                                                         #31#)
                                                                        (FUNCALL
                                                                         #31#
                                                                         . #30#))
                                                                       (T
                                                                        (ERROR
                                                                         #3#
                                                                         'MAKE-<OP-GT>)))))
                                                                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                     (= K 15))
                                                                    (IF (FBOUNDP
                                                                         'MAKE-<OP-LE>)
                                                                        (MAKE-<OP-LE>
                                                                         . #32=(:LEFT
                                                                                LEFT
                                                                                :RIGHT
                                                                                RIGHT))
                                                                        (LET ((#33=#:VAL429
                                                                               MAKE-<OP-LE>))
                                                                          (COND
                                                                           ((FUNCTIONP
                                                                             #33#)
                                                                            (FUNCALL
                                                                             #33#
                                                                             . #32#))
                                                                           (T
                                                                            (ERROR
                                                                             #3#
                                                                             'MAKE-<OP-LE>)))))
                                                                    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                         (= K
                                                                            16))
                                                                        (IF (FBOUNDP
                                                                             'MAKE-<OP-GE>)
                                                                            (MAKE-<OP-GE>
                                                                             . #34=(:LEFT
                                                                                    LEFT
                                                                                    :RIGHT
                                                                                    RIGHT))
                                                                            (LET ((#35=#:VAL430
                                                                                   MAKE-<OP-GE>))
                                                                              (COND
                                                                               ((FUNCTIONP
                                                                                 #35#)
                                                                                (FUNCALL
                                                                                 #35#
                                                                                 . #34#))
                                                                               (T
                                                                                (ERROR
                                                                                 #3#
                                                                                 'MAKE-<OP-GE>)))))
                                                                        (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                             (=
                                                                              K
                                                                              17))
                                                                            (IF (FBOUNDP
                                                                                 'MAKE-<OP-AND>)
                                                                                (MAKE-<OP-AND>
                                                                                 . #36=(:LEFT
                                                                                        LEFT
                                                                                        :RIGHT
                                                                                        RIGHT))
                                                                                (LET ((#37=#:VAL431
                                                                                       MAKE-<OP-AND>))
                                                                                  (COND
                                                                                   ((FUNCTIONP
                                                                                     #37#)
                                                                                    (FUNCALL
                                                                                     #37#
                                                                                     . #36#))
                                                                                   (T
                                                                                    (ERROR
                                                                                     #3#
                                                                                     'MAKE-<OP-AND>)))))
                                                                            (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                                 (=
                                                                                  K
                                                                                  18))
                                                                                (IF (FBOUNDP
                                                                                     'MAKE-<OP-OR>)
                                                                                    (MAKE-<OP-OR>
                                                                                     . #38=(:LEFT
                                                                                            LEFT
                                                                                            :RIGHT
                                                                                            RIGHT))
                                                                                    (LET ((#39=#:VAL432
                                                                                           MAKE-<OP-OR>))
                                                                                      (COND
                                                                                       ((FUNCTIONP
                                                                                         #39#)
                                                                                        (FUNCALL
                                                                                         #39#
                                                                                         . #38#))
                                                                                       (T
                                                                                        (ERROR
                                                                                         #3#
                                                                                         'MAKE-<OP-OR>)))))
                                                                                (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                                     (=
                                                                                      K
                                                                                      19))
                                                                                    (IF (FBOUNDP
                                                                                         'MAKE-<OP-CONCAT>)
                                                                                        (MAKE-<OP-CONCAT>
                                                                                         . #40=(:LEFT
                                                                                                LEFT
                                                                                                :RIGHT
                                                                                                RIGHT))
                                                                                        (LET ((#41=#:VAL433
                                                                                               MAKE-<OP-CONCAT>))
                                                                                          (COND
                                                                                           ((FUNCTIONP
                                                                                             #41#)
                                                                                            (FUNCALL
                                                                                             #41#
                                                                                             . #40#))
                                                                                           (T
                                                                                            (ERROR
                                                                                             #3#
                                                                                             'MAKE-<OP-CONCAT>)))))
                                                                                    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                                         (=
                                                                                          K
                                                                                          20))
                                                                                        (IF (FBOUNDP
                                                                                             'MAKE-<OP-SPLIT>)
                                                                                            (MAKE-<OP-SPLIT>
                                                                                             . #42=(:LEFT
                                                                                                    LEFT
                                                                                                    :RIGHT
                                                                                                    RIGHT))
                                                                                            (LET ((#43=#:VAL434
                                                                                                   MAKE-<OP-SPLIT>))
                                                                                              (COND
                                                                                               ((FUNCTIONP
                                                                                                 #43#)
                                                                                                (FUNCALL
                                                                                                 #43#
                                                                                                 . #42#))
                                                                                               (T
                                                                                                (ERROR
                                                                                                 #3#
                                                                                                 'MAKE-<OP-SPLIT>)))))
                                                                                        (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                                             (=
                                                                                              K
                                                                                              21))
                                                                                            (IF (FBOUNDP
                                                                                                 'MAKE-<OP-JOIN>)
                                                                                                (MAKE-<OP-JOIN>
                                                                                                 . #44=(:LEFT
                                                                                                        LEFT
                                                                                                        :RIGHT
                                                                                                        RIGHT))
                                                                                                (LET ((#45=#:VAL435
                                                                                                       MAKE-<OP-JOIN>))
                                                                                                  (COND
                                                                                                   ((FUNCTIONP
                                                                                                     #45#)
                                                                                                    (FUNCALL
                                                                                                     #45#
                                                                                                     . #44#))
                                                                                                   (T
                                                                                                    (ERROR
                                                                                                     #3#
                                                                                                     'MAKE-<OP-JOIN>)))))
                                                                                            (IF (FOL.COMPILER.PRIMITIVES:TRUTHY?
                                                                                                 (=
                                                                                                  K
                                                                                                  22))
                                                                                                (IF (FBOUNDP
                                                                                                     'MAKE-<OP-MAP>)
                                                                                                    (MAKE-<OP-MAP>
                                                                                                     . #46=(:LEFT
                                                                                                            LEFT
                                                                                                            :RIGHT
                                                                                                            RIGHT))
                                                                                                    (LET ((#47=#:VAL436
                                                                                                           MAKE-<OP-MAP>))
                                                                                                      (COND
                                                                                                       ((FUNCTIONP
                                                                                                         #47#)
                                                                                                        (FUNCALL
                                                                                                         #47#
                                                                                                         . #46#))
                                                                                                       (T
                                                                                                        (ERROR
                                                                                                         #3#
                                                                                                         'MAKE-<OP-MAP>)))))
                                                                                                NIL)))))))))))))))))))))))))

(DEFUN MAKE-LEAF (IDX)
  (DECLARE (SPECIAL MAKE-<OP-VAR> MAKE-<OP-LIT>))
  (LET ((K (MOD IDX 3)))
    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (= K 0))
        (IF (FBOUNDP 'MAKE-<OP-LIT>)
            (MAKE-<OP-LIT> . #1=(:VAL 0))
            (LET ((#2=#:VAL437 MAKE-<OP-LIT>))
              (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                    ((TYPEP #2# . #3=('FOL.COMPILER.COLLECTIONS:<DICT>))
                     (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                    ((TYPEP #2# . #4=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                     (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2# . #1#))
                    ((TYPEP #2# . #5=('FOL.COMPILER.COLLECTIONS:<SET>))
                     (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                    (T
                     (ERROR #6="~S is not a function or collection"
                            'MAKE-<OP-LIT>)))))
        (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (= K 1))
            (IF (FBOUNDP 'MAKE-<OP-LIT>)
                (MAKE-<OP-LIT> . #7=(:VAL 1))
                (LET ((#8=#:VAL438 MAKE-<OP-LIT>))
                  (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                        ((TYPEP #8# . #3#)
                         (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                        ((TYPEP #8# . #4#)
                         (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #8# . #7#))
                        ((TYPEP #8# . #5#)
                         (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                        (T (ERROR #6# 'MAKE-<OP-LIT>)))))
            (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (= K 2))
                (IF (FBOUNDP 'MAKE-<OP-VAR>)
                    (MAKE-<OP-VAR> . #9=(:NAME :X))
                    (LET ((#10=#:VAL439 MAKE-<OP-VAR>))
                      (COND ((FUNCTIONP #10#) (FUNCALL #10# . #9#))
                            ((TYPEP #10# . #3#)
                             (FOL.COMPILER.COLLECTIONS:GET #10# . #9#))
                            ((TYPEP #10# . #4#)
                             (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #10#
                                                                    . #9#))
                            ((TYPEP #10# . #5#)
                             (FOL.COMPILER.COLLECTIONS:GET #10# . #9#))
                            (T (ERROR #6# 'MAKE-<OP-VAR>)))))
                NIL)))))

(DEFUN BUILD-BALANCED (N IDX)
  (DECLARE (SPECIAL BUILD-BALANCED))
  (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (<= N 1))
      (MAKE-LEAF IDX)
      (LET ((HALF (/ (- N 1) 2)))
        (MAKE-OP IDX
         (IF (FBOUNDP 'BUILD-BALANCED)
             (BUILD-BALANCED . #1=(HALF (* 2 IDX)))
             (LET ((#2=#:VAL440 BUILD-BALANCED))
               (COND ((FUNCTIONP #2#) (FUNCALL #2# . #1#))
                     ((TYPEP #2# . #3=('FOL.COMPILER.COLLECTIONS:<DICT>))
                      (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                     ((TYPEP #2# . #4=('FOL.COMPILER.COLLECTIONS:<VECTOR>))
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #2# . #1#))
                     ((TYPEP #2# . #5=('FOL.COMPILER.COLLECTIONS:<SET>))
                      (FOL.COMPILER.COLLECTIONS:GET #2# . #1#))
                     (T
                      (ERROR #6="~S is not a function or collection"
                             'BUILD-BALANCED)))))
         (IF (FBOUNDP 'BUILD-BALANCED)
             (BUILD-BALANCED . #7=(HALF (+ (* 2 IDX) 1)))
             (LET ((#8=#:VAL441 BUILD-BALANCED))
               (COND ((FUNCTIONP #8#) (FUNCALL #8# . #7#))
                     ((TYPEP #8# . #3#)
                      (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                     ((TYPEP #8# . #4#)
                      (FOL.COMPILER.COLLECTION-FUNCTIONS:NTH #8# . #7#))
                     ((TYPEP #8# . #5#)
                      (FOL.COMPILER.COLLECTIONS:GET #8# . #7#))
                     (T (ERROR #6# 'BUILD-BALANCED)))))))))

(DEFUN RUN-BENCH (N)
  (LET ((TREE (BUILD-BALANCED 9999 1)))
    (LET ((#1=#:MAX-442 N))
      (BLOCK LOOP-BLOCK-1
        (LET ((#2=#:I-443 0))
          (TAGBODY
           LOOP-1
            (LET ((RESULT-1
                   (PROGN
                    (IF (FOL.COMPILER.PRIMITIVES:TRUTHY? (< #2# #1#))
                        (PROGN
                         (LET ((I #2#))
                           (PROGN
                            (WALK TREE)
                            (PROGN
                             (PSETQ #2#
                                      (FOL.COMPILER.ARITHMETIC-FUNCTIONS:INC
                                       #2#))
                             (GO LOOP-1)))))
                        NIL))))
              (RETURN-FROM LOOP-BLOCK-1 RESULT-1))))))))
