Abstract



We present FOL (Functional Object Lisp), a Lisp dialect combining

Clojure’s persistent data structures with CLOS-style object orientation.

Using this combination, we find that persistent objects

and CLOS are not antagonistic but, in fact synergistic. Among other software

capabilities, the combination yields metaobject-protocol-enabled versioned objects, declarative

event sourcing using method combinations, and lazy schema evaluation - patterns

more natural than in either parent alone. Benchmarks show that persistence adds

only 1-3x overhead for sequential modifications. A preliminary transpiler to Common

Lisp with minor optimizations reaches parity with hand-written Common Lisp code. FOL

is written in Common Lisp atop FSet and Sycamore persistent data structure libraries,

providing Clojure-compatible persistent collection objects and a meta-object-protocol

adapted for immutable storage.





Introduction



The first question to answer when writing a new Lisp is "Why write another Lisp?". In the

case of FOL, we wanted to find out if Common Lisp-style objects could co-exist with an immutable object

model as found in Clojure. Each tradition offers distinct strengths: CLOS provides multiple dispatch,

method combinations, and full metaobject

protocol introspection; Clojure provides immutable data structures

with 𝑂(log𝑛) updates and structural sharing.



That immutable objects have many advantages in multi-processing systems is a

well-known fact. Mutation makes it difficult to coordinate multiple threads without conflict and

proper synchronization of these threads across multiple objects is a onerous, labor-intensive, and

quite often an ad-hoc, manual task. Systems based on immutable data structures do not require synchronization

of this kind.



On the other hand, CLOS, with its multiple-inheritance structures

and meta-object protocol (MOP) provides capabilities that other object models do not have. But this object

model is fundamentally based on mutation of object instance's variables. Putting CLOS within the paradigm

of immutability seemed unlikely;

eschewing CLOS's capabilities to gain immutability seemed a high price to pay. In the end, the only way to see if one

could merge the two models was to try.



So why build a new Lisp rather than simply building an add-on library using libraries like FSet or Sycamore (both of

which are used in FOL)? The first two arguments are due to correctness. FOL, by necessity, has some objects

that are not persistent objects - primitives, mutable objects (such as streams, atoms, lazy sequences, etc.), collections

objects that are based on persistent data structures, but do not inherit from a persistent-class, as their slots never change

and, as such, they don't need to be based on persistent objects. Hooking up these elements properly would have made for a difficult

and brittle library system. Another sticking point was that as certain objects required inheritence from CLOS's standard-object, if

this class were exposed by a library system, there would always be the temptation to use this class as a base for some user class -

a land mine of sizable proportion.

Guarantees stemming from limiting user-defined objects to be persistent would evaporate, leading to difficult and brittle

software. The final argument was pragmatic - it was simply easier to package FOL as a fully-functional Lisp, rather than as a library.



Using Common Lisp's MOP, FOL provides immutable CLOS objects. We show that CLOS objects need not be based

on mutable variables, but can instead be based on immutable data structures, where changing variables

provide new copies of the original objects sharing structure with the original object. In doing this, we

also demonstrate that immutability ensures old instances

are never corrupted by class redefinition, and functional

updates transparently produce instances of the new schema

—trading CLOS’s explicit migration hooks for

corruption safety.



We demonstrate that the combination of immutability and CLOS-style objects is synergystic. FOL provides

the following software capabilities:

Automatically versioned objects via persistence and the MOP: Immutability ensures old instances

are never corrupted by class redefinition, and functional

updates transparently produce instances of the new schema

—trading CLOS’s explicit migration hooks for

corruption safety.



Event sourcing via method combinations: :around

methods declaratively intercept all mutations to build im-

mutable event logs, while predicate dispatch routes com-

mands by content. FOL’s :around applies au-

tomatically to all methods; Clojure’s equivalent wrapper

must be invoked explicitly.



FOL also provides enhanced destructuring patterns:

 Multiple patterns in defgeneric

 Multiple patterns in defmethod

 Multiple patterns in functions and macros

 Category-based predicate dispatch that is well-founded



Finally, we provide transpiled benchmarks showing that FOL's persistence adds only 1-3x penalty for sequential object modifications while

