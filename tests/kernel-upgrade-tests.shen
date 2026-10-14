\\ Shen 42.2 integration, numeric predicates, and structural dictionary keys.

(assert= "input+ expands its type as syntax"
  [shen.input-h+ number [stinput]] (macroexpand [input+ number]))

(let Out (open "tests/input-plus.tmp" out)
     Written (pr "42" Out)
     Closed (close Out)
     In (open "tests/input-plus.tmp" in)
     Result ((fn input+) number In)
     Closed (close In)
  (assert= "higher-order input+ reads a final number at EOF" 42 Result))

(assert-true "integer? integral float" (integer? 1.0))
(assert-true "integer? negative integral float" (integer? -17.0))
(assert-true "integer? bignum" (integer? 10000000000000000000000000000))
(assert-false "integer? fractional float" (integer? 1.25))
(assert-false "integer? non-number" (integer? [1]))
(assert-true "boolean? false" (boolean? false))
(assert-false "boolean? empty list" (boolean? []))

(assert-true "pvar? correctly named native predicate"
  (shen.pvar? (address-> (absvector 2) 0 shen.pvar)))
(assert-false "pvar? empty vector" (shen.pvar? (absvector 0)))
(assert-false "pvar? ordinary vector" (shen.pvar? (vector 2)))
(assert-false "pvar? list" (shen.pvar? [shen.pvar]))

(assert-true "tuple? ordinary tuple" (tuple? (@p 1 2)))
(assert-false "tuple? empty vector" (tuple? (absvector 0)))
(assert-false "tuple? ordinary vector" (tuple? (vector 2)))
(assert-false "tuple? list" (tuple? [shen.tuple 1 2]))
(assert-false "tuple? string" (tuple? "shen.tuple"))
(assert-true "tuple? tests the marker without requiring three slots"
  (tuple? (address-> (absvector 1) 0 shen.tuple)))
(let Tuple (@p 1 2)
     Before (tuple? Tuple)
     Changed (address-> Tuple 0 changed)
  (assert= "tuple? sees marker mutation" [true false] [Before (tuple? Tuple)]))

