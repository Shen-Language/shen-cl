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

(DEFUN shen.pvar? (x)
  (IF (AND (ARRAYP x) (NOT (STRINGP x)) (EQ (SVREF x 0) 'shen.pvar))
    'true
    'false))

(DEFUN shen.lazyderef (x n)
  (IF (AND (ARRAYP x) (NOT (STRINGP x)) (EQ (SVREF x 0) 'shen.pvar))
    (LET ((val (shen.valvector x n)))
      (IF (EQ val 'shen.-null-)
        x
        (shen.lazyderef val n)))
    x))

(DEFUN shen.valvector (var n)
  (SVREF (SVREF shen.*prologvectors* n) (SVREF var 1)))

(DEFUN shen.unbindv (var n)
  (LET ((vec (SVREF shen.*prologvectors* n)))
    (SETF (SVREF vec (SVREF var 1)) 'shen.-null-)))

(DEFUN shen.bindv (var val n)
  (LET ((vec (SVREF shen.*prologvectors* n)))
    (SETF (SVREF vec (SVREF var 1)) val)))

(DEFUN shen.copy-vector-stage-1 (index source dest size)
  (IF (= size index)
    dest
    (shen.copy-vector-stage-1
      (1+ index)
      source
      (address-> dest index (<-address source index))
      size)))

(DEFUN shen.copy-vector-stage-2 (index size val dest)
  (IF (= size index)
    dest
    (shen.copy-vector-stage-2
      (1+ index)
      size
      val
      (address-> dest index val))))

(DEFUN shen.newpv (n)
  (LET ((counter (1+ (THE INTEGER (SVREF shen.*varcounter* n))))
        (vec     (SVREF shen.*prologvectors* n)))
    (SETF (SVREF shen.*varcounter* n) counter)
    (IF (= (THE INTEGER counter) (THE INTEGER (limit vec)))
      (shen.resizeprocessvector n counter)
      'skip)
    (shen.mk-pvar counter)))

(DEFUN vector-> (vec n x)
  (IF (ZEROP n)
    (ERROR "cannot access 0th element of a vector~%")
    (address-> vec n x)))

(DEFUN <-vector (vec n)
  (IF (ZEROP n)
    (ERROR "cannot access 0th element of a vector~%")
    (LET ((x (SVREF vec n)))
      (IF (EQ x (fail))
        (ERROR "vector element not found~%")
        x))))

(DEFUN variable? (x)
  (IF (AND (SYMBOLP x) (NOT (NULL x)) (UPPER-CASE-P (CHAR (SYMBOL-NAME x) 0)))
    'true
    'false))

(DEFUN shen.+string? (x)
  (IF (AND (STRINGP x) (NOT (STRING-EQUAL x "")))
    'true
    'false))

(DEFUN thaw (fn)
  (FUNCALL fn))

#+CLISP
(DEFUN exit (code)
  (EXT:EXIT code))

#+(AND CCL (NOT WINDOWS))
(DEFUN exit (code)
  (CCL:QUIT code))

#+(AND CCL WINDOWS)
(CCL::EVAL (CCL::READ-FROM-STRING "(DEFUN exit (code) (#__exit code))"))

#+ECL
(DEFUN exit (code)
  (SI:QUIT code))

#+SBCL
(DEFUN exit (code)
  (ALIEN-FUNCALL (EXTERN-ALIEN "exit" (FUNCTION VOID INT)) code))

#+(OR CCL SBCL)
(DEFUN read-char-code (s)
  (LET ((ch (READ-CHAR s NIL -1)))
    (IF (EQ ch -1)
      -1
      (CHAR-INT ch))))

#+(OR CCL SBCL)
(DEFUN pr (x s)
  (WRITE-STRING x s)
  (WHEN (OR (EQ s *stoutput*) (EQ s *sterror*))
    (FORCE-OUTPUT s))
  x)
