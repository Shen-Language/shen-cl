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
    (if (zerop len)
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
;;   - across COND clauses, IF branches, OR alternatives, trap-error bodies:
;;     bindings do NOT escape (short-circuiting means they may not have run);
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
;; Only |eval-kl| applies this pass, so precompiled kernel sources
;; (compiled/*.lsp) are byte-identical to before.

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
               (member head '(quote function go declare setq
                              lambda |lambda| |freeze|)))
           ;; Literals and closures: leave the whole form untouched.
           (values e env env))
          ((eq head 'tagbody)
           ;; (TAGBODY {tag | statement}*), emitted by the pattern
           ;; factoriser's fallthrough join. A statement can also be
           ;; reached via GO from a sibling statement, so bindings made
           ;; in one statement are never guaranteed on entry to another:
           ;; walk each compound statement with the tagbody's entry env,
           ;; pass tags (atoms) through, and let nothing escape (GO may
           ;; skip any suffix of a statement, and TAGBODY's value is NIL).
           ;; Within a single statement the usual guarded-reuse rules
           ;; hold: control only enters a statement at its beginning.
           (values (cons 'tagbody
                         (mapcar (lambda (s)
                                   (if (atom s)
                                       s
                                       (multiple-value-bind (s2)
                                           (shen-cl.acc-walk s env scope)
                                         s2)))
                                 (cdr e)))
                   env env))
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
                       ca ca))))
          ((eq head 'cond) (shen-cl.acc-walk-cond e env scope))
          ((member head '(let let*)) (shen-cl.acc-walk-let e env scope))
          ((eq head '|let|)           ; (|let| var value body)
           (destructuring-bind (op var value body) e
             (multiple-value-bind (value2 va) (shen-cl.acc-walk value env scope)
               (let ((body2 (shen-cl.acc-walk
                             body
                             (shen-cl.acc-shadow va (list var))
                             (cons var scope))))
                 (values (list op var value2 body2) va va)))))
          ((eq head '|if|)            ; (|if| c y z): c always evaluated
           (destructuring-bind (op c y z) e
             (multiple-value-bind (c2 ca) (shen-cl.acc-walk c env scope)
               (values (list op c2
                             (shen-cl.acc-walk y ca scope)
                             (shen-cl.acc-walk z ca scope))
                       ca ca))))
          ((member head '(|and| |or|)) ; (op x y): y conditionally evaluated
           (destructuring-bind (op x y) e
             (multiple-value-bind (x2 xa xt) (shen-cl.acc-walk x env scope)
               (values (list op x2
                             (shen-cl.acc-walk y (if (eq head '|and|) xt xa)
                                               scope))
                       xa xa))))
          ((eq head '|trap-error|)    ; body may unwind mid-way
           (destructuring-bind (op x f) e
             (values (list op
                           (shen-cl.acc-walk x env scope)
                           (shen-cl.acc-walk f env scope))
                     env env)))
          ((eq head 'block)           ; (BLOCK name form...): RETURN may skip
           (multiple-value-bind (forms)
               (shen-cl.acc-walk-seq (cddr e) env scope)
             (values (list* 'block (second e) forms) env env)))
          ((eq head 'progn)
           (multiple-value-bind (forms env2)
               (shen-cl.acc-walk-seq (cdr e) env scope)
             (values (cons 'progn forms) env2 env2)))
          ((eq head 'return)          ; (RETURN [value])
           (values (if (cdr e)
                       (list 'return (shen-cl.acc-walk (second e) env scope))
                       e)
                   env env))
          ((eq head 'return-from)     ; (RETURN-FROM name [value])
           (values (if (cddr e)
                       (list 'return-from (second e)
                             (shen-cl.acc-walk (third e) env scope))
                       e)
                   env env))
          ((or (special-operator-p head) (macro-function head))
           ;; Anything else the compiler does not emit (lisp. escapes):
           ;; leave completely unchanged.
           (values e env env))
          (t
           ;; Plain function call: arguments all evaluated left-to-right.
           (multiple-value-bind (args env2)
               (shen-cl.acc-walk-seq (cdr e) env scope)
             (values (cons head args) env2 env2)))))))

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
  (let ((cur env) (out nil) (env-always env))
    (loop for arg in (cdr e)
          for i from 0
          do (multiple-value-bind (a2 aa at) (shen-cl.acc-walk arg cur scope)
               (push a2 out)
               (when (= i 0) (setf env-always aa))
               (setf cur at)))
    (values (cons 'and (nreverse out)) env-always cur)))

(defun shen-cl.acc-walk-or (e env scope)
  ;; arg j evaluates only if args 1..j-1 were false.
  (let ((cur env) (out nil) (env-always env))
    (loop for arg in (cdr e)
          for i from 0
          do (multiple-value-bind (a2 aa) (shen-cl.acc-walk arg cur scope)
               (push a2 out)
               (when (= i 0) (setf env-always aa))
               (setf cur aa)))
    (values (cons 'or (nreverse out)) env-always env-always)))

(defun shen-cl.acc-walk-cond (e env scope)
  ;; test i+1 evaluates only after test i evaluated (to false); a clause body
  ;; evaluates only after its own test was fully true.
  (let ((cur env) (out nil) (env-always env))
    (loop for clause in (cdr e)
          for i from 0
          do (multiple-value-bind (t2 ta tt)
                 (shen-cl.acc-walk (car clause) cur scope)
               (multiple-value-bind (body)
                   (shen-cl.acc-walk-seq (cdr clause) tt scope)
                 (push (cons t2 body) out))
               (when (= i 0) (setf env-always ta))
               (setf cur ta)))
    (values (cons 'cond (nreverse out)) env-always env-always)))

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
        ;; variables, so nothing escapes.
        (values (list* op (nreverse out) body2) env env)))))

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
  (if (and (arrayp x) (not (stringp x)))
     '|true|
     '|false|))

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
  (multiple-value-bind (entry found) (gethash var dict)
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
    ((and (consp x) (consp y) (|shen-cl.absequal| (car x) (car y)))
     (|shen-cl.absequal| (cdr x) (cdr y)))
    ((and (stringp x) (stringp y))
     (string= x y))
    ((and (numberp x) (numberp y))
     (= x y))
    ((and (arrayp x) (arrayp y))
     (cf-vectors x y (length x) (length y)))
    (t
     (equal x y))))

(defun cf-vectors (x y lx ly)
  (and
    (= lx ly)
    (or (zerop lx)
        (cf-vectors-help x y 0 (1- lx)))))

(defun cf-vectors-help (x y count max)
  (cond
    ((= count max)
     (|shen-cl.absequal| (aref x max) (aref y max)))
    ((|shen-cl.absequal| (aref x count) (aref y count))
     (cf-vectors-help x y (1+ count) max))
    (t
     nil)))

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
    (t (string (char x n)))))

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
        (string c)
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
    (if (zerop len)
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
  (if (integerp x) x (coerce x 'double-float)))

(defun |shen-cl.multiply| (x y)
  (if (or (zerop x) (zerop y))
    0
    (* (|shen-cl.double-precision| x) (|shen-cl.double-precision| y))))

(defun |shen-cl.add| (x y)
  (+ (|shen-cl.double-precision| x) (|shen-cl.double-precision| y)))

(defun |shen-cl.subtract| (x y)
  (- (|shen-cl.double-precision| x) (|shen-cl.double-precision| y)))

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

    ;; Advertise the host SHA-256 backend from the running process. SBCL/CLISP
    ;; bake the environment into the saved image at build time, so this cannot
    ;; move to boot.lsp without freezing SHEN_X_SHA256 at whoever built it.
    ;; ECL initialises the Shen environment further down and installs there.
    #-ecl (|shen-cl.install-sha256-host|)

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
    ;; dumping an image. Unlike SBCL/CLISP (which bake Tarver's StLib sources
    ;; into the saved image at build time -- see boot.lsp), ECL cannot bake that
    ;; runtime state, and loading the StLib sources at startup costs ~105s
    ;; (ECL C-compiles each definition on load). So ECL alone retains the
    ;; precompiled community stlib.kl graft (baked into the object files,
    ;; replayed cheaply here). Retiring it needs a StLib->.lsp packager; see
    ;; docs/KERNEL-PROVENANCE-tarver-s42.0.md.
    #+ecl
    (progn
     (|shen.initialise|)
     (|shen-cl.initialise|)
     (|shen.x.features.initialise| '(|shen/cl| |shen/cl.ecl|))
     (|stlib.initialise-environment|)
     (|stlib.initialise-arities|)
     (|stlib.initialise-synonyms|)
     (|stlib.initialise-datatypes|)
     (|stlib.initialise-macros|)
     (|stlib.initialise-types|)
     (|stlib.initialise-sources|)
     (|stlib.initialise-final|)
     (|shen-cl.install-sha256-host|)
     (|shen-cl.toplevel-interpret-args| (si:command-args)))

    #+sbcl
    (handler-case
      (|shen-cl.toplevel-interpret-args| sb-ext:*posix-argv*)
      (serious-condition (c)
        (ignore-errors
          (format *error-output* "~&Fatal: ~A~%" c))
        (|cl.exit| 1)))
))
