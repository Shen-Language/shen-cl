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

(DEFMACRO shen-cl.with-temp-readcase (new-read-case &BODY body)
  (LET ((old-read-case (READTABLE-CASE *READTABLE*))
        (result (GENSYM)))
  `(PROGN
     (SETF (READTABLE-CASE *READTABLE*) ,new-read-case)
     (LET ((,result ,@body))
       (SETF (READTABLE-CASE *READTABLE*) ,old-read-case)
       ,result))))

(DEFUN shen-cl.load-lisp (FILESPEC &OPTIONAL (readtable-case :UPCASE))
  (shen-cl.with-temp-readcase readtable-case
    (LET ((*PACKAGE* (FIND-PACKAGE :COMMON-LISP-USER)))
      (LOAD FILESPEC))))

(DEFUN shen-cl.eval-lisp (string &OPTIONAL (package :COMMON-LISP-USER) (readtable-case :UPCASE))
  (shen-cl.with-temp-readcase readtable-case
    (LET ((*PACKAGE* (FIND-PACKAGE package)))
     (EVAL (READ-FROM-STRING string)))))
