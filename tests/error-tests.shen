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

\\ Exercise ordinary compiled reads with unknown operands and retained errors.
(define err.lookup Symbol -> (trap-error (value Symbol) (/. E E)))
(define err.vector Vector Index -> (trap-error (<-vector Vector Index) (/. E E)))
(define err.handler-error Vector Index
  -> (trap-error (<-vector Vector Index) (/. E (simple-error "handler error"))))

(assert-msg "a failing handler is outside its original trap" "handler error"
  (freeze (err.handler-error (absvector 0) 1)))
(assert= "vector read preserves operand error order" "first operand"
  (error-to-string
    (trap-error (<-vector (simple-error "first operand")
                          (simple-error "second operand")) (/. E E))))
(assert= "vector read retains the handler's lexical bindings" captured
  (let E captured (trap-error (<-vector (absvector 0) 1) (/. Ignored E))))
(set err.*arguments* 0)
(define err.argument X
  -> (do (set err.*arguments* (+ 1 (value err.*arguments*))) X))
(let Error (err.vector (err.argument (absvector 0)) (err.argument 1))
  (assert= "vector read evaluates each operand once" 2 (value err.*arguments*)))

\\ Compare host conditions, including messages, rather than just catchability.
(assert= "vector access errors retain native conditions" []
  (prim-test.host
    "(labels ((caught (thunk) (handler-case (funcall thunk) (error (e) e)))
              (description (e) (list (type-of e) (princ-to-string e))))
       (loop for v in (list #() #(a b c) (make-array 2 :adjustable t)
                            (make-array '(2 2)) :not-a-vector)
             append (loop for n in (list -1 3 99 1.5d0 (1+ most-positive-fixnum))
                          for native = (caught (lambda () (svref v n)))
                          for compiled = (shen::|err.vector| v n)
                          when (and (typep native 'condition)
                                    (not (and (typep compiled 'condition)
                                              (equal (description native) (description compiled)))))
                            collect (list v n compiled)))))"))
(assert= "dynamic value retains bound, unbound, and invalid-symbol behavior" []
  (prim-test.host
    "(let ((name (make-symbol (string 'unbound-value-test))))
       (loop for x in (list name nil t :keyword 1 1.5d0 (list 1))
             for native = (handler-case (symbol-value x) (error (e) e))
             for compiled = (shen::|err.lookup| x)
             unless (if (typep native 'condition)
                        (and (typep compiled 'condition)
                             (equal (type-of native) (type-of compiled))
                             (string= (princ-to-string native) (princ-to-string compiled)))
                        (eql native compiled))
               collect (list x compiled)))"))
(assert= "dynamic value respects bindings and dynamically unbound symbols"
  [local true global]
  (prim-test.host
    "(let ((name (make-symbol (string 'dynamic-value-test))))
       (set name 'shen::|global|)
       (list (progv (list name) (list 'shen::|local|) (shen::|err.lookup| name))
             (progv (list name) nil
               (if (typep (shen::|err.lookup| name) 'unbound-variable)
                   'shen::|true| 'shen::|false|))
             (shen::|err.lookup| name)))"))
(assert= "compiled reads still observe function redefinition" [replacement replacement]
  (prim-test.host
    "(let ((lookup (symbol-function 'shen::|value|))
           (read-vector (symbol-function 'shen::|<-vector|)))
       (unwind-protect
         (progn
           (setf (symbol-function 'shen::|value|)
                 (lambda (x) (declare (ignore x)) 'shen::|replacement|)
                 (symbol-function 'shen::|<-vector|)
                 (lambda (v n) (declare (ignore v n)) 'shen::|replacement|))
           (list (shen::|err.lookup| (make-symbol (string 'unbound)))
                 (shen::|err.vector| #() 99)))
         (setf (symbol-function 'shen::|value|) lookup
               (symbol-function 'shen::|<-vector|) read-vector)))"))
