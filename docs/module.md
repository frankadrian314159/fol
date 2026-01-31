# FOL Module System

Modules in FOL provide namespaces for organizing code and managing symbol visibility. They allow you to group related functions and values together, control what is exported to other modules, and import functionality from other modules.

## Overview

A module is a named collection of bindings (symbols mapped to values) with:
- **Local bindings**: The module's own definitions
- **Exports**: Symbols that other modules can import
- **Imports**: Symbols imported from other modules

When looking up a symbol in a module, FOL searches in this order:
1. The module's imports dict
2. The module's local bindings
3. The environment chain (parent environments)

## Standard Modules

FOL provides two standard modules:

### `fol.core`

The core module containing all standard FOL functions, macros, and values. This is automatically loaded as the base environment when starting the REPL or evaluating code.

### `zip`

The zipper module containing functions for navigating and editing tree structures. See [zip.md](zip.md) for details.

## Using Modules

### `(use-module name)`

Imports all exported symbols from the named module into the current module's imports dict.

**Parameters:**
- `name` - A string naming the module to import from

**Example:**
```clojure
;; Import all zipper functions
(use-module "zip")

;; Now zipper functions are available
(def z (vector-zip [1 [2 3] 4]))
(node (down z))  ; => 1
```

**Behavior:**
- Traces up the environment chain to find the nearest enclosing module
- Adds exported symbols from the source module to the target module's imports dict
- Does not modify the current environment's local bindings
- Imported symbols take precedence over the environment chain but not over local bindings

## Creating Modules

### `(module)` or `(module name)`

Creates a new module and adds it to the environment chain. The new module has the current environment as its parent.

**Parameters:**
- `name` (optional) - A string naming the module

**Returns:** The newly created module

**Behavior:**
- If `name` is provided, the module is registered in the global module registry and can be found later with `find-module`
- If `name` is omitted, an anonymous module is created (not registered)
- The new module's parent is set to the current environment
- The module starts with empty local bindings and empty imports

**Example:**
```clojure
;; Create a named module
(def my-mod (module "my-utils"))

;; Create an anonymous module (local scope)
(def local-scope (module))

;; Define something in the new module context
;; (the module becomes the environment for subsequent evaluation)
```

### Implementation-Level Creation

At the implementation level, modules can be created using `make-module`:

```lisp
(make-module "my-module"
  'foo #'foo-function
  'bar #'bar-function)
```

## Exporting Symbols

Symbols must be explicitly exported from a module to be available for import by other modules. The `fol.core` and `zip` modules export all their symbols automatically.

At the implementation level, use `module-export`:

```lisp
(module-export my-module 'symbol-name)
```

## Module Lookup Semantics

When FOL evaluates a symbol reference within a module context:

1. **Check imports**: First, the module's imports dict is searched. This contains symbols that were brought in via `use-module`.

2. **Check local bindings**: If not found in imports, the module's own bindings (items) are searched.

3. **Check environment chain**: If still not found, FOL traverses up the environment chain (parent environments) looking for the binding.

4. **Unbound error**: If the symbol is not found anywhere, an unbound variable error is signaled.

This search order means:
- Local definitions shadow imported symbols
- Imported symbols shadow inherited bindings from parent environments
- You can override imported functionality with local definitions

## Example: Using the Zip Module

```clojure
;; Start with fol.core as the base module
;; Import zipper functionality
(use-module "zip")

;; Create a zipper over a nested vector
(def tree [1 [2 3] [4 [5 6]]])
(def z (vector-zip tree))

;; Navigate the tree
(def z1 (down z))        ; Move to first child
(node z1)                ; => 1

(def z2 (right z1))      ; Move to sibling
(node z2)                ; => [2 3]

;; Edit the tree
(def z3 (-> z2 down (replace 99)))
(root z3)                ; => [1 [99 3] [4 [5 6]]]
```

## Implementation Notes

- Modules inherit from `<env>` (environment) and can be used anywhere an environment is expected
- The imports dict uses the same key normalization as environments (symbol names as uppercase strings)
- Module registration is global - modules are stored in a registry by name
- The `find-module` function retrieves modules from the registry by name
