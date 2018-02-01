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

; TODO: SBCL doesn't want this to be a DEFCONSTANT, thinks it's being redefined
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

(DEFUN shen-cl.clean-numeric (s)
  (LET ((index (SEARCH "d0" s)))
    (SUBSTITUTE  #\e #\d (IF index (SUBSEQ s 0 index) s))))

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

(DEFUN shen-cl.true? (x)
  (COND
    ((EQ 'true  x) 'T)
    ((EQ 'false x) 'NIL)
    (T (simple-error (cn "~S is not a boolean~%" x)))))