providing parity with hand-written Common Lisp versions of these same benchmarks



Language Design

  Core Philosophy



FOL makes several design commitments:



1\) Immutability by default: All objects and collections (ex-

cept streams, atoms, etc.) are persistent—in the sense of

Driscoll et al. \[5], preserving previous versions after modi-

fication, not database persistence

(2) Structural sharing: Updates create new versions sharing

structure with old

(3) Object identity: Distinguishes version identity (eq) from

value equality (=)

(4) Generic functions: Multiple dispatch over destructuring

patterns

(5) Meta-object protocol: Introspection and extension via

adapted MOP protocols



  Identity and Equality



Following Hickey’s epochal time

model \[11], FOL simplifies Common Lisp’s four-level equality hierarchy (eq/eql/equal/equalp) to two levels. eq tests reference

identity—each functional update produces a new object, so (eq

alice older-alice) returns false even when both represent “Al-

ice.” FOL’s = tests value equality via generic dispatch: numbers

compare with numeric coercion, persistent objects compare by

structural comparison of storage maps (using fset:equal?), and

strings compare by content—subsuming the roles of eql, equal,

and equalp. Two independently constructed objects with identical

slot values are = and may be used as map keys (hashing is based on

storage structure, not reference identity).



  Syntax and Readability

FOL adopts Clojure's reader syntax:



\[1 2 3] 		; Vectors

{:name "Alice" :age 30} ; Maps

\#{1 2 3 4}		; Sets



(defn summarize \[{:keys \[(name <string>) (age <number>)]}]

(str name " is " age " years old"))



  Persisten Object Protocol

User-defined classes inherit from <persistent-object>:



(defclass <person> \[<persistent-object>]

\[\[name :type <string>]

\[age :type <number>]])

(def alice (make <person> :name "Alice" :age 30))

(def older-alice (assoc alice :age 31)) ; Returns new instance

(:age alice) ; => 30 (unchanged)

(:age older-alice) ; => 31



defclass supports standard CLOS options (:type, :initarg,

:initform, :reader, :writer). Slot values are stored in a persis-

tent hash map, enabling 𝑂(log𝑛)updates with structural sharing.



  Collection Implementation

FOL wraps FSet and Sycamore data structures for its collections:



• Vectors (\[1 2 3]): 32-way branching trees supporting

𝑂(log32 𝑛)random access

• Maps ({:a 1 :b 2}): Hash array mapped tries (HAMTs)

with efficient key-value operations

• Sets (#{1 2 3}): Weight-balanced binary trees for ordered

iteration

• Lists: Persistent cons cells with standard 𝑂(1)prepend and

𝑂(𝑛)access



FOL also provides thirteen additional collection classes from <array-dict> to <dense-int-set> to <array>.

These collection classes have either been optimized to use the

combinations of FSet and Sycamore data structures that provide the

best performance at both small sizes (< 20 elements) and at scale (> 1000 elements) or have

been hand-written in the case of collections not based on persistent structures (list, lazy-seq).



  Runtime Representations



Most runtime representations in the transpiled code are inherited from the

Common Lisp base. Primitives (like <bool>, <string>, the numeric tower, and <symbol> are unwrapped Common Lisp primitives; functions

with their closures are simply Common Lisp functions. FOL inherits the package structure and error handling model

of Common Lisp. Garbage collection is also

inherited from Common Lisp - old versions of objects are collected when unreferenced;

structural sharing ensures only unshared portions are reclaimed.



  MOP Protocol Adaptation

FOL’s persistent metaclass adapts rather than replaces the MOP.

Table 2 summarizes the protocol disposition.

Introspection protocols (class-slots, class-precedence-list,

slot-definition-\*) work unchanged because FOL’s class structure is standard CLOS—only slot storage is redirected. The validate-superclass

extension permits cross-metaclass inheritance (persistent classes

may inherit from standard classes), but mixed hierarchies must

respect the invariant that persistent slots use FSet or Sycamore storage while inherited standard slots remain mutable—finalization signals an error

if this invariant cannot be maintained. This adaptation requires the

MOP: persistence cannot be implemented as a library because transparent slot access demands slot-value-using-class redirection

at the metaclass level.

