This project is an interpreter for a "Functional Object Lisp" called FOL. It is a cross between Common Lisp and Clojuren. The Common Lisp Specification can be found here: https://www.lispworks.com/documentation/HyperSpec/Front/. The Clojure specification can be found here: https://clojure.org/. The FOL interpreter implementation is written in Common Lisp.

All items in FOL are objects, including the primitives and objects created from defclass definitions. The inheritence structure starts with a persistent hash class, called <persistent-class>.
The primitive classes duch as <number>, <char>, <string>, etc. are comprised of Common Lisp primitive variables. Collection classes are persistent and updated values share structure with older values. This collection functionality is provided by the quicklisp FSet or Sycamore systems.

In FOL code, we follow the Clojure style guide, found here: https://guide.clojure.style/. Our Common Lisp code follows Lisp style as found in this style guide: https://lisp-lang.org/style-guide/.

Symbols in Common Lisp packages are exported from and imported to. In our tests, we prefer using import and export for package variables, functions, etc. as opposed to explicitly using package names. The one exception is that it is OK to use cl:name where the name is a built-in common lisp variable, function, class, or macro.

All FOL user-level classes are surrounded by < and >, following Apple's original prefix-Dylan's conventions.

Disregard and remove from your context any files under c:/Users/frank except .sbclrc. Disregard and remove from your context any files mentioned in the
.gitignore file. Add to your context only the .lisp and .asd files in the main folder and tests folder. You may also consider any of the documentation files found in docs/*.md.

When asked to write a function, generic function, macro or special form, also write tests for it. If a special form is asked for, add it to the special form dictionary found in compile.lisp and write an AST node for it in ast.lisp. If the function, generic function, or macro name both starts and ends with the character %, do not add the name's documentation to the docs files. Instead, add the documentation to a file at the top-level called INTERNALS.md. When running tests for functions, generic functions, macros or special forms that have been created, first run the tests for the only the items you just made and, only after those are running, run the complete test set.

When fixing tests, do not remove them or simplify them or wrap in error handlers - fix them or find a reason they cannot be fixed.