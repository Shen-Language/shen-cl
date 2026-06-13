\* Copyright (c) 2026 shen-cl port authors.                          *\
\* BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause *\

\\ Port-authored primitive regression suite. Mirrors shen-go's
\\ kl/primitives_test.go + kl/primitives_coverage_test.go: ~50+ primitives
\\ driven through ordinary evaluation -- arithmetic (incl. float comparisons),
\\ string ops, symbols/globals, cons/hd/tl, absvector (incl. uninitialised and
\\ out-of-range slots), type predicates, and get-time.
\\
\\ Loaded after tests/test-harness.shen by scripts/run-port-tests.shen.

\\ --- arithmetic (integer + float) ---
(assert= "add int" 8 (+ 5 3))
(assert= "subtract int" 2 (- 5 3))
(assert= "multiply int" 42 (* 6 7))
(assert= "divide whole" 5 (/ 20 4))
(assert= "divide fractional" 3.5 (/ 7 2))
(assert= "subtract float" 3.5 (- 5.5 2.0))
(assert= "multiply float" 4.5 (* 1.5 3.0))

\\ float comparisons (mirrors shen-go's float comparison coverage)
(assert-true  "gt float true"  (> 3.5 2.0))
(assert-false "gt float false" (> 2.0 3.5))
(assert-true  "lt float true"  (< 2.0 3.5))
(assert-true  "ge float eq"    (>= 2.0 2.0))
(assert-true  "le float eq"    (<= 2.0 2.0))
(assert-true  "ge int"         (>= 5 3))
(assert-false "le int false"   (<= 5 3))

\\ --- list ops: cons / hd / tl ---
(assert= "hd"          1     (hd (cons 1 (cons 2 ()))))
(assert= "tl"          [2]   (tl (cons 1 (cons 2 ()))))
(assert= "cons builds" [1 2] (cons 1 (cons 2 ())))
\\ DIVERGENCE from shen-go: shen-go's (hd ())/(tl ()) RAISE "head/tail of nil".
\\ shen-cl's kernel hd/tl of the empty list return [] (no error). Lock in the
\\ shen-cl behaviour rather than fake parity.
(assert= "hd of empty is []" [] (hd ()))
(assert= "tl of empty is []" [] (tl ()))

\\ --- type predicates ---
(assert-true  "number? yes"    (number? 42))
(assert-false "number? no"     (number? foo))
(assert-true  "string? yes"    (string? "hi"))
(assert-false "string? no"     (string? 1))
(assert-true  "symbol? yes"    (symbol? hello))
(assert-false "symbol? no"     (symbol? 1))
(assert-true  "variable? upper" (variable? X))
(assert-false "variable? lower" (variable? x))
(assert-true  "cons? yes"      (cons? (cons 1 ())))
(assert-false "cons? no"       (cons? 1))
(assert-true  "absvector? yes" (absvector? (absvector 3)))
(assert-false "absvector? no"  (absvector? 1))
(assert-true  "empty? yes"     (empty? ()))
(assert-false "empty? no"      (empty? (cons 1 ())))
(assert-true  "tuple? yes"     (tuple? (@p 1 2)))
(assert-false "boolean? num"   (boolean? 1))
(assert-true  "boolean? true"  (boolean? true))

\\ --- string ops ---
(assert= "string->n"  65      (string->n "A"))
(assert= "n->string"  "A"     (n->string 65))
(assert= "cn"         "foobar" (cn "foo" "bar"))
(assert= "@s"         "foobar" (@s "foo" "bar"))
(assert= "tlstr"      "ello"  (tlstr "hello"))
(assert= "pos"        "e"     (pos "hello" 1))
(assert= "str number" "42"    (str 42))
(assert= "str symbol" "foo"   (str foo))

\\ --- symbols / globals: set then value ---
(assert= "set returns value" 99 (set prim-test-global 99))
(assert= "value reads global" 99 (value prim-test-global))
(assert= "intern roundtrip" abc (intern "abc"))

\\ --- absvector: set/get round trip, uninitialised + out-of-range slots ---
(assert= "vector round trip" 7 (<-address (address-> (absvector 3) 1 7) 1))
\\ Uninitialised slot: shen-cl initialises absvector slots to the symbol `fail!`
\\ (the kernel's unfilled-slot marker). Assert that reading an untouched slot
\\ does NOT crash and yields that marker (mirrors shen-go's undefined-slot case).
(assert-no-crash "uninitialised slot no crash"
                 (freeze (<-address (absvector 3) 0)))
(assert= "uninitialised slot is fail!" (fail) (<-address (absvector 3) 0))
\\ Out-of-range read is a catchable error (mirrors shen-go's TestVectorGet).
(assert-caught "vector out-of-range read"
               (freeze (<-address (absvector 3) 9)))

\\ --- logic ---
(assert-false "not true"  (not true))
(assert-true  "not false" (not false))
(assert-true  "and tt"    (and true true))
(assert-false "and tf"    (and true false))
(assert-true  "or ft"     (or false true))
(assert-false "or ff"     (or false false))

\\ --- get-time: both arms return numbers (mirrors shen-go's TestGetTime) ---
(assert-true "get-time run is number" (number? (get-time run)))
(assert-true "get-time unix is number" (number? (get-time unix)))

\\ --- eval-kl (mirrors shen-go's TestEvalKL) ---
(assert= "eval-kl builds + form" 7 (eval-kl (cons + (cons 3 (cons 4 ())))))
