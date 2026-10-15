# SBCL optimizations

Shen CL reduces overhead when translating KLambda to Common Lisp and when
implementing frequently used kernel operations. Ordinary function calls retain
interactive redefinition; selected primitives have direct translations or
inline implementations. Most of the compiler transformations are shared with
the other Common Lisp targets.

The main implementation points are [the compiler](../src/compiler.shen),
[host primitives](../src/primitives.lsp), [kernel overrides](../src/overwrite.lsp),
[the dictionary backend](../src/dictionaries.lsp), and [the build](../boot.lsp).

## Direct code generation

Predicates such as `cons?`, `number?`, `string?`, and `empty?` compile to Common
Lisp tests. Vector, integer, Boolean, and Prolog-variable predicates use small
host helpers. A predicate used as a value still produces Shen's `true` or
`false` symbols. In a condition, the compiler can use the host Boolean directly
and avoid converting it to a Shen Boolean and immediately testing it again.

Boolean simplification follows the result of `let`, `do`, and conditional
expressions. For example, the test in this function can use `numberp` directly:

```shen
(define classify
  X -> (if (let Y X (number? Y)) number other))
```

Unknown Boolean expressions still receive Shen's strict Boolean check. The
transformation preserves evaluation order, short-circuiting, and errors for
non-Boolean conditions.

Equality with a known literal uses the corresponding host operation:

| Known operand | Generated test | Required semantics |
|---|---|---|
| Empty list | `null` | Only the empty list matches. |
| Symbol or Boolean | `eq` | Symbol identity. |
| Number | Inlined numeric test | Integer equality, then numeric equality across representations. |
| String | `equal` | Case-sensitive string contents. |
| Neither operand known | `shen-cl.absequal` | General Shen equality. |

Literal global `set` uses a local `special` declaration around the store, so
SBCL can assign the known variable directly. The value expression is evaluated
once outside that declaration; its lexical bindings and captured values keep
their scope. Globals are not proclaimed special across compilation, and host
dynamic bindings remain observable. Dynamic symbol names retain runtime `set`.
Both paths return the assigned value. A literal `intern` is resolved during
compilation, and `thaw` becomes a zero-argument `funcall`.

## Checked primitive inlining

Small arithmetic, string, and address primitives are declared inline so SBCL
can optimize them together with their callers. Predicate helper definitions
are available before the generated kernel is compiled; an inline declaration
without its body at that point would not provide the same opportunity.

Arithmetic helpers branch on fixnum and double-float inputs, giving SBCL enough
type information to emit integer and floating-point instructions. Fixnum results
remain unrestricted integers, so overflow promotes to bignums; floating-point
errors remain catchable. Other inputs retain the general numeric path.
The existing increment/decrement translations use the same input guard while
preserving their general-number behavior. Numeric normalization returns integers
and existing double floats directly; it converts other accepted representations
to double precision. Avoiding conversion of an existing double float also avoids
boxing another copy of it.

Literal numeric equality uses `eql` when both operands are integers and `=` for
other numeric representations. The literal operand lets inlining eliminate
irrelevant tests. Non-numbers still fail the match, and each operand is evaluated
once. The internal strict Boolean helper is also inline, retaining its error
branch while avoiding a call for ordinary conditions.

`pos` and `n->string` construct a fresh string of length one directly after
validating their inputs. This exposes the known result size to SBCL and avoids
the generic string-designator conversion. Each call returns an independent
string, including for NUL and non-ASCII characters.

Inlining retains the implementations' numeric conversions and checks. The
build uses Lisp safety 3. Numbers remain general numbers: bignums and floats
must continue to work, and `integer?` accepts integral floats. Vector bounds,
string access, and the abstract-vector allocation limit retain their checks.
Inlining is not permission to replace those operations with unchecked fixnum
or array access.

## Pattern matching and accessor reuse

There are two separate factorisation layers. The S-kernel's `(factorise +)`
option factors recognisers and selectors while producing KLambda. It represents
shared fallbacks as `let`-bound `freeze` expressions invoked through `thaw`.
The compiler lowers `thaw` to `funcall`, and `freeze` expands to a Lisp lambda,
so SBCL can see the complete lexical structure. Non-escaping continuations can
become direct branches or local calls without heap-allocated closures, including
when they capture values. Thunks that escape retain ordinary closure semantics.

