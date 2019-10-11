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

(IN-PACKAGE :SHEN)

(DEFVAR |*stinput*| *STANDARD-INPUT*)
(DEFVAR |*stoutput*| *STANDARD-OUTPUT*)
(DEFVAR |*sterror*| *ERROR-OUTPUT*)
(DEFVAR |*language*| "Common Lisp")
(DEFVAR |*port*| "2.7.0")
(DEFVAR |*porters*| "Mark Tarver")

#+CLISP
(PROGN
  (DEFVAR |*implementation*| "GNU CLisp")
  (DEFVAR |*release*| (LET ((V (LISP-IMPLEMENTATION-VERSION))) (SUBSEQ V 0 (POSITION #\SPACE V :START 0))))
  (DEFVAR |*os*| (OR #+WIN32 "Windows" #+LINUX "Linux" #+MACOS "macOS" #+UNIX "Unix" "Unknown")))

#+CCL
(PROGN
  (DEFVAR |*implementation*| "Clozure CL")
  (DEFVAR |*release*| (LISP-IMPLEMENTATION-VERSION))
  (DEFVAR |*os*| (OR #+WINDOWS "Windows" #+LINUX "Linux" #+DARWIN "macOS" #+UNIX "Unix" "Unknown")))

#+ECL
(PROGN
  (DEFVAR |*implementation*| "ECL")
  (DEFVAR |*release*| (LISP-IMPLEMENTATION-VERSION))
  (DEFVAR |*os*| (OR #+(OR :WIN32 :MINGW32) "Windows" #+LINUX "Linux" #+APPLE "macOS" #+UNIX "Unix" "Unknown"))
  (SETQ COMPILER::*COMPILE-VERBOSE* NIL)
  (SETQ COMPILER::*SUPPRESS-COMPILER-MESSAGES* NIL)
  (EXT:SET-LIMIT 'EXT:C-STACK (* 1024 1024)))

#+SBCL
(PROGN
  (DEFVAR |*implementation*| "SBCL")
  (DEFVAR |*release*| (LISP-IMPLEMENTATION-VERSION))
  (DEFVAR |*os*| (OR #+WIN32 "Windows" #+LINUX "Linux" #+DARWIN "macOS" #+UNIX "Unix" "Unknown"))
  (DECLAIM (INLINE |write-byte|))
  (DECLAIM (INLINE |read-byte|))
  (DECLAIM (INLINE |shen-cl.double-precision|)))

(DEFMACRO |if| (X Y Z)
  `(LET ((*C* ,X))
    (COND
      ((EQ *C* '|true|)  ,Y)
      ((EQ *C* '|false|) ,Z)
      (T               (ERROR "~S is not a boolean~%" *C*)))))

(DEFMACRO |and| (X Y)
  `(|if| ,X (|if| ,Y '|true| '|false|) '|false|))

(DEFMACRO |or| (X Y)
  `(|if| ,X '|true| (|if| ,Y '|true| '|false|)))

(DEFUN |set| (X Y)
  (SET X Y))

(DEFUN |value| (X)
  (SYMBOL-VALUE X))

(DEFUN |simple-error| (String)
  (ERROR "~A" String))

(DEFMACRO |trap-error| (X F)
  `(HANDLER-CASE ,X (ERROR (Condition) (FUNCALL ,F Condition))))

(DEFUN |error-to-string| (E)
  (IF (TYPEP E 'CONDITION)
    (FORMAT NIL "~A" E)
    (ERROR "~S is not an exception~%" E)))

(DEFUN |cons| (X Y)
  (CONS X Y))

(DEFUN |hd| (X)
  (CAR X))

(DEFUN |tl| (X)
  (CDR X))

(DEFUN |cons?| (X)
  (IF (CONSP X) '|true| '|false|))

(DEFUN |intern| (String)
  (INTERN (|shen-cl.process-intern| String)))

(DEFUN |shen-cl.process-intern| (S)
  (COND
    ((STRING-EQUAL S "")          S)
    ((STRING-EQUAL (|pos| S 0) "#") (|cn| "_hash1957" (|shen-cl.process-intern| (|tlstr| S))))
    ((STRING-EQUAL (|pos| S 0) "'") (|cn| "_quote1957" (|shen-cl.process-intern| (|tlstr| S))))
    ((STRING-EQUAL (|pos| S 0) "`") (|cn| "_backquote1957" (|shen-cl.process-intern| (|tlstr| S))))
    ((STRING-EQUAL (|pos| S 0) "|") (|cn| "bar!1957" (|shen-cl.process-intern| (|tlstr| S))))
    (T                            (|cn| (|pos| S 0) (|shen-cl.process-intern| (|tlstr| S))))))

(DEFUN |eval-kl| (X)
  (LET ((E (EVAL (|shen-cl.kl->lisp| X))))
    (IF (AND (CONSP X) (EQ (CAR X) '|defun|))
      (COMPILE E)
      E)))

(DEFMACRO |lambda| (X Y)
  `(FUNCTION (LAMBDA (,X) ,Y)))

(DEFMACRO |let| (X Y Z)
  `(LET ((,X ,Y)) ,Z))

(DEFMACRO |freeze| (X)
  `(FUNCTION (LAMBDA () ,X)))

(DEFUN |absvector| (N)
  (MAKE-ARRAY (LIST N)))

(DEFUN |absvector?| (X)
  (IF (AND (ARRAYP X) (NOT (STRINGP X))) '|true| '|false|))

(DEFUN |address->| (Vector N Value)
  (SETF (SVREF Vector N) Value) Vector)

(DEFUN |<-address| (Vector N)
  (SVREF Vector N))

(DEFUN |shen-cl.value/or| (Var Default)
  (IF (BOUNDP Var)
      (SYMBOL-VALUE Var)
      (FUNCALL Default)))

(DEFUN |shen-cl.get/or| (Var Prop Dict Default)
  (MULTIPLE-VALUE-BIND (Entry Found) (GETHASH Var Dict)
    (IF Found
        (LET ((Res (ASSOC Prop Entry :TEST #'EQ)))
          (IF Res
              (CDR Res)
              (FUNCALL Default)))
        (FUNCALL Default))))

(DEFUN |shen-cl.<-address/or| (Vector N Default)
  (IF (>= N (LENGTH Vector))
      (|thaw| Default)
      (SVREF Vector N)))

(DEFUN |shen-cl.<-vector/or| (Vector N Default)
  (IF (ZEROP N)
      (|thaw| Default)
      (LET ((VectorElement (SVREF Vector N)))
        (IF (EQ VectorElement (|fail|))
            (|thaw| Default)
            VectorElement))))

(DEFUN |shen-cl.equal?| (X Y)
  (IF (|shen-cl.absequal| X Y) '|true| '|false|))

(DEFUN |shen-cl.absequal| (X Y)
  (COND
    ((AND (CONSP X) (CONSP Y) (|shen-cl.absequal| (CAR X) (CAR Y)))
     (|shen-cl.absequal| (CDR X) (CDR Y)))
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
    (OR (ZEROP LX)
        (CF-VECTORS-HELP X Y 0 (1- LX)))))

(DEFUN CF-VECTORS-HELP (X Y COUNT MAX)
  (COND
    ((= COUNT MAX)
     (|shen-cl.absequal| (AREF X MAX) (AREF Y MAX)))
    ((|shen-cl.absequal| (AREF X COUNT) (AREF Y COUNT))
     (CF-VECTORS-HELP X Y (1+ COUNT) MAX))
    (T
     NIL)))

(DEFUN |write-byte| (Byte S)
  (WRITE-BYTE Byte S))

(DEFUN |read-byte| (S)
  (READ-BYTE S NIL -1))

(DEFUN |open| (String Direction)
  (LET ((Path (FORMAT NIL "~A~A" |*home-directory*| String)))
    (|shen.openh| Path Direction)))

(DEFUN |shen.openh| (Path Direction)
  (COND
    ((EQ Direction '|in|)
     (OPEN Path
      :DIRECTION :INPUT
      :ELEMENT-TYPE
        #+CLISP 'UNSIGNED-BYTE
        #-CLISP :DEFAULT))
    ((EQ Direction '|out|)
     (OPEN Path
      :DIRECTION :OUTPUT
      :ELEMENT-TYPE
        #+CLISP 'UNSIGNED-BYTE
        #-CLISP :DEFAULT
      :IF-EXISTS :SUPERSEDE))
    (T
     (ERROR "invalid direction"))))

(DEFUN |type| (X MyType)
  (DECLARE (IGNORE MyType))
  X)

(DEFUN |close| (Stream)
  (CLOSE Stream)
  NIL)

(DEFUN |pos| (X N)
  (COERCE (LIST (CHAR X N)) 'STRING))

(DEFUN |tlstr| (X)
  (SUBSEQ X 1))

(DEFUN |cn| (Str1 Str2)
  (DECLARE (TYPE STRING Str1) (TYPE STRING Str2))
  (CONCATENATE 'STRING Str1 Str2))

(DEFUN |string?| (S)
  (IF (STRINGP S) '|true| '|false|))

(DEFUN |n->string| (N)
  (FORMAT NIL "~C" (CODE-CHAR N)))

(DEFUN |string->n| (S)
  (CHAR-CODE (CAR (COERCE S 'LIST))))

(DEFUN |str| (X)
  (COND
    ((NULL X)      (ERROR "[] is not an atom in Shen; str cannot convert it to a string.~%"))
    ((SYMBOLP X)   (|shen-cl.process-string| (SYMBOL-NAME X)))
    ((NUMBERP X)   (|shen-cl.process-number| (FORMAT NIL "~A" X)))
    ((STRINGP X)   (FORMAT NIL "~S" X))
    ((STREAMP X)   (FORMAT NIL "~A" X))
    ((FUNCTIONP X) (FORMAT NIL "~A" X))
    (T             (ERROR "~S is not an atom, stream or closure; str cannot convert it to a string.~%" X))))

(DEFUN |shen-cl.process-number| (S)
  (COND
    ((STRING-EQUAL S "")
     "")
    ((STRING-EQUAL (|pos| S 0) "d")
     (IF (STRING-EQUAL (|pos| S 1) "0") "" (|cn| "e" (|tlstr| S))))
    (T
     (|cn| (|pos| S 0) (|shen-cl.process-number| (|tlstr| S))))))

(DEFUN |shen-cl.prefix?| (Str Prefix)
  (LET ((Prefix-Length (LENGTH Prefix)))
    (AND
      (>= (LENGTH Str) Prefix-Length)
      (STRING-EQUAL Str Prefix :END1 Prefix-Length))))

(DEFUN |shen-cl.true?| (X)
  (COND
    ((EQ '|true| X)  'T)
    ((EQ '|false| X) ())
    (T (|simple-error| (FORMAT NIL "boolean expected: not ~A~%" X)))))

(DEFUN |shen-cl.lisp-true?| (X)
  (IF X '|true| '|false|))

(DEFUN |shen-cl.lisp-function-name| (Symbol)
  (LET* ((Str (|str| Symbol))
         (LispName (STRING-UPCASE (SUBSTITUTE #\: #\. (SUBSEQ Str 5)))))
    (INTERN LispName)))

(DEFUN |shen-cl.lisp-prefixed?| (Symbol)
  (|shen-cl.lisp-true?|
    (AND (NOT (NULL Symbol))
         (SYMBOLP Symbol)
         (|shen-cl.prefix?| (str Symbol) "lisp."))))

(DEFUN |shen-cl.process-string| (X)
  (COND
    ((STRING-EQUAL X "")                    X)
    ((|shen-cl.prefix?| X "_hash1957")      (|cn| "#" (|shen-cl.process-string| (SUBSEQ X 9))))
    ((|shen-cl.prefix?| X "_quote1957")     (|cn| "'" (|shen-cl.process-string| (SUBSEQ X 10))))
    ((|shen-cl.prefix?| X "_backquote1957") (|cn| "`" (|shen-cl.process-string| (SUBSEQ X 14))))
    ((|shen-cl.prefix?| X "bar!1957")       (|cn| "|" (|shen-cl.process-string| (SUBSEQ X 8))))
    (T                                      (|cn| (|pos| X 0) (|shen-cl.process-string| (|tlstr| X))))))

(DEFUN |get-time| (Time)
  (COND
    ((EQ Time '|run|)  (* 1.0 (/ (GET-INTERNAL-RUN-TIME) INTERNAL-TIME-UNITS-PER-SECOND)))
    ((EQ Time '|unix|) (- (GET-UNIVERSAL-TIME) 2208988800))
    (T                 (ERROR "get-time does not understand the parameter ~A~%" Time))))

(DEFUN |shen-cl.double-precision| (X)
  (IF (INTEGERP X) X (COERCE X 'DOUBLE-FLOAT)))

(DEFUN |shen-cl.multiply| (X Y)
  (IF (OR (ZEROP X) (ZEROP Y))
    0
    (* (|shen-cl.double-precision| X) (|shen-cl.double-precision| Y))))

(DEFUN |shen-cl.add| (X Y)
  (+ (|shen-cl.double-precision| X) (|shen-cl.double-precision| Y)))

(DEFUN |shen-cl.subtract| (X Y)
  (- (|shen-cl.double-precision| X) (|shen-cl.double-precision| Y)))

(DEFUN |shen-cl.divide| (X Y)
  (LET ((Div (/ (|shen-cl.double-precision| X)
                (|shen-cl.double-precision| Y))))
    (IF (INTEGERP Div)
      Div
      (* (COERCE 1.0 'DOUBLE-FLOAT) Div))))

(DEFUN |shen-cl.greater?| (X Y)
  (IF (> X Y) '|true| '|false|))

(DEFUN |shen-cl.less?| (X Y)
  (IF (< X Y) '|true| '|false|))

(DEFUN |shen-cl.greater-than-or-equal-to?| (X Y)
  (IF (>= X Y) '|true| '|false|))

(DEFUN |shen-cl.less-than-or-equal-to?| (X Y)
  (IF (<= X Y) '|true| '|false|))

(DEFUN |number?| (N)
  (IF (NUMBERP N) '|true| '|false|))

(DEFUN |shen-cl.repl| ()

  #+SBCL
  (HANDLER-CASE (|shen.repl|)
    (SB-SYS:INTERACTIVE-INTERRUPT ()
      (|cl.exit| 0)))

  #-SBCL
  (|shen.repl|))

(DEFUN |shen-cl.read-eval| (Str)
  (CAR (LAST (MAPC #'|eval| (|read-from-string| Str)))))


(DEFUN |shen-cl.toplevel-interpret-args| (Args)
  (|trap-error|
    (LET ((Result (|shen.x.launcher.launch-shen| Args)))
      (COND
        ((EQ 'error (CAR Result))
         (PROGN
          (|shen.x.launcher.default-handle-result| Result)
          (|cl.exit| 1)))
        ((EQ 'unknown-arguments (CAR Result))
         (PROGN
          (|shen.x.launcher.default-handle-result| Result)
          (|cl.exit| 1)))
        (T
         (PROGN
          (|shen.x.launcher.default-handle-result| Result)
          (|cl.exit| 0)))))
    (|lambda| E
      (PROGN
        (FORMAT T "~%!!! FATAL ERROR: ")
        (|shen.toplevel-display-exception| E)
        (FORMAT T "~%Exiting Shen.~%")
        (|cl.exit| 1)))))

(DEFUN |shen-cl.toplevel| ()
  (LET ((*PACKAGE* (FIND-PACKAGE :SHEN)))

    #+CLISP
    (HANDLER-BIND ((WARNING #'MUFFLE-WARNING))
      (WITH-OPEN-STREAM (*STANDARD-INPUT* (EXT:MAKE-STREAM :INPUT :ELEMENT-TYPE 'UNSIGNED-BYTE))
        (WITH-OPEN-STREAM (*STANDARD-OUTPUT* (EXT:MAKE-STREAM :OUTPUT :ELEMENT-TYPE 'UNSIGNED-BYTE))
          (SETQ |*stoutput*| *STANDARD-OUTPUT*)
          (SETQ |*stinput*| *STANDARD-INPUT*)
          (LET ((Args (CONS (CAR (COERCE (EXT:ARGV) 'LIST)) EXT:*ARGS*)))
            (|shen-cl.toplevel-interpret-args| Args)))))

    #+CCL
    (HANDLER-BIND ((WARNING #'MUFFLE-WARNING))
      (|shen-cl.toplevel-interpret-args| *COMMAND-LINE-ARGUMENT-LIST*))

    #+ECL
    (PROGN
     (|shen.initialise|)
     (|shen-cl.initialise|)
     (|shen.x.features.initialise| '(|shen/cl| |shen/cl.ecl|))
     (|shen-cl.toplevel-interpret-args| (SI:COMMAND-ARGS)))

    #+SBCL
    (|shen-cl.toplevel-interpret-args| SB-EXT:*POSIX-ARGV*)))
