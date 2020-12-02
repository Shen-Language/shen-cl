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

(defun |shen.lazyderef| (x process-n)
  (if (and (arrayp x) (not (stringp x)) (eq (svref x 0) '|shen.pvar|))
    (let ((value (|shen.valvector| x process-n)))
      (if (eq value '|shen.-null-|)
        x
        (|shen.lazyderef| value process-n)))
    x))

(defun |shen.valvector| (var process-n)
  (svref (svref |shen.*prologvectors*| process-n) (svref var 1)))

(defun |shen.unbindv| (var n)
  (let ((vector (svref |shen.*prologvectors*| n)))
    (setf (svref vector (svref var 1)) '|shen.-null-|)))

(defun |shen.bindv| (var val n)
  (let ((vector (svref |shen.*prologvectors*| n)))
    (setf (svref vector (svref var 1)) val)))

(defun |shen.copy-vector-stage-1| (count vector big-vector max)
  (if (= max count)
      big-vector
      (|shen.copy-vector-stage-1|
        (1+ count)
        vector
        (|address->| big-vector count (|<-address| vector count))
        max)))

(defun |shen.copy-vector-stage-2| (count max fill big-vector)
  (if (= max count)
      big-vector
      (|shen.copy-vector-stage-2|
        (1+ count)
        max
        fill
        (|address->| big-vector count fill))))

(defun |shen.newpv| (n)
  (let ((count+1 (1+ (the integer (svref |shen.*varcounter*| n))))
        (vector (svref |shen.*prologvectors*| n)))
    (setf (svref |shen.*varcounter*| n) count+1)
    (if (= (the integer count+1) (the integer (|limit| vector)))
        (|shen.resizeprocessvector| n count+1)
        '|skip|)
    (|shen.mk-pvar| count+1)))

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

#+abcl
(defun |cl.exit| (code)
  (ext:quit :status code))

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
    (|shen-cl.read-eval| "(defmacro shen-cl.exit-macro [shen-cl.exit] -> [cl.exit 0])")))

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
#-abcl
(setf (symbol-function '|shen-cl.original-credits|) #'|shen.credits|)

#-abcl
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
