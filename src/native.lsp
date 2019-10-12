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

(defmacro |shen-cl.with-temp-readcase| (new-read-case &body body)
  (let ((old-read-case (readtable-case *readtable*))
        (result (gensym)))
  `(progn
     (setf (readtable-case *readtable*) ,new-read-case)
     (let ((,result ,@body))
       (setf (readtable-case *readtable*) ,old-read-case)
       ,result))))

(defun |shen-cl.load-lisp| (filespec &optional (readtable-case :upcase))
  (|shen-cl.with-temp-readcase| readtable-case
    (let ((*package* (find-package :common-lisp-user)))
      (load filespec))))

(defun |shen-cl.eval-lisp| (string &optional (package :common-lisp-user) (readtable-case :upcase))
  (|shen-cl.with-temp-readcase readtable-case|
    (let ((*package* (find-package package)))
     (eval (read-from-string string)))))
