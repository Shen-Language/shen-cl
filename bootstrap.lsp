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

(LOAD "src/package.lsp") ; Package code must be loaded before boot
                         ; code so that boot.lisp can be in the SHEN
                         ; package.

(IN-PACKAGE :SHEN)
(DEFVAR *BOOT-MODE* 'BOOTSTRAP)

(LOAD "boot.lsp")

#+ECL
(PROGN
 (shen.initialise)
 (shen-cl.initialise)

(DEFUN produce-kl (Shen)
  (COND
   ((AND (CONSP Shen) (EQ 'define (CAR Shen)) (CDR Shen))
    (shen.shen->kl (CAR (CDR Shen)) (CDR (CDR Shen))))
   (T Shen) (T (simple-error "No condition was true"))))

(LET* ((ShenCode (read-file "src/backend.shen"))
       (KlCode (MAPCAR #'(LAMBDA (X) (produce-kl X)) ShenCode))
       (CLCode (translate-kl KlCode)))
  (write-lsp-file "src/backend.lsp" CLCode)
  (shen-cl.exit 0))