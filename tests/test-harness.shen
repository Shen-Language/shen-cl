\* Copyright (c) 2026 shen-cl port authors.                          *\
\* BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause *\

\\ Port-authored runtime test harness (DISTINCT from the canonical kernel
\\ certification suite under kernel/tests and from tests/compiler-tests.shen,
\\ which checks KL->Lisp compiler output). This harness drives the *runtime*
\\ behaviour of the built image through ordinary Shen evaluation and tallies
\\ pass/fail, exiting non-zero on any failure so `make test-port` gates CI.
\\
\\ It mirrors, category-for-category, the shen-go port-authored Go test suite
\\ (kl/primitives_*_test.go, io_coverage_test.go, error_robustness_test.go,
\\ reader_*_test.go, library_test.go), translated idiomatically into Shen.

(set *port-test-failures* 0)
(set *port-test-count* 0)

\\ mk-str: best-effort rendering of any value for failure diagnostics.
(define mk-str
  X -> (trap-error (make-string "~R" X) (lambda E "<unprintable>")))

\\ assert= : assert Got equals Expected by value (=).
\\ assert= prints ONLY on failure (so a green run is quiet and `load`'s
\\ form-echo does not bury the final tally); the report prints the totals.
(define assert=
  Label Expected Got
  -> (do (set *port-test-count* (+ 1 (value *port-test-count*)))
         (if (= Expected Got)
             true
             (do (set *port-test-failures* (+ 1 (value *port-test-failures*)))
                 (output "[FAIL]  ~A  expected ~A got ~A~%"
                         Label (mk-str Expected) (mk-str Got))))))

\\ assert-true / assert-false: boolean assertions.
(define assert-true
  Label Got -> (assert= Label true Got))

(define assert-false
  Label Got -> (assert= Label false Got))

\\ assert-caught: run a frozen thunk under trap-error; PASS iff it raised an
\\ error that the handler caught (returns the symbol `caught`). Used for the
\\ error-catchability contract: we assert the error path is *catchable*, not
\\ the exact (implementation-specific) Common Lisp message text.
(define assert-caught
  Label Thunk
  -> (assert= Label caught (trap-error (do (thaw Thunk) not-caught)
                                       (lambda E caught))))

\\ assert-no-crash: run a frozen thunk; PASS iff evaluation TERMINATES without
\\ taking down the process (returns a value OR raises a catchable error). This
\\ is the Shen analogue of shen-go's reader/eval fuzz no-panic contract.
(define assert-no-crash
  Label Thunk
  -> (assert= Label survived (trap-error (do (thaw Thunk) survived)
                                         (lambda E survived))))

\\ assert-msg: assert a caught error's message string equals Expected (for the
\\ stable, implementation-independent messages such as simple-error passthrough).
(define assert-msg
  Label Expected Thunk
  -> (assert= Label Expected (trap-error (do (thaw Thunk) "<<no-error>>")
                                         (lambda E (error-to-string E)))))

\\ Report the tally and exit (0 = green, 1 = any failure). We clear *hush*
\\ first so the summary always prints and the exit code never depends on the
\\ quiet flag's interaction with output on a particular Lisp (CLISP in
\\ particular is sensitive here).
\\ A machine-readable sentinel line is emitted alongside the human summary.
\\ The exit CODE is the primary green/red signal on SBCL (the reference gate),
\\ but the CLISP runtime can intermittently mis-report the exit code when its
\\ buffered console stream races (cl.exit); its SUMMARY TEXT, by contrast, is
\\ emitted reliably. Callers that need a CLISP/ECL parity signal therefore
\\ grep for PORT-TESTS-PASS / PORT-TESTS-FAIL (see scripts/test-cli.sh).
(define port-test-report
  Name -> (let _ (set *hush* false)
               Failures (value *port-test-failures*)
               Total (value *port-test-count*)
            (if (= Failures 0)
                (do (output "~%~A: all ~A assertions passed.~%" Name Total)
                    (output "PORT-TESTS-PASS ~A~%" Total)
                    (cl.exit 0))
                (do (output "~%~A: ~A of ~A assertions FAILED.~%" Name Failures Total)
                    (output "PORT-TESTS-FAIL ~A~%" Failures)
                    (cl.exit 1)))))