Kernel factorisation defaults to off for ordinary source definitions; it works
through ordinary `eval-kl` compilation. The released kernel
KLambda itself contains already-factorised functions. The kernel factoriser can
also share repeated guard expressions, so enabling it can reduce how often an
effectful guard runs. The backend preserves that generated control flow.
A `freeze` in generated code does not by itself establish a runtime allocation
problem: inspect the compiled code and allocations before adding a backend
transformation. Keep fallback bodies shared, preserve tail positions and lexical
bindings, and leave errors deferred until the corresponding thunk is called.

The legacy backend pass, controlled by `shen-cl.*factorise-patterns*` and enabled
by default, handles definitions whose body is still a `cond`. It groups
consecutive clauses with a common stable test on a function parameter, emits
the remaining clauses once, and reaches them through `tagbody`/`go` joins.
Shared tests are limited to type tests and equality with numeric or symbol
literals. User guards and tests of mutable contents must be evaluated again
for each attempted clause; functions with Lisp escapes are left alone because
those escapes can reassign parameters. The pass remains useful for
unfactored source definitions and is independent of the kernel option. The
joins control generated code size and compiler work while preserving clause
order and results; duplicating the fallback tree would defeat that purpose.

The accessor pass binds repeated `car`/`cdr` steps to function-local temporaries.
This reduces repeated list traversal and the size of the selector expressions
SBCL must compile. The pass runs on definitions compiled through `eval-kl`
and the build's copies of generated kernel/StLib Lisp. It
leaves the kernel distribution and precompiled source files unchanged.

Cache reuse depends on where an accessor was actually evaluated and whether
its input can have changed:

- Only lexical roots and previously bound selector temporaries are cached.
- Short-circuit guards establish bindings only on paths that evaluate them.
- Writes and calls outside the known-pure primitive set invalidate the cache.
- Conditional joins, scope exits, and control transfers are conservative.
- Closure bodies are left untouched; they can run later with different inputs.

For example, the final selector here must read the changed cons:

```lisp
(progn (car x) (rplaca x 42) (car x))
```

An unknown user function can perform the same mutation, including after
interactive redefinition. Marking ordinary user functions pure merely because
their current definitions look harmless would make selector reuse unsound.
See [the accessor tests](../tests/accessor-tests.lsp) and
[pattern tests](../tests/pattern-tests.shen) when modifying these passes.

Lexical `let` bindings are useful when they expose information the host compiler
is missing. SBCL can also propagate guarded types through assigned temporaries.
Compare generated code, compilation cost, and complete workloads before adding
another binding transformation; changing the Lisp's shape alone is insufficient.

## Equality, dictionaries, and symbol strings

General equality first checks object identity, avoiding a recursive walk when
both operands are the same object. Other operands retain structural comparison,
case-sensitive strings, and numeric equality. Strings remain distinct from
non-string vectors.

Fixnum comparisons use `eql` directly. Comparisons with other numeric
representations retain numeric `=`, including integer/float equivalence.
Distinct symbols need no call to Common Lisp `equal`: the earlier identity
test has already ruled out equality. This rejection follows the numeric and
structural cases, preserving their existing dispatch paths.

Dispatch then follows the first operand's type. A failed list comparison returns
immediately; falling through to Common Lisp `equal` would repeat the failed
structural comparison.

Vector equality uses a checked index loop with bounds obtained from the vector
lengths. This exposes the index's integer range and avoids recursive helper
calls and general arithmetic for the counter. Elements retain general Shen
equality, including numeric equality across representations; specialized and
adjustable host vectors retain checked access.
Ordinary Shen vectors take a simple-vector path, allowing SBCL to generate
checked slot loads directly. Identical elements avoid the general equality call;
distinct elements retain its numeric and structural comparisons. Other host
vectors use the general array path.

The host `tuple?` override checks simple vectors directly for the `shen.tuple`
marker. Empty vectors fail the test; other host arrays take the kernel's checked
address path. The predicate remains a global function, so already compiled
callers observe redefinition and changes to the marker slot.

