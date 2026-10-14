\* Copyright (c) 2026 shen-cl port authors.                          *\
\* BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause *\

\\ Port-authored reader suite. Mirrors shen-go's kl/reader_test.go (well-formed
\\ edge cases) and kl/reader_fuzz_test.go (seeded malformed input must NEVER
\\ crash -- only parse, or raise a catchable error).
\\
\\ Reader entry point is (read-from-string S), which returns the LIST of forms
\\ parsed from S. Several shen-go reader behaviours differ here and are locked
\\ in as the documented shen-cl semantics (see the DIVERGENCE notes). Loaded
\\ after tests/test-harness.shen by run-port-tests.shen.

(define first-form
  S -> (head (read-from-string S)))

\\ Character classification must retain numeric equality, not just fixnum
\\ identity. Compare the whole byte range with the original kernel predicate.
(define reader-test.misc-reference
  X -> (element? X [61 45 42 47 43 95 63 36 33 64 126 46 62 60 38 37 39 35 96]))
(define reader-test.misc-bytes
  256 -> true
  N -> (and (= (shen.misc? N) (reader-test.misc-reference N))
            (reader-test.misc-bytes (+ N 1))))
(assert-true "misc? byte classification" (reader-test.misc-bytes 0))
(assert-true "misc? integral double" (shen.misc? 61.0))
(assert-true "misc? integral single" (shen.misc? (eval-kl [lisp. "61f0"])))
(assert-true "misc? complex equivalent" (shen.misc? (eval-kl [lisp. "#c(61d0 0d0)"])))
(assert-false "misc? fractional number" (shen.misc? 61.5))
(assert-false "misc? non-real number" (shen.misc? (eval-kl [lisp. "#c(61 1)"])))
(assert-false "misc? large integer" (shen.misc? (eval-kl [lisp. "(expt 2 130)"])))
(assert-false "misc? unicode code point" (shen.misc? 955))
(assert-false "misc? symbol" (shen.misc? punctuation))
(assert-false "misc? string" (shen.misc? "="))
(assert-false "misc? list" (shen.misc? [61]))
(assert-false "misc? vector" (shen.misc? (absvector 2)))
(assert-true "misc? redefinition reaches compiled reader"
  (eval-kl [lisp. "(let ((original (symbol-function '|shen.misc?|)) (seen nil))
    (unwind-protect
         (progn
           (setf (symbol-function '|shen.misc?|)
                 (lambda (x) (setf seen t) (funcall original x)))
           (|read-from-string| (symbol-name '|+|))
           (if seen '|true| '|false|))
      (setf (symbol-function '|shen.misc?|) original)))"]))

\\ --- well-formed atoms ---
(assert= "read integer"  42      (first-form "42"))
(assert= "read symbol"   symbol  (first-form "symbol"))
(assert= "read true"     true    (first-form "true"))
(assert= "read false"    false   (first-form "false"))
\\ The argument to read-from-string must itself contain double-quote chars;
\\ the Shen reader has no '\"' escape, so build "\"abc\"" via (n->string 34).
(assert= "read string"   "abc"
         (head (read-from-string (@s (n->string 34) (@s "abc" (n->string 34))))))

\\ --- nested form evaluates correctly after reading ---
(assert= "read+eval nested arithmetic" 7
         (eval (first-form "(+ 1 (* 2 3))")))
(assert= "read+eval nested if" 2
         (eval (first-form "(if false 1 2)")))

\\ DIVERGENCE from shen-go: in shen-go a paren form (a b c) reads as a plain
\\ list. In shen-cl the reader lowers a paren application into the kernel's
\\ CURRIED application AST, so (a b c) reads as [[[fn a] b] c]. Lock that in.
(assert= "paren form is curried application AST"
         [[[fn a] b] c]
         (first-form "(a b c)"))

\\ DIVERGENCE from shen-go: shen-go treats [a b c] as (list a b c). In shen-cl
\\ bracket lists read as the unevaluated nested-cons AST (the documented
\\ bracket-vs-paren gotcha), so [a b] -> [cons a [cons b []]].
(assert= "bracket list is nested-cons AST"
         [cons a [cons b []]]
         (first-form "[a b]"))
\\ ...and that AST, when evaluated, builds the list.
(assert= "bracket list evaluates to a list"
         [1 2 3]
         (eval (first-form "[1 2 3]")))

\\ DIVERGENCE from shen-go: shen-go's extended reader treats ';' as a line
\\ comment. shen-cl uses '\\' for line comments (and ';' is an ordinary
\\ symbol). Lock in BOTH facts.
(assert= "backslash-backslash starts a line comment"
         99
         (first-form "\\\\ a comment line
99"))
(assert= "semicolon is an ordinary symbol"
         ;
         (first-form ";"))

\\ --- seeded malformed-input no-crash contract (mirrors FuzzReaderEval) ---
\\ For each seed, reading (and where parseable, evaluating) must TERMINATE
\\ without taking down the process: a value or a catchable error, never a hard
\\ crash. We probe via assert-no-crash over a frozen read[/eval] thunk.
(assert-no-crash "empty input"        (freeze (read-from-string "")))
(assert-no-crash "lone space"         (freeze (read-from-string " ")))
(assert-no-crash "empty parens"       (freeze (read-from-string "()")))
(assert-no-crash "open paren only"    (freeze (read-from-string "(")))
(assert-no-crash "close paren only"   (freeze (read-from-string ")")))
(assert-no-crash "unbalanced parens"  (freeze (read-from-string "((((")))
(assert-no-crash "unterminated string"
                 (freeze (read-from-string (@s (n->string 34) "unterminated"))))
(assert-no-crash "garbage tokens"     (freeze (read-from-string "garbage !@# %^&")))
(assert-no-crash "lambda underscore param read"
                 (freeze (read-from-string "(/. _ false)")))
(assert-no-crash "dollar form read"   (freeze (read-from-string "($ foo bar)")))
\\ The witness-proofs repro: reading then EVALUATING illegal '_'-param lambda
\\ must still terminate (catchable error, not a crash).
(assert-no-crash "lambda underscore param read+eval"
                 (freeze (eval (first-form "(/. _ false)"))))
\\ DIVERGENCE from shen-go: shen-go's FuzzReaderEval includes
\\ "(absvector 10000000000)" because PrimAbsvector there CAPS the requested
\\ size and raises a catchable error. shen-cl's (absvector N) calls CL's
\\ make-array with no kernel-side cap, so a pathological N is an unrecoverable
\\ heap exhaustion, not a catchable Shen error -- we deliberately do NOT assert
\\ catchability here (asserting it would fake parity and crash the run). A
\\ modest oversize request still reads+evals fine:
(assert-no-crash "modest absvector request"
                 (freeze (eval (first-form "(absvector 1000)"))))
