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

;;; Kernel 41.1 stream primitives.
;;; Character streams (e.g. *standard-input*) need read-char; binary streams
;;; (e.g. file streams opened for bytes) use read-byte.
(defun |shen.char-stinput?| (stream)
  (if (subtypep (stream-element-type stream) 'character)
      '|true|
      '|false|))

(defun |shen.char-stoutput?| (stream)
  (if (subtypep (stream-element-type stream) 'character)
      '|true|
      '|false|))

;; The kernel's pr calls this on character output streams. On SBCL/CCL the
;; native |pr| override below bypasses it; other implementations (CLisp,
;; ECL) run the kernel's KL pr and need it defined.
(defun |shen.write-string| (string stream)
  (write-string string stream)
  (force-output stream)
  string)

(defun |shen.read-unit-string| (stream)
  (let ((c (read-char stream nil nil)))
    (if c (string c) "")))

(defvar |shen-cl.kernel-sysfunc?| (fdefinition '|shen.sysfunc?|))

(defun |shen.sysfunc?| (symbol)
  (if (not (symbolp symbol))
      '|false|
      (|or|
        (|shen-cl.lisp-prefixed?| symbol)
        (apply |shen-cl.kernel-sysfunc?| (list symbol)))))

(defun shen.pvar? (x)
  (if (and (arrayp x) (not (stringp x)) (eq (svref x 0) '|shen.pvar|))
      '|true|
      '|false|))

(defvar specials (coerce "=*/+-_?$!@~><&%{}:;`#'." 'list))

(defun symbol-characterp (c)
  (or (alphanumericp c)
      (not (null (member c specials)))))

(defun |shen.analyse-symbol?| (s)
  (if (and (> (length s) 0)
           (not (digit-char-p (char s 0)))
           (symbol-characterp (char s 0))
           (every #'symbol-characterp s))
      '|true|
      '|false|))

(defun |symbol?| (val)
  (if (and (symbolp val)
           (not (null val))
           (not (eq t val))
           (not (eq val '|true|))
           (not (eq val '|false|)))
      (|shen.analyse-symbol?| (|str| val))
      '|false|))

(defun |variable?| (val)
  (if (and (symbolp val)
           (not (null val))
           (not (eq t val))
           (not (eq val '|true|))
           (not (eq val '|false|))
           (upper-case-p (char (symbol-name val) 0))
           (every #'symbol-characterp (symbol-name val)))
      '|true|
      '|false|))

;;; --- Phase 3: Pattern factorization ---
;;; Factorises multi-clause cond forms by grouping consecutive clauses
;;; that share the same leading AND test. Operates on KL forms where
;;; symbols are in the :SHEN package (|and|, |cond|, |defun|, |true|).

(defun shen-cl.extract-first-test (test)
  "Extract the first test from a KL (and X Y) chain, or return NIL if not."
  (if (and (consp test)
           (eq (car test) '|and|)
           (consp (cdr test))
           (consp (cddr test)))
      (values (cadr test) (caddr test))
      (values nil nil)))

(defun shen-cl.factorise-cases (cases)
  "Group consecutive cond cases sharing the same first AND test.
   When a group has >1 case, emit a nested cond under the shared test,
   with a (true ...) fallthrough to the remaining cases for correctness."
  (if (null cases)
      nil
      (let* ((case1 (car cases))
             (test1 (car case1)))
        (multiple-value-bind (first-test rest-test)
            (shen-cl.extract-first-test test1)
          (if (null first-test)
              ;; Not an AND chain (e.g. |true| fallthrough) — pass through
              (cons case1 (shen-cl.factorise-cases (cdr cases)))
              ;; Collect consecutive cases sharing this first-test
              (let ((group nil)
                    (remaining (cdr cases)))
                ;; First case's rest-test + body
                (push (list rest-test (cadr case1)) group)
                ;; Collect more cases with same first-test
                (loop while remaining
                      do (multiple-value-bind (ft rt)
                             (shen-cl.extract-first-test (caar remaining))
                           (if (and ft (equal ft first-test))
                               (progn
                                 (push (list rt (cadar remaining)) group)
                                 (setf remaining (cdr remaining)))
                               (return))))
                (setf group (nreverse group))
                (if (= (length group) 1)
                    ;; Only one case in group — no benefit, keep original
                    (cons case1 (shen-cl.factorise-cases remaining))
                    ;; Multiple cases — factor out shared first-test.
                    ;; The nested cond needs a (true ...) fallthrough to handle
                    ;; when the shared test matches but no sub-test does.
                    (let ((factored-remaining (shen-cl.factorise-cases remaining)))
                      (let ((inner-cond
                              (append group
                                      (list (list '|true|
                                                  (cons '|cond| factored-remaining))))))
                        (cons (list first-test (cons '|cond| inner-cond))
                              factored-remaining))))))))))

(defun |shen.x.factorise-defun.factorise-defun| (defun-form)
  "Factorise a [defun Name Args [cond | Cases]] form by grouping
   consecutive clauses that share the same leading AND test."
  (if (and (consp defun-form)
           (eq (car defun-form) '|defun|)
           (consp (cdr defun-form))
           (consp (cddr defun-form))
           (consp (cdddr defun-form))
           (null (cddddr defun-form)))
      (let* ((name (cadr defun-form))
             (args (caddr defun-form))
             (body (cadddr defun-form)))
        (if (and (consp body)
                 (eq (car body) '|cond|)
                 (> (length (cdr body)) 1))
            (let ((factored (shen-cl.factorise-cases (cdr body))))
              (if (equal factored (cdr body))
                  defun-form
                  (list '|defun| name args (cons '|cond| factored))))
            defun-form))
      defun-form))

(defun |vector->| (vector n x)
  (if (zerop n)
      (error "cannot access 0th element of a vector~%")
      (|address->| vector n x)))

(defun |<-vector| (vector n)
  (if (zerop n)
    (error "cannot access 0th element of a vector~%")
    (let ((vector-element (svref vector n)))
      (if (eq vector-element (|fail|))
          (error "vector element not found~%")
          vector-element))))

(defun |variable?| (x)
  (if (and (symbolp x) (not (null x)) (upper-case-p (char (symbol-name x) 0)))
      '|true|
      '|false|))

(defun |shen.+string?| (x)
  (if (and (stringp x) (not (string-equal x "")))
      '|true|
      '|false|))

(defun |thaw| (f)
  (funcall f))

(defun |hash| (val bound)
  (mod (sxhash val) bound))

(defun |shen.dict| (size)
  (make-hash-table :size size))

(defun |shen.dict?| (dict)
  (if (hash-table-p dict) '|true| '|false|))

(defun |shen.dict-count| (dict)
  (hash-table-count dict))

(defun |shen.dict->| (dict key value)
 (setf (gethash key dict) value))

(defun |shen.<-dict| (dict key)
  (multiple-value-bind (result found) (gethash key dict)
    (if found
        result
        (error "value ~A not found in dict~%" key))))

(defun |shen.dict-rm| (dict key)
  (progn (remhash key dict) key))

(defun |shen.dict-fold| (f dict init)
  (let ((acc init))
    (maphash #'(lambda (k v)
                 (setf acc (funcall (funcall (funcall f k) v) acc))) dict)
    acc))

#+clisp
(defun |cl.exit| (code)
  (ext:exit code))

#+(and ccl (not windows))
(defun |cl.exit| (code)
  (ccl:quit code))

#+(and ccl windows)
(ccl::eval (ccl::read-from-string "(defun |cl.exit| (code) (#__exit code))"))

#+ecl
(defun |cl.exit| (code)
  (si:quit code))

#+sbcl
(defun |cl.exit| (code)
  (alien-funcall (extern-alien "exit" (function void int)) code))

(defun |shen-cl.exit| (code)
  (|cl.exit| code))

(defun |shen-cl.initialise| ()
  (progn
    (|shen-cl.initialise-compiler|)

    (|put|      '|cl.exit| '|arity| 1 |*property-vector*|)
    (|put| '|shen-cl.exit| '|arity| 1 |*property-vector*|)

    (|declare|      '|cl.exit| (list '|number| '--> '|unit|))
    (|declare| '|shen-cl.exit| (list '|number| '--> '|unit|))

    (|shen-cl.read-eval| "(defmacro      cl.exit-macro      [cl.exit] -> [cl.exit 0])")
    (|shen-cl.read-eval| "(defmacro shen-cl.exit-macro [shen-cl.exit] -> [cl.exit 0])")

    ;; Register the threading natives (defined in native.lsp) so they have
    ;; a known arity and can be passed around as first-class functions;
    ;; mirrors (update-lambda-table 'thread 1) in the official S41.1 build.
    #+sbcl (|update-lambda-table| '|thread| 1)
    #+sbcl (|update-lambda-table| '|terminate| 1)))

#+(or ccl sbcl)
(defun |shen.read-char-code| (s)
  (let ((c (read-char s nil -1)))
    (if (eq c -1)
      -1
      (char-int c))))

#+(or ccl sbcl)
(defun |pr| (x s)
  (write-string x s)
  (when (or (eq s |*stoutput*|) (eq s |*stinput*|))
    (force-output s))
  x)

;; file reading

(defun |read-file-as-bytelist| (path)
  (with-open-file (stream (format nil "~A~A" |*home-directory*| path) :direction :input :element-type 'unsigned-byte)
    (let ((data (make-array (file-length stream) :element-type 'unsigned-byte :initial-element 0)))
      (read-sequence data stream)
      (coerce data 'list))))

(defun |shen.read-file-as-charlist| (path)
  (|read-file-as-bytelist| path))

(defun |shen.read-file-as-string| (path)
  (with-open-file (stream (format nil "~A~A" |*home-directory*| path) :direction :input)
    (let ((data (make-string (file-length stream))))
      (read-sequence data stream)
      data)))

;; tuples

(defun |@p| (x y)
  (vector '|shen.tuple| x y))

;; vectors

(defun |vector| (n)
  (let ((vec (make-array (1+ n) :initial-element (|fail|))))
    (setf (svref vec 0) n)
    vec))

; Amend the REPL credits message to explain exit command
(setf (symbol-function '|shen-cl.original-credits|) #'|shen.credits|)

(defun |shen.credits| ()
  (|shen-cl.original-credits|)
  (format t "exit REPL with (cl.exit)"))

;; Compiler functions

(defun |shen-cl.cl| (symbol)
  (let* ((str (symbol-name symbol))
         (lispname (string-upcase str)))
    (|intern| lispname)))

(defun |shen-cl.lisp-prefixed?| (symbol)
  (|shen-cl.lisp-true?|
    (and (not (null symbol))
         (symbolp symbol)
         (|shen-cl.prefix?| (symbol-name symbol) "lisp."))))

(defun |shen-cl.remove-lisp-prefix| (symbol)
  (|intern| (subseq (symbol-name symbol) 5)))

;;; --- Phase 1: Reader performance overrides ---

;;; shen.str->bytes: O(N) via char indexing instead of recursive tlstr
(defun |shen.str->bytes| (s)
  (declare (type string s))
  (let ((len (length s)))
    (if (zerop len)
        nil
        (let ((result nil))
          (loop for i from (1- len) downto 0
                do (push (char-code (char s i)) result))
          result))))

;;; shen.bytes->string: O(N) via string buffer instead of recursive cn
(defun |shen.bytes->string| (bytes)
  (if (null bytes)
      ""
      (with-output-to-string (out)
        (dolist (b bytes)
          (write-char (code-char b) out)))))

;;; shen.rfas-h: O(N) string building via buffer instead of repeated cn
(defun |shen.rfas-h| (stream byte acc)
  (declare (ignore acc))
  (if (eql byte -1)
      (progn (|close| stream) "")
      (let ((result (with-output-to-string (out)
                      (loop for b = byte then (|read-byte| stream)
                            until (eql b -1)
                            do (write-char (code-char b) out)))))
        (|close| stream)
        result)))

;;; shen.reader-error-message: O(N) via string buffer
(defun |shen.reader-error-message| (max-len idx bytes)
  (if (or (null bytes) (eql max-len idx))
      ""
      (with-output-to-string (out)
        (loop for b-list on bytes
              for i from idx
              while (not (eql max-len i))
              do (write-char (code-char (car b-list)) out)))))

;;; --- Phase 2: Macro expansion performance overrides ---

;;; macroexpand: extract macro functions once instead of mapping CDR each call
(defun |macroexpand| (expr)
  (let ((fns (mapcar #'cdr |*macros*|)))
    (|shen.macroexpand-h| expr fns fns)))

;;; shen.macroexpand-h: EQ fast-path before expensive absequal
;;; When a macro function doesn't match, it returns its argument unchanged
;;; (same pointer), so EQ succeeds for the vast majority of non-matching cases.
(defun |shen.macroexpand-h| (expr macros all-macros)
  (if (null macros)
      expr
      (if (consp macros)
          (let ((walked (|shen.walk| (car macros) expr)))
            (if (eq expr walked)
                ;; EQ means definitely unchanged — skip absequal entirely
                (|shen.macroexpand-h| expr (cdr macros) all-macros)
                ;; Pointers differ; check structural equality
                (if (|shen-cl.absequal| expr walked)
                    (|shen.macroexpand-h| expr (cdr macros) all-macros)
                    ;; Genuinely changed: restart from all macros
                    (|shen.macroexpand-h| walked all-macros all-macros))))
          (|simple-error| "implementation error in shen.macroexpand-h"))))

;;; Fix atom? to recognise CL T as a valid atom.
;;; The kernel atom? uses (or (symbol? x) ...) but shen-cl's symbol?
;;; excludes CL T (used for Shen variable T). This override uses CL
;;; symbolp as a fallback so the prolog <hterm> parser can handle T.
(defun |atom?| (x)
  (if (or (symbolp x) (stringp x) (numberp x))
      '|true|
      '|false|))
