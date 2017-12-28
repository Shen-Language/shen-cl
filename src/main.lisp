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
     (MAPC #'(LAMBDA (expr) (print (eval expr))) (read-from-string (CADR args)))
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

(DEFUN shen-cl.main ()
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