SBCL dictionaries use a custom hash-table test matching Shen equality. Equal
list/vector keys and numerically equal keys such as `1` and `1.0` must select
the same bucket. Atomic keys avoid the structural traversal; compound hashing
uses a bounded iterative traversal. A bounded hash may produce collisions,
which equality resolves. The public kernel `hash` function is separate from
this dictionary implementation.

These semantics impose more work than an EQL-only table for simple keys.
Optimizations to dictionary lookup must preserve structural key lookup,
case-sensitive strings, numeric equivalence, and the distinction between a
stored empty list and a missing entry.

Symbol escaping and decoding return the original string when no transformation
is needed. Strings containing escape characters or encoded markers take the
normal conversion path. Avoiding intermediate strings reduces allocation in
reading and symbol handling without changing the escape format.
Names shorter than the shortest encoded marker skip the marker searches
entirely. The bound comes from the escape format; partial markers remain
unchanged, while complete markers still take the normal decoder path.
Symbol validation scans the resulting string directly rather than using generic
sequence mapping, and classifies each character once. It retains Common Lisp's
Unicode-aware alphanumeric tests, the mutable punctuation list, and replaceable
global bindings for `symbol?`, `str`, and `shen.analyse-symbol?`.

The reader's `shen.misc?` punctuation classifier also avoids constructing a
list on each call. Integer inputs use a fixed set of character codes; other
numbers use numeric equality against that set, preserving integral floats and
complex representations. The function retains its global binding, so compiled
reader code observes interactive redefinition. This is a specific host override;
ordinary mutable Shen lists are not shared or hoisted by the compiler.

## Function bindings and compilation boundaries

Prolog variables are constructed directly as fresh two-slot host vectors, with
the kernel's marker and ticket. This avoids initializing an abstract vector
and then replacing both slots. The representation, mutable slots, binding and
unwinding behavior, and replaceable constructor binding remain the same.

The normal build explicitly disables SBCL block compilation. Calls between
kernel functions retain global bindings, allowing redefinition and reaching
host overrides installed after the kernel loads. Giving a block-compiled
function a global entry point does not make calls inside that block follow
later redefinitions of its callees.

## Useful next steps

1. **Prolog and typechecker allocation.** `shen.prolog-vector` allocates a fresh
   vector sized by `shen.*prolog-memory*` during query setup. Profile vector
   initialization separately from proof search. Checked growth or carefully
   reset reuse could reduce allocation, but must preserve capacity behavior,
   independent queries, nested calls, and binding/unwinding semantics.
2. **Dictionary overhead.** Separate the cost of custom hash/equality callbacks
   from compound-key traversal. Focus on common atomic and property-store keys
   before adding another representation. Any specialization must still handle
   mixed numeric representations and structural keys correctly.
3. **Closures and partial application.** Profile closure creation and dispatch,
   particularly immediately called closures and known-arity calls. Further
   simplification must preserve evaluation order, callable metadata, and
   interactive redefinition. Check which allocations survive SBCL's existing
   treatment of lexical continuations before introducing a new lowering pass.
4. **Typed arithmetic.** Investigate using kernel type annotations to expose
   more information to SBCL through ordinary compilation. Keep general
   arithmetic as the fallback; specializing a path must not reject valid
   bignums or floats or weaken error handling.

## Evaluating changes

Use focused workloads to check the intended mechanism and complete programs to
check its practical value. Include parsing, pattern-heavy code, dictionaries,
Prolog/typechecking, and compiler or interpreter workloads as appropriate.
Compare the same SBCL and kernel versions. Load, compile, and warm up before
timing runtime work; measure process startup separately. Record CPU runtime
and allocation independently, and check that the compared programs produce
the same results.

Keep gains that repeat beyond measurement noise and justify their maintenance
cost. Correctness fixes may carry a performance cost; replacing them requires
preserving the same behavior.

Run `make test-all` after compiler or runtime changes. In particular, preserve
[port behavior](../tests/kernel-upgrade-tests.shen), mutation-safe accessors,
pattern fallthrough, and interactive redefinition.
