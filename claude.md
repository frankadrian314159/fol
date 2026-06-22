# Claude Instructions for FOL Project

## Overview

FOL (Functional Object Lisp) is a hybrid Lisp dialect combining persistent data structures, CLOS-style OOP, and array programming. The compiler is written in Common Lisp (SBCL) and transpiles FOL source to CL.

## Key Context

### Build System
- **ASDF**: Main build tool, system defined in `src/fol-compiler.asd`
- **SBCL**: Required Lisp implementation
- **Key components**: src/compiler.lisp, src/package.lisp, src/ast.lisp

### Code Organization
- **src/**: Compiler, runtime, standard library
- **src/tests/**: Test suites using FiveAM framework
- **docs/manual/**: User documentation
- **benchmarks/**: Performance testing

### Testing Requirements
Before committing changes:
```bash
cd src && sbcl --noinform --non-interactive \
  --eval "(push (truename \".\") asdf:*central-registry*)" \
  --eval "(asdf:load-system :fol-compiler/tests)" \
  --eval "(fol.compiler.tests:run-compiler-tests)"
```

All tests must pass (100% baseline).

## Development Workflow

### When Adding Features

1. **Update compiler.lisp** if it's a special form
2. **Add generic operators** in appropriate file (array-functions.lisp, adverbs.lisp, etc.)
3. **Export from package.lisp** - add to package definition
4. **Update ASDF** - add file to fol-compiler.asd if new file
5. **Write tests** in src/tests/test-*.lisp
6. **Run full test suite** - ensure 100% pass rate
7. **Document** in docs/manual/ - update reference files

### Package Architecture

Key packages:
- `fol.compiler.ast` - AST nodes
- `fol.compiler.array-functions` - Vectorized operators
- `fol.compiler.adverbs` - Axis-aware operations
- `fol.compiler.advanced-array-operations` - Shape/slice/transpose
- `fol.core` - User-facing API that imports from all others

**Important**: When adding operators to array-functions or adverbs, update both the implementation package AND the fol.core package imports.

## Code Patterns

### Generic Functions (for operators)

Use CLOS generic dispatch for vectorization:

```lisp
(defgeneric array-op (a b)
  (:documentation "Description here"))

(defmethod array-op ((a number) (b number))
  "Scalar implementation"
  (cl:+ a b))

(defmethod array-op ((a <vector>) (b number))
  "Broadcasting: vector OP scalar"
  (mapv (lambda (x) (array-op x b)) a))
```

Use `mapv` for element-wise operations on vectors (not `cl:map`).

### Reducing Operations

For operations that reduce vectors to scalars, use `cl:reduce` on converted lists:

```lisp
(defun sum-axis (arr axis)
  (let* ((columns (loop for j below (count (get arr 0)) collect j))
         (result (mapv (lambda (j)
                         (cl:reduce #'+ (vec-to-list 
                           (mapv (lambda (i) (get (get arr i) j)) 
                                 (range (count arr))))))
                       columns)))
    result))
```

Helper for conversion:
```lisp
(defun vec-to-list (vec)
  "Convert FOL vector to Common Lisp list"
  (loop for i below (count vec) collect (get vec i)))
```

### Array Indexing

For 2D arrays:
```lisp
(get (get arr i) j)  ; NOT (get arr i j) - use nested get
```

FOL uses column-major layout matching Q/APL semantics.

### Test Patterns

FiveAM test structure:

```lisp
(def-suite my-feature-suite
  :description "Feature description"
  :in compiler-tests)

(in-suite my-feature-suite)

(test my-test-name
  "Test description"
  (let ((result (some-function input)))
    (is (equal expected result))))
```

Always run after test definition:
```lisp
(fiveam:run! 'my-feature-suite)
```

## Common Pitfalls

1. **Shadowing**: Array operators shadow CL operators - use `cl:+`, `cl:-` when needed
2. **Reduce signature**: `fol.compiler.seq-functions:reduce` takes 3 args (fn seq optional-init), not keywords
3. **Vector type**: FOL vectors are `<vector>` class, not CL `#()` vectors - check with `typep arr '<vector>'`
4. **Package exports**: Must update BOTH implementation package AND fol.core imports
5. **Test infrastructure**: Tests must load `compiler-tests-package.lisp` before test files
6. **Cache clearing**: After package changes, clear SBCL cache: `rm -rf ~/.cache/common-lisp/sbcl*`

## Array Programming Phases

### Phase 1: Operators (COMPLETE, 71 tests)
- Vectorized: `+`, `-`, `*`, `/`, comparisons, logical ops
- Broadcasting between scalars and vectors
- Varargs reduction chains

### Phase 1 Extension: N-Dimensional Arrays (COMPLETE, 20+ tests)
- **New functions**:
  - `create-nd-array` - Create n-dimensional arrays with shape and initial values
  - `nd-shape` - Get shape (list of dimensions) of array
  - `nd-rank` - Get rank (number of dimensions) of array
  - `nd-size` - Get total element count
- **Features**:
  - Support for arbitrary dimensions (1D, 2D, 3D, 4D+)
  - Uses existing `<array>` class from collections.lisp
  - Leverages persistent vector infrastructure
  - Full backwards compatibility

### Phase 2: Adverbs (COMPLETE, 50 tests)
- Axis-aware: `fold`, `scan`, `each`, `window`
- Statistics: `sum`, `mean`, `variance`, `std-dev`
- Transforms: `array-reverse`, `map-array`, `zip`
- Partition: `array-partition`, `array-take`, `array-drop`

### Phase 3: Advanced (COMPLETE, 38 tests)
- Reshape, slice, put-slice
- Concatenation, stacking, transposition
- Axis reductions: `sum-axis`, `mean-axis`, `max-axis`, `min-axis`

All phases must remain at 100% test passing.

## Documentation

Update these files when changing public APIs:
- `docs/manual/FOL-MANUAL.md` - Section 22 (Array Programming)
- `docs/manual/array-operations.md` - Phase 1 reference
- `docs/manual/adverbs.md` - Phase 2 reference
- `docs/manual/index.md` - Central index file

Use markdown format with:
- Function signatures in code blocks
- Examples showing input/output
- Cross-references between docs

## Naming Conventions

- **Predicates**: End with `?` (e.g., `nil?`, `vector?`)
- **Mutators**: End with `!` (e.g., `reset!`, `swap!`)
- **Array operations**: Prefix with `array-` to avoid CL shadowing (e.g., `array-reverse`, `array-partition`)
- **Generic functions**: Descriptive names, use dispatch for overloading
- **Helper functions**: Prefix with `_` or `%` if internal (e.g., `%build-vec-t-from-list`)

## Git Workflow

- **Branch naming**: feature/*, bugfix/*, docs/*
- **Commit messages**: "Add X", "Fix Y", "Refactor Z" (reference issues where applicable)
- **Before push**: Run full test suite, update docs if needed
- **No force-push** to main/master without discussion

## When You Get Stuck

1. **Compilation error**: Clear cache (`rm -rf ~/.cache/common-lisp/sbcl*`), check package exports
2. **Type mismatch**: Verify `typep` for `<vector>` vs CL vector vs list
3. **Reduce failures**: Check signature - seq-functions:reduce ≠ cl:reduce keyword behavior
4. **Test failure**: Run individual test suite, check shadowed operators (use `cl:` prefix as needed)
5. **Performance**: Check if using `mapv` instead of `map`, and using `reduce` not `cl:reduce`

## References

- **Main compiler**: src/compiler.lisp (parse-* and emit-* functions)
- **Test runner**: src/tests/compiler-tests-package.lisp
- **Examples**: docs/manual/ for language patterns
- **Paper**: docs/caching/DISPATCH_CACHING_PAPER_v4.md for optimization techniques

---

**Remember**: All 159 tests must pass before committing. No exceptions.
