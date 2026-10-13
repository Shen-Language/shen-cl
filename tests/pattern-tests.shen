\* Copyright (c) 2026 shen-cl port authors.                          *\
\* BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause *\

\\ Regression tests for large-literal pattern destructuring (issue: SBCL heap
\\ exhaustion). The kernel's pattern compiler re-derives the full hd/tl
\\ accessor chain for every pattern element, so the emitted test/body code
\\ grows with pattern-size * pattern-depth; before the accessor-chain binding
\\ pass in src/primitives.lsp, SBCL consed ~800MB compiling a ~100-leaf
\\ record pattern and a 16-field pattern like the one below consed ~5.6GB --
\\ both fatal in the default 1GB image. These definitions merely *compiling*
\\ is the primary assertion; the calls then pin down match/fallthrough
\\ behaviour so the binding pass cannot silently alter semantics.

(define port-tests.wide-record
  [record
     [[[109 107 104 102 109 115 119 106] [bytes F0]]
      [[114 105 109 120 121 115 97 121] F1]
      [[104 118 97 111 101 101 120 107] [bytes F2]]
      [[102 105 117 119 116 115 98 100] F3]
      [[122 115 98 110 106 120 103 99] [bytes F4]]
      [[120 108 120 112 101 114 118 97] F5]
      [[100 100 101 119 102 98 105 107] [bytes F6]]
      [[104 116 97 116 115 102 110 122] F7]
      [[98 106 109 101 100 118 99 110] [bytes F8]]
      [[97 118 118 112 109 104 97 99] F9]
      [[101 99 111 120 109 110 114 120] [bytes F10]]
      [[105 114 97 97 117 111 107 102] F11]
      [[101 122 99 119 98 120 118 121] [bytes F12]]
      [[100 118 119 101 110 117 119 120] F13]
      [[99 116 113 110 116 100 104 104] [bytes F14]]
      [[110 108 120 111 118 120 110 122] F15]]] ->
    [ok F0 F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 F13 F14 F15]
  _ -> [error shape])

(define port-tests.deep-spine
  [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[X]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]] -> [ok X]
  _ -> [error shape])

(assert=
  "wide-record: 16-field literal record pattern matches and binds in order"
  [ok 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15]
  (port-tests.wide-record
    [record
     [[[109 107 104 102 109 115 119 106] [bytes 0]]
      [[114 105 109 120 121 115 97 121] 1]
      [[104 118 97 111 101 101 120 107] [bytes 2]]
      [[102 105 117 119 116 115 98 100] 3]
      [[122 115 98 110 106 120 103 99] [bytes 4]]
      [[120 108 120 112 101 114 118 97] 5]
      [[100 100 101 119 102 98 105 107] [bytes 6]]
      [[104 116 97 116 115 102 110 122] 7]
      [[98 106 109 101 100 118 99 110] [bytes 8]]
      [[97 118 118 112 109 104 97 99] 9]
      [[101 99 111 120 109 110 114 120] [bytes 10]]
      [[105 114 97 97 117 111 107 102] 11]
      [[101 122 99 119 98 120 118 121] [bytes 12]]
      [[100 118 119 101 110 117 119 120] 13]
      [[99 116 113 110 116 100 104 104] [bytes 14]]
      [[110 108 120 111 118 120 110 122] 15]]]))

(assert=
  "wide-record: near-miss falls through to the default rule"
  [error shape]
  (port-tests.wide-record [record nope]))

(assert=
  "wide-record: atom falls through to the default rule"
  [error shape]
  (port-tests.wide-record 0))

(assert=
  "deep-spine: 40-deep nested list pattern matches"
  [ok deep-payload]
  (port-tests.deep-spine [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[deep-payload]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]))

(assert=
  "deep-spine: shallower value falls through"
  [error shape]
  (port-tests.deep-spine [[nope]]))

\\ Regression tests for the pattern factoriser's fallthrough emission
\\ (shen-cl.factorise-cases, src/overwrite.lsp). It groups consecutive
\\ clauses sharing a first test; the remaining clauses are needed both
\\ when the shared test fails and when it matches but no sub-test does.
\\ They used to be spliced into BOTH paths, compounding across groups:
\\ generated code grew 2^groups, and a function like the one below with
\\ 16+ two-clause groups exhausted SBCL's 1GB heap inside COMPILE. The
\\ fallthrough is now emitted once as a tagbody label both paths GO to,
\\ so this function *compiling at all* is the primary assertion; the
\\ calls pin dispatch order and both fallthrough paths.

(define port-tests.grouped-dispatch
  g1 a -> 1
  g1 b -> 2
  g2 a -> 3
  g2 b -> 4
  g3 a -> 5
  g3 b -> 6
  g4 a -> 7
  g4 b -> 8
  g5 a -> 9
  g5 b -> 10
  g6 a -> 11
  g6 b -> 12
  g7 a -> 13
  g7 b -> 14
  g8 a -> 15
  g8 b -> 16
  g9 a -> 17
  g9 b -> 18
  g10 a -> 19
  g10 b -> 20
  g11 a -> 21
  g11 b -> 22
  g12 a -> 23
  g12 b -> 24
  g13 a -> 25
  g13 b -> 26
  g14 a -> 27
  g14 b -> 28
  g15 a -> 29
  g15 b -> 30
  g16 a -> 31
  g16 b -> 32
  g17 a -> 33
  g17 b -> 34
  g18 a -> 35
  g18 b -> 36
  g19 a -> 37
  g19 b -> 38
  g20 a -> 39
  g20 b -> 40
  g21 a -> 41
  g21 b -> 42
  g22 a -> 43
  g22 b -> 44
  g23 a -> 45
  g23 b -> 46
  g24 a -> 47
  g24 b -> 48
  _ _ -> 0)

(assert=
  "grouped-dispatch: first clause of the first group"
  1
  (port-tests.grouped-dispatch g1 a))

(assert=
  "grouped-dispatch: second clause of a middle group"
  24
  (port-tests.grouped-dispatch g12 b))

(assert=
  "grouped-dispatch: last group reached through every fallthrough join"
  48
  (port-tests.grouped-dispatch g24 b))

(assert=
  "grouped-dispatch: shared test matches but no sub-test does -> default"
  0
  (port-tests.grouped-dispatch g1 c))

(assert=
  "grouped-dispatch: no shared test matches -> default"
  0
  (port-tests.grouped-dispatch h a))
