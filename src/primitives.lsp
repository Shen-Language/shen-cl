; Copyright (c) 2010-2015, Mark Tarver

; All rights reserved.

; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
; 1. Redistributions of source code must retain the above copyright
;    notice, this list of conditions and the following disclaimer.
; 2. Redistributions in binary form must reproduce the above copyright
;    notice, this list of conditions and the following disclaimer in the
;    documentation and/or other materials provided with the distribution.
; 3. The name of Mark Tarver may not be used to endorse or promote products
;    derived from this software without specific prior written permission.

; THIS SOFTWARE IS PROVIDED BY Mark Tarver ''AS IS'' AND ANY
; EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL Mark Tarver BE LIABLE FOR ANY
; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

(in-package :shen)

(defvar |*stinput*| *standard-input*)
(defvar |*stoutput*| *standard-output*)
(defvar |*sterror*| *error-output*)

;; Bound to T only for the dynamic extent of the REPL (see shen.repl in
;; overwrite.lsp). It lets the input layer (read-byte / shen.read-unit-string)
;; tell the REPL's command input apart from a program's own reads of stdin, so
;; only the former exits on EOF.
(defvar |shen-cl.in-repl?| nil)
(defvar |*language*| "Common Lisp")
(defvar |*port*| "3.0.3")
(defvar |*porters*| "Mark Tarver, Robert Koeninger and Bruno Deferrari")

