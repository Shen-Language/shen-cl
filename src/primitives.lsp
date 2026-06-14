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

(defun |eval-kl| (X)
  (let ((e (eval (|shen-cl.kl->lisp| x))))
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
  (read-byte s nil -1))

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
        (format t "~%!!! FATAL error: ")
        (|shen.toplevel-display-exception| E)
        (format t "~%Exiting Shen.~%")
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
    #+ecl
    (progn
     (|shen.initialise|)
     (|shen-cl.initialise|)
     (|shen.x.features.initialise| '(|shen/cl| |shen/cl.ecl|))
     (|shen-cl.toplevel-interpret-args| (si:command-args)))

    #+sbcl
    (|shen-cl.toplevel-interpret-args| sb-ext:*posix-argv*)))
