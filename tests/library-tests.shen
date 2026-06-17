\* Copyright (c) 2026 shen-cl port authors.                          *\
\* BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause *\

\\ Port-authored stdlib suite. Mirrors shen-go's kl/library_test.go: the
\\ standard list functions (reverse/append/map/element?/...) behave correctly,
\\ including nested-list and empty-list edge cases.
\\
\\ Loaded after tests/test-harness.shen by run-port-tests.shen.

\\ --- reverse (incl. nested + empty, mirroring shen-go's TestReverse) ---
(assert= "reverse list"        [3 2 1]      (reverse [1 2 3]))
(assert= "reverse empty"       []           (reverse []))
(assert= "reverse nested"      [d [b c] a]  (reverse [a [b c] d]))
(assert= "reverse roundtrip"   [1 2 3]      (reverse (reverse [1 2 3])))

\\ --- append ---
(assert= "append two lists"    [1 2 3 4]    (append [1 2] [3 4]))
(assert= "append empty left"   [1]          (append [] [1]))
(assert= "append empty right"  [1]          (append [1] []))

\\ --- map / mapcan ---
(assert= "map square"          [1 4 9]      (map (lambda X (* X X)) [1 2 3]))
(assert= "map empty"           []           (map (lambda X (+ X 1)) []))
(assert= "mapcan flatten"      [1 1 2 2]    (mapcan (lambda X [X X]) [1 2]))

\\ --- element? ---
(assert-true  "element? present" (element? 2 [1 2 3]))
(assert-false "element? absent"  (element? 9 [1 2 3]))
(assert-false "element? in empty" (element? a []))

\\ --- length / nth (1-indexed) ---
(assert= "length"   4 (length [1 2 3 4]))
(assert= "length 0" 0 (length []))
(assert= "nth 1"    a (nth 1 [a b c d]))
(assert= "nth 3"    c (nth 3 [a b c d]))

\\ --- union ---
(assert= "union dedups" [1 2 3 4] (union [1 2 3] [2 3 4]))

\\ --- occurrences ---
(assert= "occurrences" 3 (occurrences 1 [1 2 1 3 1]))

\\ --- tuples: @p / fst / snd ---
(assert= "fst of tuple" 1 (fst (@p 1 2)))
(assert= "snd of tuple" 2 (snd (@p 1 2)))

\\ --- head / tail on a proper list ---
(assert= "head" 1   (head [1 2 3]))
(assert= "tail" [2 3] (tail [1 2 3]))