(define port-test.tuple-check X -> (tuple? X))
(define port-test.tuple-branch X -> (if (tuple? X) matched unmatched))
(assert= "tuple callers retain redefinition and strict Boolean checks" [false true]
  (shen-cl.eval-lisp
    "(let ((saved (symbol-function 'shen::|tuple?|)))
       (unwind-protect
         (progn
           (setf (symbol-function 'shen::|tuple?|)
                 (lambda (x) (declare (ignore x)) 'shen::|false|))
           (let ((result (shen::|port-test.tuple-check| (vector 'shen::|shen.tuple| 1 2))))
             (setf (symbol-function 'shen::|tuple?|) (lambda (x) (declare (ignore x)) 42))
             (list result
                   (handler-case
                     (progn (shen::|port-test.tuple-branch| (vector 'shen::|shen.tuple| 1 2))
                            'shen::|false|)
                     (simple-error (e) (declare (ignore e)) 'shen::|true|)))))
         (setf (symbol-function 'shen::|tuple?|) saved)))"))

(assert-true "empty abstract vectors compare equal" (= (absvector 0) (absvector 0)))
(assert-false "unequal vector lengths fail equality" (= (vector 1) (vector 2)))
(assert-true "vector equality retains nested numeric equality"
  (= (@v 1 [2 (@p 3 4)] <>) (@v 1.0 [2.0 (@p 3.0 4.0)] <>)))
(assert-false "vector equality checks the final slot"
  (= (@v 1 2 3 <>) (@v 1 2 4 <>)))
(assert-true "vector equality supports specialized host vectors"
  (shen-cl.eval-lisp
    "(shen::|shen-cl.equal?| (make-array 3 :element-type 'double-float :initial-contents '(1d0 2d0 3d0))
                (vector 1 2 3))"))
(assert-true "vector equality supports adjustable host vectors"
  (shen-cl.eval-lisp
    "(shen::|shen-cl.equal?| (make-array 3 :adjustable t :initial-contents '(1 2 3)) (vector 1 2 3))"))
(assert-false "vector equality stops before a later invalid comparison"
  (shen-cl.eval-lisp
    "(shen::|shen-cl.equal?| (vector 1 (make-array '(2 2))) (vector 2 (make-array '(2 2))))"))
(assert-caught "vector equality retains errors in reached elements"
  (freeze (shen-cl.eval-lisp
    "(shen::|shen-cl.equal?| (vector 1 (make-array '(2 2))) (vector 1 (make-array '(2 2))))")))
(assert-false "tuple? retains empty adjustable vector behavior"
  (shen-cl.eval-lisp "(shen::|tuple?| (make-array 0 :adjustable t))"))
(assert-caught "tuple? retains address type checks on host arrays"
  (freeze (shen-cl.eval-lisp "(shen::|tuple?| (make-array 1 :element-type 'bit :initial-element 0))")))

(assert= "type annotation extension remains callable through fn"
  [defun port-test.annotated [x] [+ [type x number] [type 1 number]]]
  ((fn shen.x.type-annotations.annotate-kl)
    [defun port-test.annotated [x] [+ x 1]]))

(assert-true "numeric equality across representations" (= 1 1.0))
(assert-true "nested numeric equality" (= [1 (@p 2 3)] [1.0 (@p 2.0 3)]))
(assert-false "string equality remains case sensitive" (= "Foo" "foo"))

(let D (shen.dict 8)
     Stored (shen.dict-> D [a [1 2]] payload)
     Replaced (shen.dict-> D [a [1.0 2]] replacement)
     Nil (shen.dict-> D missing-value [])
  (do (assert= "structurally equal list keys" replacement (shen.<-dict D [a [1 2.0]]))
      (assert= "replacement does not add a key" 2 (shen.dict-count D))
      (assert= "stored empty list is not a missing value" [] (shen.<-dict D missing-value))
      (shen.dict-rm D [a [1.0 2.0]])
      (assert= "structural key removal" 1 (shen.dict-count D))))

(let D (shen.dict 8)
     S (shen.dict-> D "Foo" 1)
     S (shen.dict-> D "foo" 2)
     S (shen.dict-> D (@p 1 [2]) 3)
  (do (assert= "case-sensitive dictionary key upper" 1 (shen.<-dict D "Foo"))
      (assert= "case-sensitive dictionary key lower" 2 (shen.<-dict D "foo"))
      (assert= "tuple keys use numeric structural equality" 3 (shen.<-dict D (@p 1.0 [2.0])))
      (assert= "dictionary key count" 3 (length (shen.dict-keys D)))
      (assert= "dictionary folds retain callback order" 6
        (shen.dict-fold (/. K V Acc (+ V Acc)) D 0))))

(assert-caught "dictionary capacity must be positive" (freeze (shen.dict 0)))
(assert-caught "dictionary capacity must be integral" (freeze (shen.dict 1.5)))

\\ Kernel 42.0 invalidates callable metadata through arity changes.
(eval (hd (read-from-string "(define port-test.arity X -> (+ X 1))")))
(assert= "fn before arity change" 42 ((fn port-test.arity) 41))
(eval (hd (read-from-string "(define port-test.arity -> zero)")))
(assert= "fn after zero arity" zero (fn port-test.arity))
(update-lambda-table port-test.arity 0)
(assert= "zero arity removes lambda-form" absent
  (trap-error (get port-test.arity shen.lambda-form) (/. E absent)))
(eval (hd (read-from-string "(define port-test.arity X Y -> (+ X Y))")))
(assert= "fn after binary arity" 42 ((fn port-test.arity) 20 22))
(assert= "partial application after binary arity" 42 ((port-test.arity 20) 22))

(define port-test.helper X -> (+ X 1))
(define port-test.caller X -> (port-test.helper X))
(eval [define port-test.helper X -> [+ X 2]])
(assert= "ordinary callers observe interactive redefinition" 42 (port-test.caller 40))
(eval [define port-test.helper X -> changed])
(assert= "redefinition may change the result representation" changed (port-test.caller 40))

(define port-test.replace-self
  -> (eval (hd (read-from-string "(define port-test.self X -> replaced)"))))
(define port-test.self
  0 -> original
  N -> (do (port-test.replace-self) (port-test.self (- N 1))))
(assert= "in-flight recursion observes redefinition" replaced (port-test.self 2))

(assert= "literal set returns assigned value" 42
  (eval-kl [set port-test.*assigned* 42]))
(assert= "literal set stores global value" 42 (value port-test.*assigned*))
(assert= "boolean through let and do keeps evaluation order" [yes [first second]]
  (let _ (set port-test.*order* [])
    [(if (do (set port-test.*order* [first])
             (let X (do (set port-test.*order* [first second]) 1.0)
               (integer? X))) yes no)
     (value port-test.*order*)]))
(assert-caught "non-boolean through let still errors"
  (freeze (if (let X 42 X) yes no)))
