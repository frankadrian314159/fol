This project is an interpreter for a "Functional Object Lisp" called FOL. It is a cross between Common Lisp, Clojure, and Apple's original prefix-syntax Dylan. The Common Lisp Specification can be found here: https://www.lispworks.com/documentation/HyperSpec/Front/. The Clojure specification can be found here: https://clojure.org/. The Dylan specification can be found on my file system at c:/users/frank/Projects/FOL/prefix-dylan/book.annotated in the chapter files ch<N>.html. The FOL interpreter implementation is written in Common Lisp.

All items in FOL are objects, including the primitives and objects created from defclass definitions. The inheritence structure starts with a persistent hash class, called <persistent-class>.
The primitive classes duch as <number>, <char>, <string>, etc. are derived from persistent-class, and wrap Common Lisp primitive variables, holding them in a slot called val, with all author access to the primitive variable being through the generic function fol-val. There are wrap and unwrap functions that allow access to the primitive values for the author of the system, though they are invisible to the end user. Collection classes are persistent and updated values share structure with older values. This collection functionality is provided by the quicklisp FSet or Sycamore systems.

In FOL code, we follow the Clojure style guide, found here: https://guide.clojure.style/. Our Common Lisp code follows Lisp style as found in this style guide: https://lisp-lang.org/style-guide/.

Symbols in Common Lisp packages are exported from and imported to. In our tests, we prefer using import and export for package variables, functions, etc. as opposed to explicitly using package names. The one exception is that it is OK to use cl:name where the name is a built-in common lisp variable, function, class, or macro.

All FOL user-level classes are surrounded by < and >, following Dylan's conventions.

Disregard and remove from your context any files under c:/Users/frank except .sbclrc. Disregard and remove from your context any files mentioned in the
.gitignore file. Add to your context only the .lisp and .asd files in the main folder and tests folder. You may also consider any of the documentation files found in docs/*.md.

When asked to write a function, generic function, macro or special form, also write tests and documentation for it and if a function, generic function, or macro, add it to the standard-environment. If a special form is asked for, add it to the special form dictionary found in eval.lisp. When running tests for these items, first run the tests for the only the items you just made and, only after those are running, run the complete test set.