\* Copyright (c) 2026 shen-cl port authors.                          *\
\* BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause *\

\\ Driver for the port-authored RUNTIME test suite (distinct from the canonical
\\ kernel certification suite and from the KL->Lisp compiler-output tests).
\\ Loads the shared harness, then every tests/*-tests.shen runtime file, then
\\ reports a pass/fail tally and exits non-zero on any failure.
\\
\\ Run on the reference SBCL build via `make test-port`:
\\   bin/sbcl/shen eval -l scripts/run-port-tests.shen
\\
\\ We set *hush* true so load's per-form echo does not flood the pipe (on the
\\ CLISP build a flooded pipe can race (cl.exit) and yield a spurious non-zero
\\ exit). assert= is silent on success; the io suite toggles *hush* locally
\\ around its pr-to-file probes; and port-test-report clears *hush* before it
\\ prints the summary and exits, so the result is deterministic on SBCL, CLISP
\\ and ECL whether or not the CLI -q flag is also passed.

(set *hush* true)

(load "tests/test-harness.shen")
(load "tests/primitives-tests.shen")
(load "tests/io-tests.shen")
(load "tests/error-tests.shen")
(load "tests/reader-tests.shen")
(load "tests/library-tests.shen")

(port-test-report "port runtime tests")
