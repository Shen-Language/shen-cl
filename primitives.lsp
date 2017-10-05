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

(DEFVAR *stinput* *STANDARD-INPUT*)
(DEFVAR *stoutput* *STANDARD-OUTPUT*)
(DEFVAR *sterror* *ERROR-OUTPUT*)
(DEFVAR *language* "Common Lisp")
(DEFVAR *port* 2.1)
(DEFVAR *porters* "Mark Tarver")

#+CLISP
(PROGN
  (DEFVAR *implementation* "GNU CLisp")
  (DEFVAR *release* (LET ((V (LISP-IMPLEMENTATION-VERSION))) (SUBSEQ V 0 (POSITION #\SPACE V :START 0))))
  (DEFVAR *os* (OR #+WIN32 "Windows" #+LINUX "Linux" #+MACOS "macOS" #+UNIX "Unix" "Unknown")))

#+CCL
(PROGN
  (DEFVAR *implementation* "Clozure CL")
  (DEFVAR *release* (LISP-IMPLEMENTATION-VERSION))
  (DEFVAR *os* (OR #+WINDOWS "Windows" #+LINUX "Linux" #+DARWIN "macOS" #+UNIX "Unix" "Unknown")))

#+ECL
(PROGN
  (DEFVAR *implementation* "ECL")
  (DEFVAR *release* (LISP-IMPLEMENTATION-VERSION))
  (DEFVAR *os* (OR #+(OR :WIN32 :MINGW32) "Windows" #+LINUX "Linux" #+APPLE "macOS" #+UNIX "Unix" "Unknown"))
  (SETQ COMPILER::*COMPILE-VERBOSE* NIL)
  (SETQ COMPILER::*SUPPRESS-COMPILER-MESSAGES* NIL))

#+SBCL
(PROGN
  (DEFVAR *implementation* "SBCL")
  (DEFVAR *release* (LISP-IMPLEMENTATION-VERSION))
  (DEFVAR *os* (OR #+WIN32 "Windows" #+LINUX "Linux" #+DARWIN "macOS" #+UNIX "Unix" "Unknown"))
  (DECLAIM (INLINE write-byte))
  (DECLAIM (INLINE read-byte))
  (DECLAIM (INLINE shen.double-precision)))

(DEFMACRO if (X Y Z)
  `(LET ((*C* ,X))
    (COND
      ((EQ *C* 'true)  ,Y)
      ((EQ *C* 'false) ,Z)
      (T               (ERROR "~S is not a boolean~%" *C*)))))

(DEFMACRO and (X Y)
  `(if ,X (if ,Y 'true 'false) 'false))

(DEFMACRO or (X Y)
  `(if ,X 'true (if ,Y 'true 'false)))

(DEFUN set (X Y)
  (SET X Y))

(DEFUN value (X)
  (SYMBOL-VALUE X))

(DEFUN simple-error (String)
  (ERROR "~A" String))

(DEFMACRO trap-error (X F)
  `(HANDLER-CASE ,X (ERROR (Condition) (FUNCALL ,F Condition))))

(DEFUN error-to-string (E)
  (IF (TYPEP E 'CONDITION)
    (FORMAT NIL "~A" E)
    (ERROR "~S is not an exception~%" E)))

(DEFUN cons (X Y)
  (CONS X Y))

(DEFUN hd (X)
  (CAR X))

(DEFUN tl (X)
  (CDR X))

(DEFUN cons? (X)
  (IF (CONSP X) 'true 'false))

(DEFUN intern (String)
  (INTERN (shen.process-intern String)))

(DEFUN shen.process-intern (S)
  (COND
    ((STRING-EQUAL S "")          S)
    ((STRING-EQUAL (pos S 0) "#") (cn "_hash1957" (shen.process-intern (tlstr S))))
    ((STRING-EQUAL (pos S 0) "'") (cn "_quote1957" (shen.process-intern (tlstr S))))
    ((STRING-EQUAL (pos S 0) "`") (cn "_backquote1957" (shen.process-intern (tlstr S))))
    ((STRING-EQUAL (pos S 0) "|") (cn "bar!1957" (shen.process-intern (tlstr S))))
    (T                            (cn (pos S 0) (shen.process-intern (tlstr S))))))

(DEFUN eval-kl (X)
  (LET ((E (EVAL (shen.kl-to-lisp NIL X))))
    (IF (AND (CONSP X) (EQ (CAR X) 'defun))
      (COMPILE E)
      E)))

(DEFMACRO lambda (X Y)
  `(FUNCTION (LAMBDA (,X) ,Y)))

(DEFMACRO let (X Y Z)
  `(LET ((,X ,Y)) ,Z))

(DEFMACRO freeze (X)
  `(FUNCTION (LAMBDA () ,X)))

(DEFUN absvector (N)
  (MAKE-ARRAY (LIST N)))

(DEFUN absvector? (X)
  (IF (ARRAYP X) 'true 'false))

(DEFUN address-> (Vector N Value)
  (SETF (SVREF Vector N) Value) Vector)

(DEFUN <-address (Vector N)
  (SVREF Vector N))

(DEFUN shen.equal? (X Y)
  (IF (shen.ABSEQUAL X Y) 'true 'false))

(DEFUN shen.ABSEQUAL (X Y)
  (COND
    ((AND (CONSP X) (CONSP Y) (shen.ABSEQUAL (CAR X) (CAR Y)))
     (shen.ABSEQUAL (CDR X) (CDR Y)))
    ((AND (STRINGP X) (STRINGP Y))
     (STRING= X Y))
    ((AND (NUMBERP X) (NUMBERP Y))
     (= X Y))
    ((AND (ARRAYP X) (ARRAYP Y))
     (CF-VECTORS X Y (LENGTH X) (LENGTH Y)))
    (T
     (EQUAL X Y))))

(DEFUN CF-VECTORS (X Y LX LY)
  (AND
    (= LX LY)
    (CF-VECTORS-HELP X Y 0 (1- LX))))

(DEFUN CF-VECTORS-HELP (X Y COUNT MAX)
  (COND
    ((= COUNT MAX)
     (shen.ABSEQUAL (AREF X MAX) (AREF Y MAX)))
    ((shen.ABSEQUAL (AREF X COUNT) (AREF Y COUNT))
     (CF-VECTORS-HELP X Y (1+ COUNT) MAX))
    (T
     NIL)))

(DEFUN write-byte (Byte S)
  (WRITE-BYTE Byte S))

(DEFUN read-byte (S)
  (READ-BYTE S NIL -1))

(DEFUN open (String Direction)
  (LET ((Path (FORMAT NIL "~A~A" *home-directory* String)))
    (shen.openh Path Direction)))

(DEFUN shen.openh (Path Direction)
  (COND
    ((EQ Direction 'in)
     (OPEN Path
      :DIRECTION :INPUT
      :ELEMENT-TYPE
        #+CLISP 'UNSIGNED-BYTE
        #-CLISP :DEFAULT))
    ((EQ Direction 'out)
     (OPEN Path
      :DIRECTION :OUTPUT
      :ELEMENT-TYPE
        #+CLISP 'UNSIGNED-BYTE
        #-CLISP :DEFAULT
      :IF-EXISTS :SUPERSEDE))
    (T
     (ERROR "invalid direction"))))

(DEFUN type (X MyType)
  (DECLARE (IGNORE MyType))
  X)

(DEFUN close (Stream)
  (CLOSE Stream)
  NIL)

(DEFUN pos (X N)
  (COERCE (LIST (CHAR X N)) 'STRING))

(DEFUN tlstr (X)
  (SUBSEQ X 1))

(DEFUN cn (Str1 Str2)
  (DECLARE (TYPE STRING Str1) (TYPE STRING Str2))
  (CONCATENATE 'STRING Str1 Str2))

(DEFUN string? (S)
  (IF (STRINGP S) 'true 'false))

(DEFUN n->string (N)
  (FORMAT NIL "~C" (CODE-CHAR N)))

(DEFUN string->n (S)
  (CHAR-CODE (CAR (COERCE S 'LIST))))

(DEFUN str (X)
  (COND
    ((NULL X)      (ERROR "[] is not an atom in Shen; str cannot convert it to a string.~%"))
    ((SYMBOLP X)   (shen.process-string (SYMBOL-NAME X)))
    ((NUMBERP X)   (shen.process-number (FORMAT NIL "~A" X)))
    ((STRINGP X)   (FORMAT NIL "~S" X))
    ((STREAMP X)   (FORMAT NIL "~A" X))
    ((FUNCTIONP X) (FORMAT NIL "~A" X))
    (T             (ERROR "~S is not an atom, stream or closure; str cannot convert it to a string.~%" X))))

(DEFUN shen.process-number (S)
  (COND
    ((STRING-EQUAL S "")
     "")
    ((STRING-EQUAL (pos S 0) "d")
     (IF (STRING-EQUAL (pos S 1) "0") "" (cn "e" (tlstr S))))
    (T
     (cn (pos S 0) (shen.process-number (tlstr S))))))

(DEFUN shen-cl.prefix? (Str Prefix)
  (LET ((Prefix-Length (LENGTH Prefix)))
    (AND
      (>= (LENGTH Str) Prefix-Length)
      (STRING-EQUAL Str Prefix :END1 Prefix-Length))))

(DEFUN shen.process-string (X)
  (COND
    ((STRING-EQUAL X "")                  X)
    ((shen-cl.prefix? X "_hash1957")      (cn "#" (shen.process-string (SUBSEQ X 9))))
    ((shen-cl.prefix? X "_quote1957")     (cn "'" (shen.process-string (SUBSEQ X 10))))
    ((shen-cl.prefix? X "_backquote1957") (cn "`" (shen.process-string (SUBSEQ X 14))))
    ((shen-cl.prefix? X "bar!1957")       (cn "|" (shen.process-string (SUBSEQ X 8))))
    (T                                    (cn (pos X 0) (shen.process-string (tlstr X))))))

(DEFUN get-time (Time)
  (COND
    ((EQ Time 'run)  (* 1.0 (/ (GET-INTERNAL-RUN-TIME) INTERNAL-TIME-UNITS-PER-SECOND)))
    ((EQ Time 'unix) (- (GET-UNIVERSAL-TIME) 2208988800))
    (T               (ERROR "get-time does not understand the parameter ~A~%" Time))))

(DEFUN shen.double-precision (X)
  (IF (INTEGERP X) X (COERCE X 'DOUBLE-FLOAT)))

(DEFUN shen.multiply (X Y)
  (IF (OR (ZEROP X) (ZEROP Y))
    0
    (* (shen.double-precision X) (shen.double-precision Y))))

(DEFUN shen.add (X Y)
  (+ (shen.double-precision X) (shen.double-precision Y)))

(DEFUN shen.subtract (X Y)
  (- (shen.double-precision X) (shen.double-precision Y)))

(DEFUN shen.divide (X Y)
  (LET ((Div (/ (shen.double-precision X)
                (shen.double-precision Y))))
    (IF (INTEGERP Div)
      Div
      (* (COERCE 1.0 'DOUBLE-FLOAT) Div))))

(DEFUN shen.greater? (X Y)
  (IF (> X Y) 'true 'false))

(DEFUN shen.less? (X Y)
  (IF (< X Y) 'true 'false))

(DEFUN shen.greater-than-or-equal-to? (X Y)
  (IF (>= X Y) 'true 'false))

(DEFUN shen.less-than-or-equal-to? (X Y)
  (IF (<= X Y) 'true 'false))

(DEFUN number? (N)
  (IF (NUMBERP N) 'true 'false))

(DEFUN shen-cl.eval-print (X)
  (print (eval X)))

(DEFUN shen-cl.print-version ()
  (FORMAT T "~A~%" *version*)
  (FORMAT T "Shen CL ~A~%" *port*))

(DEFUN shen-cl.option-prefix? (Args Options)
  (AND (CONSP Args) (MEMBER (CAR Args) Options :TEST #'STRING-EQUAL)))

; Returns T if repl should be started
(DEFUN shen-cl.interpret-args (Args)
  (COND
    ((shen-cl.option-prefix? Args (LIST "-v" "--version"))
     (PROGN
       (shen-cl.print-version)
       NIL))
    ((shen-cl.option-prefix? Args (LIST "-h" "--help"))
     (PROGN
       (shen-cl.print-version)
       (FORMAT T "~%")
       (FORMAT T "Usage: shen [OPTIONS...]~%")
       (FORMAT T "  -v, --version       : Prints Shen, shen-cl version numbers and exits~%")
       (FORMAT T "  -h, --help          : Shows this help and exits~%")
       (FORMAT T "  -e, --eval <expr>   : Evaluates expr and prints result~%")
       (FORMAT T "  -l, --load <file>   : Reads and evaluates file~%")
       (FORMAT T "~%")
       (FORMAT T "Evaluates options in order~%")
       (FORMAT T "Starts the REPL if no eval/load options specified~%")
       NIL))
    ((shen-cl.option-prefix? Args (LIST "-e" "--eval"))
     (PROGN
       (LET ((Exprs (read-from-string (CADR Args))))
         (MAPC #'shen-cl.eval-print Exprs))
       (shen-cl.interpret-args (CDDR Args))
       NIL))
    ((shen-cl.option-prefix? Args (LIST "-l" "--load"))
     (PROGN
       (load (CADR Args))
       (shen-cl.interpret-args (CDDR Args))
       NIL))
    ((CONSP Args)
     (shen-cl.interpret-args (CDR Args)))
    (T
     T)))

(DEFUN shen-cl.toplevel ()

  #+CLISP
  (HANDLER-BIND
    ((WARNING #'MUFFLE-WARNING))
    (WITH-OPEN-STREAM (*STANDARD-INPUT* (EXT:MAKE-STREAM :INPUT :ELEMENT-TYPE 'UNSIGNED-BYTE))
      (WITH-OPEN-STREAM (*STANDARD-OUTPUT* (EXT:MAKE-STREAM :OUTPUT :ELEMENT-TYPE 'UNSIGNED-BYTE))
        (SETQ *stoutput* *STANDARD-OUTPUT*)
        (SETQ *stinput* *STANDARD-INPUT*)
        (SETQ *sterror* *ERROR-OUTPUT*)
        (LET ((Args EXT:*ARGS*))
          (SETQ *argv* Args)
          (IF (shen-cl.interpret-args Args)
            (shen.shen)
            (EXT:EXIT 0))))))

  #+CCL
  (HANDLER-BIND
    ((WARNING #'MUFFLE-WARNING))
    (LET ((Args (CDR *COMMAND-LINE-ARGUMENT-LIST*)))
      (SETQ *argv* Args)
      (IF (shen-cl.interpret-args Args)
        (shen.shen)
        (exit 0))))

  #+ECL
  (LET ((Args (CDR (SI:COMMAND-ARGS))))
    (SETQ *argv* Args)
    (IF (shen-cl.interpret-args Args)
      (shen.shen)
      (exit 0)))

  #+SBCL
  (LET ((Args (CDR SB-EXT:*POSIX-ARGV*)))
    (SETQ *argv* Args)
    (IF (shen-cl.interpret-args Args)
      (HANDLER-CASE (shen.shen)
        (SB-SYS:INTERACTIVE-INTERRUPT ()
          (exit 0)))
      (exit 0))))