#+clisp
(progn
  (defvar |*implementation*| "GNU CLisp")
  (defvar |*release*| (let ((V (lisp-implementation-version))) (subseq v 0 (position #\space v :start 0))))
  (defvar |*os*| (or #+win32 "Windows" #+linux "Linux" #+macos "macOS" #+unix "Unix" "Unknown")))

#+ccl
(progn
  (defvar |*implementation*| "Clozure CL")
  (defvar |*release*| (lisp-implementation-version))
  (defvar |*os*| (or #+WINDOWS "Windows" #+linux "Linux" #+DARWIN "macOS" #+unix "Unix" "Unknown")))

#+ecl
(progn
  (defvar |*implementation*| "ECL")
  (defvar |*release*| (lisp-implementation-version))
  (defvar |*os*| (or #+(or :win32 :mingw32) "Windows" #+linux "Linux" #+APPLE "macOS" #+unix "Unix" "Unknown"))
  (setq compiler::*compile-verbose* nil)
  (setq compiler::*suppress-compiler-messages* nil)
  (ext:set-limit 'ext:c-stack (* 1024 1024)))

#+sbcl
(progn
  (defvar |*implementation*| "SBCL")
  (defvar |*release*| (lisp-implementation-version))
  (defvar |*os*| (or #+win32 "Windows" #+linux "Linux" #+DARWIN "macOS" #+unix "Unix" "Unknown"))
  (declaim (inline |write-byte|))
  (declaim (inline |read-byte|))
  (declaim (inline |shen-cl.double-precision|)))

(defmacro |if| (x y z)
  `(let ((*c* ,x))
    (cond
      ((eq *c* '|true|)  ,y)
      ((eq *c* '|false|) ,z)
      (t               (error "~S is not a boolean~%" *c*)))))

(defmacro |and| (x y)
  `(|if| ,x (|if| ,y '|true| '|false|) '|false|))

(defmacro |or| (x y)
  `(|if| ,x '|true| (|if| ,y '|true| '|false|)))

(defun |set| (x y)
  (set x y))

;; Declare only the store special; its value may contain lexical bindings
;; of the same name. Do not proclaim Shen globals special across compilation.
(defmacro |shen-cl.set-global| (symbol expression)
  (let ((value (gensym "VALUE")))
    `(let ((,value ,expression))
       (locally (declare (special ,symbol))
         (setq ,symbol ,value)))))

(defun |value| (x)
  (symbol-value x))

(defun |simple-error| (string)
  (error "~A" string))

(defmacro |trap-error| (x f)
  `(handler-case ,x (error (condition) (funcall ,f condition))))

(defun |error-to-string| (e)
  (if (typep e 'condition)
      (format nil "~A" e)
      (error "~S is not an exception~%" e)))

(defun |cons| (X Y)
  (cons X Y))

(defun |hd| (X)
  (car X))

(defun |tl| (X)
  (cdr X))

(defun |cons?| (X)
  (if (consp X) '|true| '|false|))

(defun |intern| (String)
  (intern (|shen-cl.process-intern| String)))

(defun |shen-cl.process-intern| (S)
  (declare (type string S))
  (let ((len (length S)))
    (if (or (zerop len)
            (not (find-if (lambda (c) (find c "#'`|")) S)))
        S
        (with-output-to-string (out)
          (loop for i from 0 below len
                for c = (char S i)
                do (cond
                     ((char= c #\#) (write-string "_hash1957" out))
                     ((char= c #\') (write-string "_quote1957" out))
                     ((char= c #\`) (write-string "_backquote1957" out))
                     ((char= c #\|) (write-string "bar!1957" out))
                     (t (write-char c out))))))))

;; ---------------------------------------------------------------------------
;; Accessor-chain binding pass (fixes super-linear compile cost of large
;; pattern matches).
;;
;; The kernel's pattern compiler re-derives the full hd/tl accessor chain for
;; every element of a destructured pattern, so kl->lisp emits tests like
;;
;;   (AND (CONSP V) (AND (EQ (CAR V) 'record) (AND (CONSP (CDR V))
;;     (AND (CONSP (CAR (CDR V))) ...))))
;;
;; where each deeper test repeats the whole (CAR (CDR ... V)) spine, and the
;; clause body repeats it again for every bound variable. Generated code size
;; grows with pattern-size * pattern-depth, and the host compiler's cost grows
;; far faster than that: on SBCL a ~100-leaf record pattern (a 12k-node form)
;; consed ~800MB inside COMPILE and exhausted the default 1GB heap.
;;
;; This pass rewrites the kl->lisp output for a defun so that each CAR/CDR
;; step is computed once, bound to a function-local variable via an inline
;; (SETQ acc-var (CAR ...)) at its first occurrence, and referenced thereafter.
;; SETQ returns the assigned value, so evaluation order and results are
;; byte-for-byte identical to the original; a chain is only ever reused at a
;; point that the original would reach after having evaluated the identical
;; (pure, immutable-cons) expression. Reuse is scoped by control flow:
;;
;;   - within (AND t1 t2 ...): bindings made in t_i are visible in t_j, j > i
;;     (t_j only evaluates after t_i was true), and in a COND clause body
;;     guarded by the whole test;
;;   - across conditional joins, bindings do not escape: skipped expressions
;;     may not have assigned them, and completed branches may mutate roots;
;;   - chains are only bound when rooted at a *lexical* variable (defun
;;     params, LET/let vars, or an earlier accessor binding) -- bare special
;;     variable references (from KL [value X]) are never CSE'd since their
;;     value can change between references;
;;   - closure bodies (LAMBDA / |lambda| / |freeze|) are left untouched: a
;;     closure can run more than once (or concurrently) with different
;;     arguments, so caching in a shared function-local would be unsound;
;;   - any form this compiler does not itself emit (macros / special
;;     operators reachable only through lisp. escapes) is left completely
;;     unchanged.
;;
;; EVAL-KL and the build's copies of generated kernel/StLib Lisp use this
;; pass. Writes and calls not known to be pure invalidate accessor bindings.

(defvar shen-cl.*acc-vars* nil)     ; vars allocated for the current defun
(defvar shen-cl.*acc-counter* 0)
(defvar shen-cl.*acc-roots* nil)    ; alist: acc var -> root source symbol

(defun shen-cl.acc-root (base)
  (let ((r (assoc base shen-cl.*acc-roots* :test #'eq)))
    (if r (cdr r) base)))

(defun shen-cl.acc-new-var (base)
  (let ((v (intern (format nil "shen-cl.acc~D" (incf shen-cl.*acc-counter*))
                   :shen)))
    (push v shen-cl.*acc-vars*)
    (push (cons v (shen-cl.acc-root base)) shen-cl.*acc-roots*)
    v))

;; env: alist ((op . base) . var); scope: list of lexical variable symbols.
(defun shen-cl.acc-lookup (op base env)
  (cdr (assoc (cons op base) env :test #'equal)))

(defun shen-cl.acc-shadow (env syms)
  "Drop ENV entries whose chain is rooted at one of SYMS (rebound names)."
  (remove-if (lambda (entry)
               (member (shen-cl.acc-root (cdar entry)) syms :test #'eq))
             env))

(defun shen-cl.acc-pool-var-p (sym)
  (and (symbolp sym) (assoc sym shen-cl.*acc-roots* :test #'eq)))

;; Walks E rewriting accessor chains. Returns three values:
;;   1. the rewritten form,
;;   2. env-always : bindings guaranteed made whenever E finishes evaluating,
;;   3. env-if-true: bindings guaranteed made whenever E evaluated to true.
(defun shen-cl.acc-walk (e env scope)
  (if (atom e)
      (values e env env)
      (let ((head (car e)))
        (cond
          ((or (not (symbolp head))
               (member head '(quote function go declare
                              lambda |lambda| |freeze|)))
           ;; Literals and closures: leave the whole form untouched.
           (values e env env))
          ((member head '(setq setf))
           ;; Host escapes and literal global writes may change a root or
           ;; the conses reachable through it. No previous cache survives.
           (values e nil nil))
          ((eq head 'tagbody)
           ;; (TAGBODY {tag | statement}*), emitted by the pattern
           ;; factoriser's fallthrough join. A statement can also be
           ;; reached via GO from a sibling statement, so bindings made
           ;; in one statement are never guaranteed on entry to another:
           ;; walk each compound statement with an empty cache,
           ;; pass tags (atoms) through, and let nothing escape (GO may
           ;; skip any suffix of a statement, and TAGBODY's value is NIL).
           ;; Within a single statement the usual guarded-reuse rules
           ;; hold: control only enters a statement at its beginning.
           (values (cons 'tagbody
                         (mapcar (lambda (s)
                                   (if (atom s)
                                       s
                                       (multiple-value-bind (s2)
                                           (shen-cl.acc-walk s nil scope)
                                         s2)))
                                 (cdr e)))
                   nil nil))
          ((member head '(car cdr))
           (shen-cl.acc-walk-chain head (second e) env scope))
          ((eq head 'and) (shen-cl.acc-walk-and e env scope))
          ((eq head 'or) (shen-cl.acc-walk-or e env scope))
          ((eq head 'if)
           (multiple-value-bind (c ca ct) (shen-cl.acc-walk (second e) env scope)
             (let ((a (shen-cl.acc-walk (third e) ct scope))
                   (b (if (cddr (cdr e))
                          (shen-cl.acc-walk (fourth e) ca scope)
                          nil)))
               (values (if (cddr (cdr e))
                           (list 'if c a b)
                           (list 'if c a))
                       nil nil))))
          ((eq head 'cond) (shen-cl.acc-walk-cond e env scope))
          ((member head '(let let*)) (shen-cl.acc-walk-let e env scope))
          ((eq head '|let|)           ; (|let| var value body)
           (destructuring-bind (op var value body) e
             (multiple-value-bind (value2 va) (shen-cl.acc-walk value env scope)
               (let ((body2 (shen-cl.acc-walk
                             body
                             (shen-cl.acc-shadow va (list var))
                             (cons var scope))))
                 (values (list op var value2 body2) nil nil)))))
          ((eq head '|if|)            ; (|if| c y z): c always evaluated
           (destructuring-bind (op c y z) e
             (multiple-value-bind (c2 ca) (shen-cl.acc-walk c env scope)
               (values (list op c2
                             (shen-cl.acc-walk y ca scope)
                             (shen-cl.acc-walk z ca scope))
                       nil nil))))
          ((member head '(|and| |or|)) ; (op x y): y conditionally evaluated
           (destructuring-bind (op x y) e
             (multiple-value-bind (x2 xa xt) (shen-cl.acc-walk x env scope)
               (values (list op x2
                             (shen-cl.acc-walk y (if (eq head '|and|) xt xa)
                                               scope))
                       nil nil))))
          ((eq head '|trap-error|)    ; body may unwind mid-way
           (destructuring-bind (op x f) e
             (values (list op
                           (shen-cl.acc-walk x env scope)
                           (shen-cl.acc-walk f env scope))
                     nil nil)))
          ((eq head 'block)           ; (BLOCK name form...): RETURN may skip
           (multiple-value-bind (forms)
               (shen-cl.acc-walk-seq (cddr e) env scope)
             (values (list* 'block (second e) forms) nil nil)))
          ((eq head 'progn)
           (multiple-value-bind (forms env2)
               (shen-cl.acc-walk-seq (cdr e) env scope)
             (values (cons 'progn forms) env2 env2)))
          ((eq head 'return)          ; (RETURN [value])
           (values (if (cdr e)
                       (list 'return (shen-cl.acc-walk (second e) env scope))
                       e)
                   nil nil))
          ((eq head 'return-from)     ; (RETURN-FROM name [value])
           (values (if (cddr e)
                       (list 'return-from (second e)
                             (shen-cl.acc-walk (third e) env scope))
                       e)
                   nil nil))
          ((or (special-operator-p head) (macro-function head))
           ;; Anything else the compiler does not emit (lisp. escapes):
           ;; leave completely unchanged.
           (values e nil nil))
          (t
           ;; Plain function call: arguments all evaluated left-to-right.
           (multiple-value-bind (args env2)
               (shen-cl.acc-walk-seq (cdr e) env scope)
             (let ((after (if (shen-cl.acc-pure-call-p head) env2 nil)))
               (values (cons head args) after after))))))))

(defun shen-cl.acc-pure-call-p (name)
  (member name '(car cdr consp null eq eql equal equalp numberp stringp
                 + - * / > < >= <= not 1+ 1- list list-length cons append reverse
                 |shen-cl.absequal| |shen-cl.equal?| |shen-cl.true?|
                 |shen-cl.numeric-equal| |shen-cl.increment| |shen-cl.decrement|
                 |shen-cl.absvector-p| |shen-cl.integral-p|
                 |shen-cl.boolean-p| |shen-cl.pvar-p|
                 |shen-cl.add| |shen-cl.subtract| |shen-cl.multiply| |shen-cl.divide|)
          :test #'eq))

(defun shen-cl.acc-walk-chain (op arg env scope)
  (multiple-value-bind (arg2 enva) (shen-cl.acc-walk arg env scope)
    (let ((base (cond ((symbolp arg2) arg2)
                      ((and (consp arg2) (eq (car arg2) 'setq)) (second arg2))
                      (t nil))))
      (if (and base
               (or (member base scope :test #'eq)
                   (shen-cl.acc-pool-var-p base)))
          (let ((hit (shen-cl.acc-lookup op base enva)))
            (if hit
                (values hit enva enva)
                (let ((v (shen-cl.acc-new-var base)))
                  (values (list 'setq v (list op arg2))
                          (acons (cons op base) v enva)
                          (acons (cons op base) v enva)))))
          (values (list op arg2) enva enva)))))

(defun shen-cl.acc-walk-and (e env scope)
  ;; arg j evaluates only if args 1..j-1 were true.
  (let ((cur env) (out nil))
    (loop for arg in (cdr e)
          do (multiple-value-bind (a2 aa at) (shen-cl.acc-walk arg cur scope)
               (declare (ignore aa))
               (push a2 out)
               (setf cur at)))
    (values (cons 'and (nreverse out)) nil cur)))

(defun shen-cl.acc-walk-or (e env scope)
  ;; arg j evaluates only if args 1..j-1 were false.
  (let ((cur env) (out nil))
    (loop for arg in (cdr e)
          do (multiple-value-bind (a2 aa) (shen-cl.acc-walk arg cur scope)
               (push a2 out)
               (setf cur aa)))
    (values (cons 'or (nreverse out)) nil nil)))

(defun shen-cl.acc-walk-cond (e env scope)
  ;; test i+1 evaluates only after test i evaluated (to false); a clause body
  ;; evaluates only after its own test was fully true.
  (let ((cur env) (out nil))
    (loop for clause in (cdr e)
          do (multiple-value-bind (t2 ta tt)
                 (shen-cl.acc-walk (car clause) cur scope)
               (multiple-value-bind (body)
                   (shen-cl.acc-walk-seq (cdr clause) tt scope)
                 (push (cons t2 body) out))
               (setf cur ta)))
    (values (cons 'cond (nreverse out)) nil nil)))

(defun shen-cl.acc-walk-let (e env scope)
  (destructuring-bind (op bindings . body) e
    (let ((cur env)
          (inner-scope scope)
          (bound nil)
          (out nil))
      ;; Init forms all evaluate left-to-right for both LET and LET*, so their
      ;; bindings thread; LET* additionally binds (shadows) after each one.
      (dolist (b bindings)
        (let ((var (if (consp b) (car b) b)))
          (if (and (consp b) (cdr b))
              (multiple-value-bind (v2 va)
                  (shen-cl.acc-walk (second b) cur inner-scope)
                (push (list var v2) out)
                (setf cur va))
              (push b out))
          (push var bound)
          (when (eq op 'let*)
            (setf cur (shen-cl.acc-shadow cur (list var)))
            (push var inner-scope))))
      (let* ((body-env (shen-cl.acc-shadow cur bound))
             (body-scope (append bound scope))
             (body2 (multiple-value-bind (forms)
                        (shen-cl.acc-walk-seq body body-env body-scope)
                      forms)))
        ;; Bindings made inside a LET may be rooted at its (now out-of-scope)
        ;; variables, and the body may change outer roots. Nothing escapes.
        (values (list* op (nreverse out) body2) nil nil)))))

(defun shen-cl.acc-walk-seq (forms env scope)
  "Walk FORMS as a left-to-right always-evaluated sequence.
Returns (values rewritten-forms env-after)."
  (let ((cur env) (out nil))
    (dolist (f forms)
      (multiple-value-bind (f2 fa) (shen-cl.acc-walk f cur scope)
        (push f2 out)
        (setf cur fa)))
    (values (nreverse out) cur)))

(defun shen-cl.acc-scan-counter (form)
  "Highest N over symbols named shen-cl.accN in FORM (collision avoidance)."
  (let ((max 0) (stack (list form)) (prefix "shen-cl.acc"))
    (loop while stack
          do (let ((y (pop stack)))
               (cond ((consp y)
                      (push (car y) stack)
                      (push (cdr y) stack))
                     ((symbolp y)
                      (let ((name (symbol-name y)))
                        (when (and (> (length name) (length prefix))
                                   (string= prefix name :end2 (length prefix))
                                   (every #'digit-char-p
                                          (subseq name (length prefix))))
                          (let ((n (parse-integer name
                                                  :start (length prefix))))
                            (when (> n max) (setf max n)))))))))
    max))

(defun shen-cl.bind-accessor-chains (form)
  "Apply the accessor-chain binding pass to a (DEFUN name (params) body) form.
Any other form is returned unchanged."
  (if (and (consp form)
           (eq (car form) 'defun)
           (consp (cdr form))
           (consp (cddr form))
           (listp (third form))
           (every #'symbolp (third form))
           (consp (cdddr form))
           (null (cddddr form)))
      (let ((shen-cl.*acc-vars* nil)
            (shen-cl.*acc-counter* (shen-cl.acc-scan-counter form))
            (shen-cl.*acc-roots* nil))
        (let ((body2 (shen-cl.acc-walk (fourth form) nil (third form))))
          (if shen-cl.*acc-vars*
              (list 'defun (second form) (third form)
                    (list 'let (reverse shen-cl.*acc-vars*) body2))
              form)))
      form))

(defun shen-cl.optimize-generated-file (path)
  "Apply the same accessor pass to precompiled kernel and StLib defuns."
  (let* ((text (with-open-file (in path)
                 (let ((s (make-string (file-length in))))
                   (subseq s 0 (read-sequence s in)))))
         (start (search "(in-package :shen)" text))
         (forms (with-input-from-string (in text)
                  (loop for form = (read in nil :eof)
                        until (eq form :eof)
                        collect (shen-cl.bind-accessor-chains form)))))
    (unless start (error "Missing generated package prelude: ~A" path))
    (with-open-file (out path :direction :output :if-exists :supersede)
      ;; Keep the license comments before the generated package prelude.
      (write-string text out :end start)
      (let ((*print-readably* t) (*print-circle* t) (*print-pretty* nil))
        (dolist (form forms) (write form :stream out) (terpri out))))))

(defun |eval-kl| (X)
  (let ((e (eval (shen-cl.bind-accessor-chains (|shen-cl.kl->lisp| x)))))
    (if (and (consp x) (eq (car x) '|defun|))
      (compile e)
      e)))

(defmacro |lambda| (x y)
  `(function (lambda (,x) ,y)))

(defmacro |let| (x y z)
  `(let ((,x ,y)) ,z))

(defmacro |freeze| (x)
  `(function (lambda () ,x)))

;; Sanity cap on absvector size (Shen issue #3). Without it, (absvector HUGE)
;; asks make-array for an array far larger than the heap, which SBCL reports as
;; an *uncatchable* "Heap exhausted" abort -- trap-error cannot recover from it,
;; so a single bad size takes down the whole image. The cap is ~16.7 million
;; slots (2^24), which is over 800x the largest vector the kernel itself ever
;; allocates (the 20000-slot property dictionary), so it cannot break any
;; legitimate kernel or program use; anything beyond it raises a catchable Shen
;; error instead of crashing. shen-go applies the same kind of cap.
(defconstant |shen-cl.max-absvector-size| (expt 2 24))

;; Elements start as the fail sentinel so that reading an unset slot via
;; <-vector signals "not found", matching the official S41.1 port and
;; Shen/Scheme. (|fail|) is kernel-defined and only called at runtime,
;; after the kernel has loaded.
(defun |absvector| (n)
  (if (and (integerp n) (>= n 0) (<= n |shen-cl.max-absvector-size|))
      (make-array n :initial-element (|fail|))
      (|simple-error|
        (format nil "absvector size ~A out of range (0..~A)~%"
                n |shen-cl.max-absvector-size|))))

(defun |absvector?| (x)
  (if (|shen-cl.absvector-p| x)
     '|true|
     '|false|))

(declaim (inline |shen-cl.absvector-p|))
(defun |shen-cl.absvector-p| (x)
  (and (arrayp x) (not (stringp x))))

;; Open-code the small checked primitives at call sites. Keep validation,
;; double precision conversion, bounds checks, and the absvector size cap.
(declaim (inline |address->| |<-address| |pos| |tlstr| |cn|
                 |n->string| |string->n| |shen-cl.add| |shen-cl.subtract|
                 |shen-cl.multiply| |shen-cl.divide| |shen-cl.increment|
                 |shen-cl.decrement| |shen-cl.numeric-equal| |shen-cl.true?|))

(defun |address->| (vector n value)
  (setf (svref vector n) value)
  vector)

(defun |<-address| (vector n)
  (svref vector n))

(defun |shen-cl.value/or| (var default)
  (if (boundp var)
      (symbol-value var)
      (funcall default)))

(defun |shen-cl.get/or| (var prop dict default)
  (multiple-value-bind (entry found) (|shen-cl.dict-entry| dict var)
    (if found
        (let ((res (assoc prop entry :test #'eq)))
          (if res
              (cdr res)
              (funcall default)))
        (funcall default))))

(defun |shen-cl.<-address/or| (vector n default)
  (if (>= n (length vector))
      (|thaw| default)
      (svref vector n)))

(defun |shen-cl.<-vector/or| (vector n default)
  (if (zerop n)
      (|thaw| default)
      (let ((vectorelement (svref vector n)))
        (if (eq vectorelement (|fail|))
            (|thaw| default)
            vectorelement))))

(defun |shen-cl.equal?| (x y)
  (if (|shen-cl.absequal| x y) '|true| '|false|))

(defun |shen-cl.absequal| (x y)
  (cond
    ((eq x y) t)
    ;; Keep common integer comparisons out of the general numeric dispatcher.
    ;; Other representations still use numeric equality, including 1 and 1.0.
    ((typep x 'fixnum)
     (if (typep y 'fixnum) (eql x y) (and (numberp y) (= x y))))
    ((numberp x) (and (numberp y) (= x y)))
    ((consp x)
     (and (consp y) (|shen-cl.absequal| (car x) (car y))
          (|shen-cl.absequal| (cdr x) (cdr y))))
    ((stringp x) (and (stringp y) (string= x y)))
    ((arrayp x)
     (and (arrayp y) (not (stringp y))
          (cf-vectors x y (length x) (length y))))
    ;; Distinct symbols cannot be structurally equal; identity was checked above.
    ((symbolp x) nil)
    (t
     (equal x y))))

;; Literal numeric equality: integer operands need only EQL. Other numeric
;; representations still compare by value; non-numbers simply do not match.
(defun |shen-cl.numeric-equal| (x y)
  (if (and (integerp x) (integerp y))
      (eql x y)
      (and (numberp x) (numberp y) (= x y))))

(defun cf-vectors (x y lx ly)
  ;; Called after LENGTH has checked both arrays are vectors. Their lengths
  ;; bound the index; elements still use general Shen equality and checked AREF.
  (declare (type vector x y)
           (type (integer 0 #.array-total-size-limit) lx ly))
  (and (= lx ly)
       (if (and (simple-vector-p x) (simple-vector-p y))
           (loop for i of-type fixnum below lx
                 always (let ((a (svref x i)) (b (svref y i)))
                          (or (eq a b) (|shen-cl.absequal| a b))))
           (loop for i of-type fixnum below lx
                 always (|shen-cl.absequal| (aref x i) (aref y i))))))

(defun |write-byte| (byte s)
  (write-byte byte s))

(defun |read-byte| (s)
  (let ((b (read-byte s nil -1)))
    ;; EOF on the REPL's standard input ends the session -> exit cleanly,
    ;; instead of returning -1 and letting the kernel reader loop forever on
    ;; "empty stream". Scoped to the REPL so a program's own stdin reads (and
    ;; all file reads) still see -1 at EOF as the primitive contract requires.
    (if (and (eql b -1) |shen-cl.in-repl?| (eq s |*stinput*|))
        (|cl.exit| 0)
        b)))

(defun |open| (string direction)
  (let ((path (format nil "~A~A" |*home-directory*| string)))
    (|shen.openh| path direction)))

(defun |shen.openh| (path direction)
  (cond
    ((eq direction '|in|)
     (open path
      :direction :input
      :element-type
        #+clisp 'unsigned-byte
        #-clisp :default))
    ((eq direction '|out|)
     (open path
      :direction :output
      :element-type
        #+clisp 'unsigned-byte
        #-clisp :default
      :if-exists :supersede))
    (t
     (error "invalid direction"))))

(defun |type| (x mytype)
  (declare (ignore mytype))
  x)

(defun |close| (stream)
  (close stream)
  nil)

(defun |pos| (x n)
  (cond
    ((not (stringp x))
     (error "~A is not a string~%" x))
    ((or (not (integerp n)) (minusp n) (>= n (length x)))
     (error "~A is not a natural number less than the length of the string~%" n))
    (t (make-string 1 :initial-element (char x n)))))

(defun |tlstr| (x)
  (if (and (stringp x) (plusp (length x)))
      (subseq x 1)
      (error "~S is not a non-empty string~%" x)))

(defun |cn| (str1 str2)
  (declare (type string str1) (type string str2))
  (concatenate 'string str1 str2))

(defun |string?| (s)
  (if (stringp s) '|true| '|false|))

(defun |n->string| (n)
  (let ((c (and (integerp n) (not (minusp n)) (< n char-code-limit) (code-char n))))
    (if c
        (make-string 1 :initial-element c)
        (error "~A is not a natural number~%" n))))

(defun |string->n| (s)
  (if (and (stringp s) (= 1 (length s)))
      (char-code (char s 0))
      (error "~S is not a unit string~%" s)))

(defun |str| (x)
  (cond
    ((null x)      (error "[] is not an atom in Shen; str cannot convert it to a string.~%"))
    ((symbolp x)   (|shen-cl.process-string| (symbol-name x)))
    ((numberp x)   (|shen-cl.process-number| (format nil "~A" x)))
    ((stringp x)   (format nil "~S" x))
    ((streamp x)   (format nil "~A" x))
    ((functionp x) (format nil "~A" x))
    (t             (error "~S is not an atom, stream or closure; str cannot convert it to a string.~%" x))))

(defun |shen-cl.process-number| (S)
  (declare (type string S))
  (let ((len (length S)))
    (if (zerop len)
        ""
        ;; A `for` clause after `while` is non-conforming LOOP syntax:
        ;; CLisp steps the binding before testing `while`, indexing past
        ;; the end. Read the char inside the body instead.
        (with-output-to-string (out)
          (loop with i = 0
                while (< i len)
                do (let ((c (char S i)))
                     (cond
                       ((char= c #\d)
                        (if (and (< (1+ i) len) (char= (char S (1+ i)) #\0))
                            (return "")
                            (progn (write-char #\e out)
                                   (loop for j from (1+ i) below len
                                         do (write-char (char S j) out))
                                   (return))))
                       (t (write-char c out) (incf i)))))))))

(defun |shen-cl.prefix?| (str prefix)
  (let ((prefix-length (length prefix)))
    (and
      (>= (length str) prefix-length)
      (string-equal str prefix :end1 prefix-length))))

(defun |shen-cl.true?| (x)
  (cond
    ((eq '|true| x)  't)
    ((eq '|false| x) ())
    (t (|simple-error| (format nil "boolean expected: not ~A~%" X)))))

(defun |shen-cl.lisp-true?| (X)
  (if X '|true| '|false|))

(defun |shen-cl.lisp-function-name| (symbol)
  (let* ((str (|str| symbol))
         (lispname (string-upcase (substitute #\: #\. (subseq str 5)))))
    (intern lispname)))

(defun |shen-cl.process-string| (x)
  (declare (type string x))
  (let ((len (length x)))
    ;; No encoded marker is shorter than "bar!1957".
    (if (or (< len (length "bar!1957"))
            (not (or (search "_hash1957" x) (search "_quote1957" x)
                     (search "_backquote1957" x) (search "bar!1957" x))))
        x
        (with-output-to-string (out)
          (loop with i = 0
                while (< i len)
                do (cond
                     ((and (<= (+ i 9) len)
                           (string= x "_hash1957" :start1 i :end1 (+ i 9)))
                      (write-char #\# out) (incf i 9))
                     ((and (<= (+ i 10) len)
                           (string= x "_quote1957" :start1 i :end1 (+ i 10)))
                      (write-char #\' out) (incf i 10))
                     ((and (<= (+ i 14) len)
                           (string= x "_backquote1957" :start1 i :end1 (+ i 14)))
                      (write-char #\` out) (incf i 14))
                     ((and (<= (+ i 8) len)
                           (string= x "bar!1957" :start1 i :end1 (+ i 8)))
                      (write-char #\| out) (incf i 8))
                     (t (write-char (char x i) out) (incf i))))))))

(defun |get-time| (time)
  (cond
    ((eq time '|run|)  (* 1.0 (/ (get-internal-run-time) internal-time-units-per-second)))
    ((eq time '|unix|) (- (get-universal-time) 2208988800))
    (t                 (error "get-time does not understand the parameter ~A~%" time))))

(defun |shen-cl.double-precision| (x)
  (if (typep x '(or integer double-float)) x (coerce x 'double-float)))

;; Expose fixnum inputs to the host compiler, without constraining results:
;; Common Lisp arithmetic promotes overflow to bignums. Keep the existing
;; general-number behavior of the compiler's 1+/1- translations.
(defun |shen-cl.increment| (x)
  (if (typep x 'fixnum) (1+ (the fixnum x)) (1+ x)))

(defun |shen-cl.decrement| (x)
  (if (typep x 'fixnum) (1- (the fixnum x)) (1- x)))

(defun |shen-cl.multiply| (x y)
  (cond ((and (typep x 'fixnum) (typep y 'fixnum)) (* x y))
        ((and (typep x 'double-float) (typep y 'double-float))
         (if (or (zerop x) (zerop y)) 0 (* x y)))
        ((or (zerop x) (zerop y)) 0)
        (t (* (|shen-cl.double-precision| x) (|shen-cl.double-precision| y)))))

(defun |shen-cl.add| (x y)
  (cond ((and (typep x 'fixnum) (typep y 'fixnum)) (+ x y))
        ((and (typep x 'double-float) (typep y 'double-float)) (+ x y))
        (t (+ (|shen-cl.double-precision| x) (|shen-cl.double-precision| y)))))

(defun |shen-cl.subtract| (x y)
  (cond ((and (typep x 'fixnum) (typep y 'fixnum)) (- x y))
        ((and (typep x 'double-float) (typep y 'double-float)) (- x y))
        (t (- (|shen-cl.double-precision| x) (|shen-cl.double-precision| y)))))

(defun |shen-cl.divide| (x y)
  (let ((div (/ (|shen-cl.double-precision| x)
                (|shen-cl.double-precision| y))))
    (if (integerp div)
      div
      (* (coerce 1.0 'double-float) div))))

(defun |shen-cl.greater?| (x y)
  (if (> x y) '|true| '|false|))

(defun |shen-cl.less?| (x y)
  (if (< x y) '|true| '|false|))

(defun |shen-cl.greater-than-or-equal-to?| (x y)
  (if (>= x y) '|true| '|false|))

(defun |shen-cl.less-than-or-equal-to?| (x y)
  (if (<= x y) '|true| '|false|))

(defun |number?| (n)
  (if (numberp n) '|true| '|false|))

;; Available before the generated kernel is compiled: SBCL must see the
;; inline bodies then, not just after overwrite.lsp installs public shims.
(declaim (inline |shen-cl.pvar-p| |shen-cl.integral-p| |shen-cl.boolean-p|))

(defun |shen-cl.pvar-p| (x)
  (and (simple-vector-p x) (plusp (length x))
       (eq (svref x 0) '|shen.pvar|)))

(defun |shen-cl.integral-p| (x)
  (or (integerp x) (and (floatp x) (= x (truncate x)))))

(defun |shen-cl.boolean-p| (x)
  (or (eq x '|true|) (eq x '|false|)))

(defun |shen-cl.repl| ()

  #+sbcl
  (handler-case (|shen.repl|)
    (sb-sys:interactive-interrupt ()
      (|cl.exit| 0)))

  #-sbcl
  (|shen.repl|))

(defun |shen-cl.read-eval| (str)
  (car (last (mapc #'|eval| (|read-from-string| str)))))


(defun |shen-cl.toplevel-interpret-args| (args)
  (|trap-error|
    (let ((result (|shen.x.launcher.launch-shen| args)))
      (cond
        ((eq 'error (car result))
         (progn
          (|shen.x.launcher.default-handle-result| result)
          (|cl.exit| 1)))
        ((eq 'unknown-arguments (car result))
         (progn
          (|shen.x.launcher.default-handle-result| result)
          (|cl.exit| 1)))
        (t
         (progn
          (|shen.x.launcher.default-handle-result| result)
          (|cl.exit| 0)))))
    (|lambda| E
      (progn
        (ignore-errors
          (format *error-output* "~%!!! FATAL error: ")
          (|shen.toplevel-display-exception| E)
          (format *error-output* "~%Exiting Shen.~%"))
        (|cl.exit| 1)))))

(defun |shen-cl.toplevel| ()
  (let ((*package* (find-package :shen)))

    #+clisp
    (handler-bind ((warning #'muffle-warning))
      (with-open-stream (*standard-input* (ext:make-stream :input :element-type 'unsigned-byte))
        (with-open-stream (*standard-output* (ext:make-stream :output :element-type 'unsigned-byte))
          (setq |*stoutput*| *standard-output*)
          (setq |*stinput*| *standard-input*)
          (let ((args (cons (car (coerce (ext:argv) 'list)) ext:*args*)))
            (|shen-cl.toplevel-interpret-args| args)))))

    #+ccl
    (handler-bind ((warning #'muffle-warning))
      (|shen-cl.toplevel-interpret-args| *command-line-argument-list*))

    ;; The factorise-defun kernel extension was dropped (its optimization
    ;; is implemented natively in overwrite.lsp), so unlike older releases
    ;; there is no extension initialise call here.
    ;; ECL builds via c:build-program, which links object files rather than
    ;; dumping an image, so it cannot bake the environment that boot.lsp
    ;; builds for SBCL/CLISP. Run the same initialisation sequence here at
    ;; startup instead: shen.initialise (init.kl), the port's registrations,
    ;; the features extension, then stlib.initialise for the precompiled
    ;; standard library (stlib.kl), which every implementation now shares.
    #+ecl
    (progn
     ;; shen-cl.initialise compiles code, which makes ECL load its compiler
     ;; module; keep ECL's ";;; Loading ..." notice off stdout.
     (setq *load-verbose* nil)
     (|shen.initialise|)
     (|shen-cl.initialise|)
     (|shen.x.features.initialise| '(|shen/cl| |shen/cl.ecl|))
     (|stlib.initialise|)
     (|shen-cl.initialise-extensions|)
     (|shen-cl.toplevel-interpret-args| (si:command-args)))

    #+sbcl
    (handler-case
      (|shen-cl.toplevel-interpret-args| sb-ext:*posix-argv*)
      (serious-condition (c)
        (ignore-errors
          (format *error-output* "~&Fatal: ~A~%" c))
        (|cl.exit| 1)))
))
