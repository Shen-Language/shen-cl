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

;
; Identify Environment
;

#+(AND (NOT WINDOWS) (OR WIN32 WIN64 MINGW32)) (PUSH :WINDOWS *FEATURES*)
#+(AND (NOT MACOS) (OR APPLE DARWIN)) (PUSH :MACOS *FEATURES*)

;
; Disable Debugging
;

#+ECL
(SETF *DEBUGGER-HOOK*
  #'(LAMBDA (e h) (DECLARE (IGNORE h)) (PRINT e) (SI:QUIT 1)))

;
; Shared Global Declarations
;

(DEFVAR *language* "Common Lisp")
(DEFVAR *port* 2.2)
(DEFVAR *porters* "Mark Tarver")
(DEFVAR *os* (OR #+WINDOWS "Windows" #+MACOS "macOS" #+LINUX "Linux" #+UNIX "Unix" "Unknown"))
(DEFVAR *stinput* *STANDARD-INPUT*)
(DEFVAR *stoutput* *STANDARD-OUTPUT*)
(DEFVAR *sterror* *ERROR-OUTPUT*)
(DEFVAR *argv* NIL)

;
; Implementation-Specific Declarations
;

(DEFVAR *implementation* #+CLISP "GNU CLisp" #+CCL "Clozure CL" #+ECL "ECL" #+SBCL "SBCL")
(DEFVAR *release*
  #+CLISP (LET ((v (LISP-IMPLEMENTATION-VERSION))) (SUBSEQ v 0 (POSITION #\SPACE v :START 0)))
  #-CLISP (LISP-IMPLEMENTATION-VERSION))

#+ECL
(PROGN
  (SETQ COMPILER::*COMPILE-VERBOSE* NIL)
  (SETQ COMPILER::*SUPPRESS-COMPILER-MESSAGES* NIL)
  (EXT:SET-LIMIT 'EXT:C-STACK (* 1024 1024)))

#+SBCL
(PROGN
  (DECLAIM (INLINE write-byte))
  (DECLAIM (INLINE read-byte))
  (DECLAIM (INLINE shen-cl.double)))

;
; Internal Helpers
;

; TODO: sbcl doesn't want this to be a DEFCONSTANT, thinks it's being redefined
(DEFVAR shen-cl.*escapes*
  (LIST
    (CONS "#" "_hash1957")
    (CONS "'" "_quote1957")
    (CONS "`" "_backtick1957")
    (CONS "|" "_pipe1957")))

(DEFUN shen-cl.replace-all (s part replacement)
  (WITH-OUTPUT-TO-STRING (out)
    (LOOP
      WITH part-length = (LENGTH part)
      FOR old-pos = 0 THEN (+ pos part-length)
      FOR pos = (SEARCH part s :START2 old-pos :TEST #'CHAR=)
      DO (WRITE-STRING s out :START old-pos :END (OR pos (LENGTH s)))
      WHEN pos DO (WRITE-STRING replacement out)
      WHILE pos)))

(DEFUN shen-cl.escape (s)
  (REDUCE
    #'(LAMBDA (s pair) (shen-cl.replace-all s (CAR pair) (CDR pair)))
    shen-cl.*escapes*
    :INITIAL-VALUE s))

(DEFUN shen-cl.unescape (s)
  (REDUCE
    #'(LAMBDA (s pair) (shen-cl.replace-all s (CDR pair) (CAR pair)))
    shen-cl.*escapes*
    :INITIAL-VALUE s))

(DEFUN shen-cl.== (x y)
  "Returns Lisp boolean"
  (COND
    ((AND (CONSP x) (CONSP y) (shen-cl.== (CAR x) (CAR y)))
     (shen-cl.== (CDR x) (CDR y)))
    ((AND (STRINGP x) (STRINGP y))
     (STRING= x y))
    ((AND (NUMBERP x) (NUMBERP y))
     (= x y))
    ((AND (ARRAYP x) (ARRAYP y))
     (AND (= (LENGTH x) (LENGTH y)) (shen-cl.array= x y 0 (LENGTH x))))
    (T
     (EQUAL x y))))

(DEFUN shen-cl.array= (x y index size)
  (OR
    (= index size)
    (AND
      (shen-cl.== (AREF x index) (AREF y index))
      (shen-cl.array= x y (1+ index) size))))

(DEFUN shen-cl.process-number (s)
  (COND
    ((STRING-EQUAL s "")
     "")
    ((STRING-EQUAL (pos s 0) "d")
     (IF (STRING-EQUAL (pos s 1) "0") "" (cn "e" (tlstr s))))
    (T
     (cn (pos s 0) (shen-cl.process-number (tlstr s))))))

(DEFUN shen-cl.prefix? (s prefix)
  (LET ((prefix-length (LENGTH prefix)))
    (AND
      (>= (LENGTH s) prefix-length)
      (STRING-EQUAL s prefix :END1 prefix-length))))

(DEFUN shen-cl.open-file (path direction)
  (COND
    ((EQ direction 'in)
     (OPEN path
      :DIRECTION :INPUT
      :ELEMENT-TYPE
        #+CLISP 'UNSIGNED-BYTE
        #-CLISP :DEFAULT))
    ((EQ direction 'out)
     (OPEN path
      :DIRECTION :OUTPUT
      :ELEMENT-TYPE
        #+CLISP 'UNSIGNED-BYTE
        #-CLISP :DEFAULT
      :IF-EXISTS :SUPERSEDE))
    (T
     (ERROR "invalid direction"))))

(DEFUN shen-cl.double (x)
  (IF (INTEGERP x) x (COERCE x 'DOUBLE-FLOAT)))

(DEFUN shen-cl.* (x y)
  (IF (OR (ZEROP x) (ZEROP y))
    0
    (* (shen-cl.double x) (shen-cl.double y))))

(DEFUN shen-cl.+ (x y)
  (+ (shen-cl.double x) (shen-cl.double y)))

(DEFUN shen-cl.- (x y)
  (- (shen-cl.double x) (shen-cl.double y)))

(DEFUN shen-cl./ (x y)
  (LET ((z (/ (shen-cl.double x) (shen-cl.double y))))
    (IF (INTEGERP z)
      z
      (* (COERCE 1.0 'DOUBLE-FLOAT) z))))

(DEFUN shen-cl.> (x y)
  (IF (> x y) 'true 'false))

(DEFUN shen-cl.< (x y)
  (IF (< x y) 'true 'false))

(DEFUN shen-cl.>= (x y)
  (IF (>= x y) 'true 'false))

(DEFUN shen-cl.<= (x y)
  (IF (<= x y) 'true 'false))

(DEFUN shen-cl.= (x y)
  "Returns Shen boolean"
  (IF (shen-cl.== x y) 'true 'false))

;
; KL Primitive Definitions
;

(DEFMACRO if (c x y)
  (LET ((r (GENSYM)))
    `(LET ((,r ,c))
      (COND
        ((EQ ,r 'true)  ,x)
        ((EQ ,r 'false) ,y)
        (T               (ERROR "~S is not a boolean~%" ,r))))))

(DEFMACRO and (x y)
  `(if ,x (if ,y 'true 'false) 'false))

(DEFMACRO or (x y)
  `(if ,x 'true (if ,y 'true 'false)))

(DEFUN set (s x)
  (SET s x))

(DEFUN value (s)
  (SYMBOL-VALUE s))

(DEFUN simple-error (s)
  (ERROR "~A" s))

(DEFMACRO trap-error (body handler)
  (LET ((e (GENSYM)))
    `(HANDLER-CASE ,body (ERROR (,e) (FUNCALL ,handler ,e)))))

(DEFUN error-to-string (e)
  (IF (TYPEP e 'CONDITION)
    (FORMAT NIL "~A" e)
    (ERROR "~S is not an exception~%" e)))

(DEFUN cons (x y)
  (CONS x y))

(DEFUN hd (x)
  (CAR x))

(DEFUN tl (x)
  (CDR x))

(DEFUN cons? (x)
  (IF (CONSP x) 'true 'false))

(DEFUN intern (s)
  (INTERN (shen-cl.escape s)))

(DEFUN eval-kl (x)
  (LET ((e (EVAL (shen-cl.kl->lisp NIL x))))
    (IF (AND (CONSP x) (EQ (CAR x) 'defun))
      (COMPILE e)
      e)))

(DEFMACRO let (x y z)
  `(LET ((,x ,y)) ,z))

(DEFMACRO lambda (param body)
  `(FUNCTION (LAMBDA (,param) ,body)))

(DEFMACRO freeze (x)
  `(FUNCTION (LAMBDA () ,x)))

(DEFUN absvector (n)
  (MAKE-ARRAY n))

(DEFUN absvector? (x)
  (IF (ARRAYP x) 'true 'false))

(DEFUN address-> (a n x)
  (SETF (SVREF a n) x) a)

(DEFUN <-address (a n)
  (SVREF a n))

(DEFUN write-byte (b s)
  (WRITE-BYTE b s))

(DEFUN read-byte (s)
  (READ-BYTE s NIL -1))

(DEFUN open (path direction)
  (shen-cl.open-file (FORMAT NIL "~A~A" *home-directory* path) direction))

(DEFUN type (x type)
  (DECLARE (IGNORE type))
  x)

(DEFUN close (s)
  (CLOSE s)
  NIL)

(DEFUN pos (s n)
  (COERCE (LIST (CHAR s n)) 'STRING))

(DEFUN tlstr (s)
  (DECLARE (TYPE STRING s))
  (SUBSEQ s 1))

(DEFUN cn (s1 s2)
  (DECLARE (TYPE STRING s1) (TYPE STRING s2))
  (CONCATENATE 'STRING s1 s2))

(DEFUN string? (x)
  (IF (STRINGP x) 'true 'false))

(DEFUN n->string (n)
  (FORMAT NIL "~C" (CODE-CHAR n)))

(DEFUN string->n (s)
  (DECLARE (TYPE STRING s))
  (CHAR-CODE (CAR (COERCE s 'LIST))))

(DEFUN str (x)
  (COND
    ((NULL x)      (ERROR "[] is not an atom in Shen; str cannot convert it to a string.~%"))
    ((SYMBOLP x)   (shen-cl.unescape (SYMBOL-NAME x)))
    ((NUMBERP x)   (shen-cl.process-number (FORMAT NIL "~A" x)))
    ((STRINGP x)   (FORMAT NIL "~S" x))
    ((STREAMP x)   (FORMAT NIL "~A" x))
    ((FUNCTIONP x) (FORMAT NIL "~A" x))
    (T             (ERROR "~S is not an atom, stream or closure; str cannot convert it to a string.~%" x))))

(DEFUN get-time (mode)
  (COND
    ((EQ mode 'run)  (* 1.0 (/ (GET-INTERNAL-RUN-TIME) INTERNAL-TIME-UNITS-PER-SECOND)))
    ((EQ mode 'unix) (- (GET-UNIVERSAL-TIME) 2208988800))
    (T               (ERROR "get-time does not understand the parameter ~A~%" mode))))

(DEFUN number? (x)
  (IF (NUMBERP x) 'true 'false))

;
; Shared Startup Procedures
;

(DEFUN shen-cl.eval-print (x)
  (print (eval x)))

(DEFUN shen-cl.print-version ()
  (FORMAT T "~A~%" *version*)
  (FORMAT T "Shen-CL ~A~%" *port*)
  (FORMAT T "~A ~A~%" *implementation* *release*))

(DEFUN shen-cl.print-help ()
  (FORMAT T "Usage: shen [OPTIONS...]~%")
  (FORMAT T "  -v, --version       : Prints Shen, shen-cl version numbers and exits~%")
  (FORMAT T "  -h, --help          : Shows this help and exits~%")
  (FORMAT T "  -e, --eval <expr>   : Evaluates expr and prints result~%")
  (FORMAT T "  -l, --load <file>   : Reads and evaluates file~%")
  (FORMAT T "  -q, --quiet         : Silences interactive output~%")
  (FORMAT T "~%")
  (FORMAT T "Evaluates options in order~%")
  (FORMAT T "Starts the REPL if no eval/load options specified~%"))

(DEFUN shen-cl.flag? (args options)
  (AND (CONSP args) (MEMBER (CAR args) options :TEST #'STRING-EQUAL)))

(DEFUN shen-cl.interpret-args (args)
  "Returns T if repl should be started"
  (COND
    ((shen-cl.flag? args (LIST "-v" "--version"))
     (shen-cl.print-version)
     NIL)
    ((shen-cl.flag? args (LIST "-h" "--help"))
     (shen-cl.print-version)
     (FORMAT T "~%")
     (shen-cl.print-help)
     NIL)
    ((shen-cl.flag? args (LIST "-e" "--eval"))
     (MAPC #'shen-cl.eval-print (read-from-string (CADR args)))
     (shen-cl.interpret-args (CDDR args))
     NIL)
    ((shen-cl.flag? args (LIST "-l" "--load"))
     (load (CADR args))
     (shen-cl.interpret-args (CDDR args))
     NIL)
    ((shen-cl.flag? args (LIST "-q" "--quiet"))
     (SETQ *hush* 'true)
     (shen-cl.interpret-args (CDR args)))
    ((CONSP args)
     (shen-cl.interpret-args (CDR args)))
    (T
     T)))

;
; Implementation-Specific Startup Procedures
;

(DEFUN shen-cl.init ()
  #+CLISP (SETQ *stinput* (EXT:MAKE-STREAM :INPUT :ELEMENT-TYPE 'UNSIGNED-BYTE))
  #+CLISP (SETQ *stoutput* (EXT:MAKE-STREAM :OUTPUT :ELEMENT-TYPE 'UNSIGNED-BYTE))
  #+CLISP (SETQ *sterror* *stoutput*)

  (SETQ *argv*
    #+CLISP EXT:*ARGS*
    #+CCL   (CDR *COMMAND-LINE-ARGUMENT-LIST*)
    #+ECL   (CDR (SI:COMMAND-ARGS))
    #+SBCL  (CDR SB-EXT:*POSIX-ARGV*)))

(DEFUN shen-cl.toplevel ()
  (shen-cl.init)

  #+CLISP
  (HANDLER-BIND ((WARNING #'MUFFLE-WARNING))
    (IF (shen-cl.interpret-args *argv*)
      (shen.shen)
      (exit 0)))

  #+CCL
  (HANDLER-BIND ((WARNING #'MUFFLE-WARNING))
    (IF (shen-cl.interpret-args *argv*)
      (shen.shen)
      (exit 0)))

  #+ECL
  (IF (shen-cl.interpret-args *argv*)
    (shen.shen)
    (exit 0))

  #+SBCL
  (IF (shen-cl.interpret-args *argv*)
    (HANDLER-CASE (shen.shen)
      (SB-SYS:INTERACTIVE-INTERRUPT ()
        (exit 0)))
    (exit 0)))
