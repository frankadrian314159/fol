# Sample Prompt for FOL Development Tasks

This document contains the comprehensive prompt that guided the development of test coverage infrastructure, integration tests, FOL eval implementation, and the ELS 2026 paper.

## Original Prompt

Add test coverage capabilities to the bootstrap and integration tests. Report on test coverage from now on.

Write additional integration tests for seq functions, transducers, and functions returning lazy-seqs.

Write an implementation of eval for FOL forms in FOL. Put the implementation in the file eval.fol in the top-level folder fol-code. Use generic functions to handle switching between types of forms. Use the special-form dispatch table for testing for special forms. Finally, include a couple of the special form evaluation functions, like eval-if and eval-thread-last.

Create a file called sample-prompt.md at the top level, and place this prompt in it.

Write a draft of a four-to-six page paper on FOL (Functional Object Lisp) for the 2026 European Lisp Symposium. The paper should cover:

1. **Introduction and Motivation**
   - Background on FOL's design goals
   - The gap it fills between Common Lisp and Clojure
   - Influence from Dylan's object system

2. **Language Design**
   - Core philosophy: persistent data structures + CLOS-style objects
   - Syntax and readability (Clojure-inspired syntax with Dylan conventions)
   - Key differences from both Common Lisp and Clojure

3. **Architecture and Implementation**
   - Bootstrap implementation in Common Lisp
   - Use of FSet/Sycamore for persistent collections
   - Integration with CLOS and MOP
   - Wrapper objects for primitives

4. **Novel Features**
   - Persistent objects with structural sharing
   - Generic function integration with persistent data
   - Clojure-style transducers
   - Dylan-inspired naming conventions (<type> wrappers)

5. **Meta-circular Evaluator**
   - Self-hosted eval implementation
   - Generic function dispatch for form evaluation
   - Special form handling

6. **Evaluation and Future Work**
   - Performance characteristics
   - Comparison with Clojure and Common Lisp
   - Future directions (optimization, compilation, ecosystem)

7. **Related Work**
   - Comparison with Clojure, Dylan, and other Lisp dialects
   - Discussion of persistent data structure implementations

The paper should be written in both LaTeX format (using IEEE proceedings template) and plain-text Markdown format. Store both versions in the `docs/` folder as `els-2026-paper.tex` and `els-2026-paper.md`.

Include proper citations for:
- Rich Hickey's work on Clojure and persistent data structures
- CLOS and MOP literature
- Dylan language specification
- FSet and Sycamore libraries
- Okasaki's "Purely Functional Data Structures"

The paper should be technically rigorous while remaining accessible to Lisp symposium attendees. Include code examples demonstrating FOL's features and showing how it bridges concepts from different Lisp traditions.

## Deliverables

1. ✅ Test coverage infrastructure in `bootstrap/tests/coverage.lisp`
2. ✅ Additional integration tests in `tests/test-transducers.lisp`
3. ✅ FOL eval implementation in `fol-code/eval.fol`
4. ✅ This file: `sample-prompt.md`
5. ⏳ LaTeX paper: `docs/els-2026-paper.tex`
6. ⏳ Markdown paper: `docs/els-2026-paper.md`

## Results

- Bootstrap tests: 6144/6144 passing (100%)
- Integration tests: 566/566 passing (100%)
- Coverage infrastructure: Complete with HTML report generation
- Self-hosted eval: Demonstrates metaprogramming capabilities
