\* Copyright (c) 2026 shen-cl port authors.                          *\
\* BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause *\

\\ Port-authored error-CATCHABILITY contract. Mirrors shen-go's
\\ kl/error_robustness_test.go: every documented error path must
\\   (1) be catchable via (trap-error ...),
\\   (2) for the stable, implementation-independent messages, surface that
\\       message verbatim, and
\\   (3) leave the interpreter state clean enough that the next eval succeeds.
\\
\\ shen-go pins exact Go-side messages and tests two eval paths (tree-walker +
\\ bytecode VM). shen-cl compiles everything to Common Lisp, so there is no
\\ second eval path to mirror, and the underlying error text for most paths is
\\ CL-specific (e.g. "The variable |X| is unbound."). We therefore assert
\\ CATCHABILITY for the CL-specific paths and pin the verbatim message only for
\\ paths whose text the Shen kernel itself controls (simple-error passthrough,
\\ the unit-string error). This locks in the real contract without faking
\\ message parity. Loaded after tests/test-harness.shen by run-port-tests.shen.

\\ --- (1) every documented error path is catchable ---
(assert-caught "apply unbound symbol"
               (freeze (overflow->str)))
(assert-caught "apply undefined function with args"
               (freeze (undefined-fn-xyz 1)))
(assert-caught "value of unbound variable"
               (freeze (value never-bound-xyz)))
(assert-caught "if requires a boolean"
               (freeze (if 42 1 2)))
(assert-caught "explicit simple-error"
               (freeze (simple-error "boom")))
(assert-caught "arithmetic on non-number"
               (freeze (+ 1 foo)))
(assert-caught "divide by zero"
               (freeze (/ 1 0)))
(assert-caught "string->n of empty string"
               (freeze (string->n "")))
(assert-caught "vector index out of range"
               (freeze (<-address (absvector 3) 99)))

\\ --- (2) stable, kernel-controlled messages surface verbatim ---
(assert-msg "simple-error message passthrough" "boom"
            (freeze (simple-error "boom")))
\\ The unit-string error's text begins with two literal double-quote chars and
\\ (in shen-cl) ends with a trailing newline; build the expected string with
\\ (n->string 34) for the quote and (n->string 10) for the newline since the
\\ Shen reader has no escape for either inside a literal.
(assert-msg "unit-string error message"
            (@s (n->string 34)
                (@s (n->string 34)
                    (@s " is not a unit string" (n->string 10))))
            (freeze (string->n "")))

\\ --- (3) interpreter state stays clean across an adversarial sequence ---
\\ Mirrors shen-go's TestEvalSurvivesAdversarialSequence: drive several errors
\\ in a row, then assert a plain arithmetic form still evaluates correctly.
(define err-survives
  -> (do (trap-error (overflow->str) (lambda E ignore))
         (trap-error (value never-bound-xyz) (lambda E ignore))
         (trap-error (if 42 1 2) (lambda E ignore))
         (trap-error (simple-error "boom") (lambda E ignore))
         (trap-error (undefined-fn-xyz 1) (lambda E ignore))
         (+ 40 2)))

(assert= "eval survives adversarial sequence" 42 (err-survives))

\\ A caught error's handler value is returned (the trap-error result IS an Obj,
\\ not a stray panic payload -- the shen-go SIGSEGV regression analogue).
(assert= "trap-error returns handler value"
         recovered
         (trap-error (overflow->str) (lambda E recovered)))

\\ error-to-string round-trips an explicit error object.
(assert= "error-to-string of simple-error"
         "specific message"
         (error-to-string (trap-error (simple-error "specific message")
                                      (lambda E E))))
