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

(DEFMACRO if (c x y)
  `(IF (shen-cl.true? ,c) ,x ,y))

(DEFMACRO and (x y)
  `(if ,x (if ,y 'true 'false) 'false))

(DEFMACRO or (x y)
  `(if ,x 'true (if ,y 'true 'false)))

(DEFMACRO trap-error (body handler)
  (LET ((e (GENSYM)))
    `(HANDLER-CASE ,body (ERROR (,e) (FUNCALL ,handler ,e)))))

(DEFMACRO let (var val body)
  `(LET ((,var ,val)) ,body))

(DEFMACRO lambda (param body)
  `(FUNCTION (LAMBDA (,param) ,body)))

(DEFMACRO freeze (x)
  `(FUNCTION (LAMBDA () ,x)))

(DEFUN set (s x)
  (SET s x))

(DEFUN value (s)
  (SYMBOL-VALUE s))

(DEFUN simple-error (s)
  (ERROR "~A" s))

(DEFUN error-to-string (e)
  (IF (TYPEP e 'CONDITION)
    (FORMAT NIL "~A" e)
    (ERROR "~S is not an exception~%" e)))

(DEFUN cons (x y)
  (CONS x y))

(DEFUN hd (x)
  (IF (CONSP x) (CAR x) (ERROR "~S is not a cons~%" x)))

(DEFUN tl (x)
  (IF (CONSP x) (CDR x) (ERROR "~S is not a cons~%" x)))

(DEFUN cons? (x)
  (IF (CONSP x) 'true 'false))

(DEFUN intern (s)
  (DECLARE (TYPE STRING s))
  (INTERN (shen-cl.escape s)))

(DEFUN eval-kl (expr)
  (LET ((x (EVAL (shen-cl.kl->lisp () expr))))
    (IF (AND (CONSP expr) (EQ (CAR expr) 'defun))
      (COMPILE x)
      x)))

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
  (DECLARE (TYPE STRING s))
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
    ((NUMBERP x)   (shen-cl.clean-numeric (FORMAT NIL "~A" x)))
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
