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
  #'(LAMBDA (C H) (DECLARE (IGNORE H)) (PRINT C) (SI:QUIT 1)))

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
  #+CLISP (LET ((V (LISP-IMPLEMENTATION-VERSION))) (SUBSEQ V 0 (POSITION #\SPACE V :START 0)))
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

(DEFUN shen-cl.escape (S)
  (COND
    ((STRING-EQUAL S "")          S)
    ((STRING-EQUAL (pos S 0) "#") (cn "_hash1957" (shen-cl.escape (tlstr S))))
    ((STRING-EQUAL (pos S 0) "'") (cn "_quote1957" (shen-cl.escape (tlstr S))))
    ((STRING-EQUAL (pos S 0) "`") (cn "_backquote1957" (shen-cl.escape (tlstr S))))
    ((STRING-EQUAL (pos S 0) "|") (cn "bar!1957" (shen-cl.escape (tlstr S))))
    (T                            (cn (pos S 0) (shen-cl.escape (tlstr S))))))

(DEFUN shen-cl.unescape (X)
  (COND
    ((STRING-EQUAL X "")                  X)
    ((shen-cl.prefix? X "_hash1957")      (cn "#" (shen-cl.unescape (SUBSEQ X 9))))
    ((shen-cl.prefix? X "_quote1957")     (cn "'" (shen-cl.unescape (SUBSEQ X 10))))
    ((shen-cl.prefix? X "_backquote1957") (cn "`" (shen-cl.unescape (SUBSEQ X 14))))
    ((shen-cl.prefix? X "bar!1957")       (cn "|" (shen-cl.unescape (SUBSEQ X 8))))
    (T                                    (cn (pos X 0) (shen-cl.unescape (tlstr X))))))

; Returns Lisp boolean
(DEFUN shen-cl.== (X Y)
  (COND
    ((AND (CONSP X) (CONSP Y) (shen-cl.== (CAR X) (CAR Y)))
     (shen-cl.== (CDR X) (CDR Y)))
    ((AND (STRINGP X) (STRINGP Y))
     (STRING= X Y))
    ((AND (NUMBERP X) (NUMBERP Y))
     (= X Y))
    ((AND (ARRAYP X) (ARRAYP Y))
     (AND (= (LENGTH X) (LENGTH Y)) (shen-cl.array= X Y 0 (LENGTH X))))
    (T
     (EQUAL X Y))))

(DEFUN shen-cl.array= (X Y Index Size)
  (OR
    (= Index Size)
    (AND
      (shen-cl.== (AREF X Index) (AREF Y Index))
      (shen-cl.array= X Y (1+ Index) Size))))

(DEFUN shen-cl.process-number (S)
  (COND
    ((STRING-EQUAL S "")
     "")
    ((STRING-EQUAL (pos S 0) "d")
     (IF (STRING-EQUAL (pos S 1) "0") "" (cn "e" (tlstr S))))
    (T
     (cn (pos S 0) (shen-cl.process-number (tlstr S))))))

(DEFUN shen-cl.prefix? (Str Prefix)
  (LET ((Prefix-Length (LENGTH Prefix)))
    (AND
      (>= (LENGTH Str) Prefix-Length)
      (STRING-EQUAL Str Prefix :END1 Prefix-Length))))

(DEFUN shen-cl.open-file (Path Direction)
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

(DEFUN shen-cl.double (X)
  (IF (INTEGERP X) X (COERCE X 'DOUBLE-FLOAT)))

(DEFUN shen-cl.* (X Y)
  (IF (OR (ZEROP X) (ZEROP Y))
    0
    (* (shen-cl.double X) (shen-cl.double Y))))

(DEFUN shen-cl.+ (X Y)
  (+ (shen-cl.double X) (shen-cl.double Y)))

(DEFUN shen-cl.- (X Y)
  (- (shen-cl.double X) (shen-cl.double Y)))

(DEFUN shen-cl./ (X Y)
  (LET ((Div (/ (shen-cl.double X) (shen-cl.double Y))))
    (IF (INTEGERP Div)
      Div
      (* (COERCE 1.0 'DOUBLE-FLOAT) Div))))

(DEFUN shen-cl.> (X Y)
  (IF (> X Y) 'true 'false))

(DEFUN shen-cl.< (X Y)
  (IF (< X Y) 'true 'false))

(DEFUN shen-cl.>= (X Y)
  (IF (>= X Y) 'true 'false))

(DEFUN shen-cl.<= (X Y)
  (IF (<= X Y) 'true 'false))

; Returns Shen boolean
(DEFUN shen-cl.= (X Y)
  (IF (shen-cl.== X Y) 'true 'false))

;
; KL Primitive Definitions
;

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
  (INTERN (shen-cl.escape String)))

(DEFUN eval-kl (X)
  (LET ((E (EVAL (shen-cl.kl->lisp NIL X))))
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

(DEFUN write-byte (Byte S)
  (WRITE-BYTE Byte S))

(DEFUN read-byte (S)
  (READ-BYTE S NIL -1))

(DEFUN open (String Direction)
  (LET ((Path (FORMAT NIL "~A~A" *home-directory* String)))
    (shen-cl.open-file Path Direction)))

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
    ((SYMBOLP X)   (shen-cl.unescape (SYMBOL-NAME X)))
    ((NUMBERP X)   (shen-cl.process-number (FORMAT NIL "~A" X)))
    ((STRINGP X)   (FORMAT NIL "~S" X))
    ((STREAMP X)   (FORMAT NIL "~A" X))
    ((FUNCTIONP X) (FORMAT NIL "~A" X))
    (T             (ERROR "~S is not an atom, stream or closure; str cannot convert it to a string.~%" X))))

(DEFUN get-time (Time)
  (COND
    ((EQ Time 'run)  (* 1.0 (/ (GET-INTERNAL-RUN-TIME) INTERNAL-TIME-UNITS-PER-SECOND)))
    ((EQ Time 'unix) (- (GET-UNIVERSAL-TIME) 2208988800))
    (T               (ERROR "get-time does not understand the parameter ~A~%" Time))))

(DEFUN number? (N)
  (IF (NUMBERP N) 'true 'false))

;
; Shared Startup Procedures
;

(DEFUN shen-cl.eval-print (X)
  (print (eval X)))

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

(DEFUN shen-cl.option-prefix? (Args Options)
  (AND (CONSP Args) (MEMBER (CAR Args) Options :TEST #'STRING-EQUAL)))

; Returns T if repl should be started
(DEFUN shen-cl.interpret-args (Args)
  (COND
    ((shen-cl.option-prefix? Args (LIST "-v" "--version"))
       (shen-cl.print-version)
       NIL)
    ((shen-cl.option-prefix? Args (LIST "-h" "--help"))
       (shen-cl.print-version)
       (FORMAT T "~%")
       (shen-cl.print-help)
       NIL)
    ((shen-cl.option-prefix? Args (LIST "-e" "--eval"))
       (LET ((Exprs (read-from-string (CADR Args))))
         (MAPC #'shen-cl.eval-print Exprs))
       (shen-cl.interpret-args (CDDR Args))
       NIL)
    ((shen-cl.option-prefix? Args (LIST "-l" "--load"))
       (load (CADR Args))
       (shen-cl.interpret-args (CDDR Args))
       NIL)
    ((shen-cl.option-prefix? Args (LIST "-q" "--quiet"))
       (SETQ *hush* 'true)
       (shen-cl.interpret-args (CDR Args)))
    ((CONSP Args)
     (shen-cl.interpret-args (CDR Args)))
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
