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

#+(AND (NOT WINDOWS) (OR WIN32 WIN64 MINGW32)) (PUSH :WINDOWS *FEATURES*)
#+(AND (NOT MACOS) (OR APPLE DARWIN)) (PUSH :MACOS *FEATURES*)

#+ECL
(SETF *DEBUGGER-HOOK*
  #'(LAMBDA (e h) (DECLARE (IGNORE h)) (PRINT e) (SI:QUIT 1)))

(DEFVAR *language* "Common Lisp")
(DEFVAR *port* 2.2)
(DEFVAR *porters* "Mark Tarver")
(DEFVAR *os* (OR #+WINDOWS "Windows" #+MACOS "macOS" #+LINUX "Linux" #+UNIX "Unix" "Unknown"))
(DEFVAR *stinput* *STANDARD-INPUT*)
(DEFVAR *stoutput* *STANDARD-OUTPUT*)
(DEFVAR *sterror* *ERROR-OUTPUT*)
(DEFVAR *argv* NIL)
(DEFVAR *implementation* #+CLISP "GNU CLisp" #+CCL "Clozure CL" #+ECL "ECL" #+SBCL "SBCL")
(DEFVAR *release*
  #+CLISP (LET ((v (LISP-IMPLEMENTATION-VERSION))) (SUBSEQ v 0 (POSITION #\SPACE v :START 0)))
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

(DEFUN shen-cl.init ()
  #+CLISP (SETQ *stinput* (EXT:MAKE-STREAM :INPUT :ELEMENT-TYPE 'UNSIGNED-BYTE))
  #+CLISP (SETQ *stoutput* (EXT:MAKE-STREAM :OUTPUT :ELEMENT-TYPE 'UNSIGNED-BYTE))
  #+CLISP (SETQ *sterror* *stoutput*)

  (SETQ *argv*
    #+CLISP EXT:*ARGS*
    #+CCL   (CDR *COMMAND-LINE-ARGUMENT-LIST*)
    #+ECL   (CDR (SI:COMMAND-ARGS))
    #+SBCL  (CDR SB-EXT:*POSIX-ARGV*)))
