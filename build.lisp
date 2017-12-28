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

(SETF (READTABLE-CASE *READTABLE*) :PRESERVE)
(PROCLAIM '(OPTIMIZE (DEBUG 0) (SPEED 3) (SAFETY 3)))
(IN-PACKAGE :CL-USER)

#+(AND (NOT WINDOWS) (OR WIN32 WIN64 MINGW32)) (PUSH :WINDOWS *FEATURES*)
#+(AND (NOT MACOS) (OR APPLE DARWIN)) (PUSH :MACOS *FEATURES*)

(SETF *DEBUGGER-HOOK*
  #'(LAMBDA (e h)
      (DECLARE (IGNORE h))
      (FORMAT T "~%~%Error: ~A~%~%" e)
      #+CLISP
        (EXT:EXIT 1)
      #+(AND CCL (NOT WINDOWS))
        (CCL:QUIT 1)
      #+(AND CCL WINDOWS)
        (CCL::EVAL (CCL::READ-FROM-STRING "(#__exit 1)"))
      #+ECL
        (SI:QUIT 1)
      #+SBCL
        (ALIEN-FUNCALL (EXTERN-ALIEN "exit" (FUNCTION VOID INT)) 1)))

(DEFVAR shen-cl.klambda-path "./kernel/klambda/")
(DEFVAR shen-cl.source-path "./src/")
(DEFVAR shen-cl.binary-name "shen")
(DEFVAR shen-cl.executable-suffix (OR #+WINDOWS ".exe" ""))
(DEFVAR shen-cl.static-library-suffix (OR #+WINDOWS ".lib" ".a"))
(DEFVAR shen-cl.shared-library-suffix (OR #+WINDOWS ".dll" #+MACOS ".dylib" ".so"))
(DEFVAR shen-cl.object-suffix (OR #+WINDOWS ".obj" ".o"))
(DEFVAR shen-cl.compiled-suffix (OR #+CCL (NAMESTRING *.FASL-PATHNAME*) #+SBCL ".fasl" ".fas"))
(DEFVAR shen-cl.binary-path (FORMAT NIL "./bin/~A/" #+CLISP "clisp" #+CCL "ccl" #+ECL "ecl" #+SBCL "sbcl"))
(DEFVAR shen-cl.binary-path-root (FORMAT NIL "~A~A" shen-cl.binary-path shen-cl.binary-name))
(DEFVAR shen-cl.executable-path (FORMAT NIL "~A~A" shen-cl.binary-path-root shen-cl.executable-suffix))
(DEFVAR shen-cl.static-library-path (FORMAT NIL "~A~A" shen-cl.binary-path-root shen-cl.static-library-suffix))
(DEFVAR shen-cl.shared-library-path (FORMAT NIL "~A~A" shen-cl.binary-path-root shen-cl.shared-library-suffix))

#+CLISP
(PROGN
  (SETQ CUSTOM:*COMPILE-WARNINGS* NIL)
  (SETQ CUSTOM:*SUPPRESS-CHECK-REDEFINITION* T)
  (SETQ *COMPILE-VERBOSE* NIL))

#+ECL
(PROGN
  (DEFVAR shen-cl.*object-files* ())
  (EXT:INSTALL-C-COMPILER)
  (SETQ COMPILER::*COMPILE-VERBOSE* NIL)
  (SETQ COMPILER::*SUPPRESS-COMPILER-MESSAGES* NIL))

#+SBCL
(PROGN
  (DECLAIM (SB-EXT:MUFFLE-CONDITIONS SB-EXT:COMPILER-NOTE))
  (SETF SB-EXT:*MUFFLED-WARNINGS* T))

;
; Confirm Pre-Requisites
;

(WHEN (NOT (PROBE-FILE (FORMAT NIL "~A~A" shen-cl.klambda-path "core.kl")))
  (FORMAT T "~%")
  (FORMAT T "Directory ~S not found.~%" shen-cl.klambda-path)
  (FORMAT T "Run 'make fetch' to retrieve Shen Kernel sources.~%")
  (QUIT))

(ENSURE-DIRECTORIES-EXIST shen-cl.binary-path)

;
; Implementation-Specific Loading Procedure
;

#-ECL
(DEFUN shen-cl.compile-lisp (file)
  (LET ((lisp-file (FORMAT NIL "~A~A.lisp" shen-cl.binary-path file)))
    (COMPILE-FILE lisp-file)))

#+ECL
(DEFUN shen-cl.compile-lisp (file)
  (LET ((lisp-file (FORMAT NIL "~A~A.lisp" shen-cl.binary-path file))
        (fas-file  (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.compiled-suffix))
        (obj-file  (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.object-suffix)))
    (COMPILE-FILE lisp-file :OUTPUT-FILE obj-file :SYSTEM-P T)
    (PUSH obj-file shen-cl.*object-files*)
    (C:BUILD-FASL fas-file :LISP-FILES (LIST obj-file))))

;
; Shared Loading Procedure
;

(DEFUN shen-cl.import-lisp (file)
  (LET ((src-file  (FORMAT NIL "~A~A.lisp" shen-cl.source-path file))
        (lisp-file (FORMAT NIL "~A~A.lisp" shen-cl.binary-path file))
        (fas-file  (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.compiled-suffix)))
    (shen-cl.copy-file src-file lisp-file)
    (shen-cl.compile-lisp file)
    (LOAD fas-file)))

(DEFUN shen-cl.import-kl (file)
  (LET ((kl-file   (FORMAT NIL "~A~A.kl" shen-cl.klambda-path file))
        (lisp-file (FORMAT NIL "~A~A.lisp" shen-cl.binary-path file))
        (fas-file  (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.compiled-suffix)))
    (shen-cl.write-lisp-file lisp-file (shen-cl.translate-kl (shen-cl.read-kl-file kl-file)))
    (shen-cl.compile-lisp file)
    (LOAD fas-file)))

(DEFUN shen-cl.read-kl-file (file)
  (WITH-OPEN-FILE
    (in file
      :DIRECTION :INPUT)
    (LET ((clean-code (shen-cl.clean-kl (READ-CHAR in NIL NIL) in NIL NIL)))
      (READ-FROM-STRING (FORMAT NIL "(~A)" (COERCE clean-code 'STRING))))))

(DEFUN shen-cl.clean-kl (ch in chars quoted)
  (IF (NULL ch)
    (REVERSE chars)
    (shen-cl.clean-kl
      (READ-CHAR in NIL NIL)
      in
      (IF (AND (NOT quoted) (MEMBER ch '(#\: #\; #\,) :TEST 'CHAR-EQUAL))
        (LIST* #\| ch #\| chars)
        (CONS ch chars))
      (IF (CHAR-EQUAL ch #\")
        (NOT quoted)
        quoted))))

(DEFUN shen-cl.translate-kl (kl-code)
  (MAPCAR #'(LAMBDA (expr) (shen-cl.kl->lisp () expr)) kl-code))

(DEFUN shen-cl.write-lisp-file (file code)
  (WITH-OPEN-FILE
    (out file
      :DIRECTION         :OUTPUT
      :IF-EXISTS         :SUPERSEDE
      :IF-DOES-NOT-EXIST :CREATE)
    (MAPC #'(LAMBDA (expr) (FORMAT out "~S~%~%" expr)) code)
    file))

(DEFUN shen-cl.copy-file (src-file dest-file)
  (WITH-OPEN-FILE
    (in src-file
      :DIRECTION    :INPUT
      :ELEMENT-TYPE '(UNSIGNED-BYTE 8))
    (WITH-OPEN-FILE
      (out dest-file
        :DIRECTION         :OUTPUT
        :IF-EXISTS         :SUPERSEDE
        :IF-DOES-NOT-EXIST :CREATE
        :ELEMENT-TYPE      '(UNSIGNED-BYTE 8))
      (LET ((buf (MAKE-ARRAY 4096 :ELEMENT-TYPE (STREAM-ELEMENT-TYPE in))))
        (LOOP FOR pos = (READ-SEQUENCE buf in)
          WHILE (PLUSP pos)
          DO (WRITE-SEQUENCE buf out :END pos))))))

(COMPILE 'shen-cl.compile-lisp)
(COMPILE 'shen-cl.import-lisp)
(COMPILE 'shen-cl.import-kl)
(COMPILE 'shen-cl.read-kl-file)
(COMPILE 'shen-cl.clean-kl)
(COMPILE 'shen-cl.translate-kl)
(COMPILE 'shen-cl.write-lisp-file)
(COMPILE 'shen-cl.copy-file)

(shen-cl.import-lisp "init")
(shen-cl.import-lisp "internal")
(shen-cl.import-lisp "primitives")
(shen-cl.import-lisp "backend")
(shen-cl.import-kl "toplevel")
(shen-cl.import-kl "core")
(shen-cl.import-kl "sys")
(shen-cl.import-kl "sequent")
(shen-cl.import-kl "yacc")
(shen-cl.import-kl "reader")
(shen-cl.import-kl "prolog")
(shen-cl.import-kl "track")
(shen-cl.import-kl "load")
(shen-cl.import-kl "writer")
(shen-cl.import-kl "macros")
(shen-cl.import-kl "declarations")
(shen-cl.import-kl "types")
(shen-cl.import-kl "t-star")
(shen-cl.import-lisp "overwrite")
(shen-cl.import-lisp "platform")
(shen-cl.import-lisp "main")

;
; Implementation-Specific Binary Output
;

#+CLISP
(PROGN
  (EXT:SAVEINITMEM
    shen-cl.executable-path
    :EXECUTABLE 0
    :QUIET T
    :INIT-FUNCTION 'shen-cl.main)
  (QUIT))

#+CCL
(PROGN
  (CCL:SAVE-APPLICATION
    shen-cl.executable-path
    :PREPEND-KERNEL T
    :TOPLEVEL-FUNCTION 'shen-cl.main)
  (CCL:QUIT))

#+ECL
(PROGN
  (SETQ shen-cl.*object-files* (REVERSE shen-cl.*object-files*))
  (C:BUILD-PROGRAM
    shen-cl.executable-path
    :LISP-FILES shen-cl.*object-files*
    :EPILOGUE-CODE '(shen-cl.main))
  (C:BUILD-STATIC-LIBRARY
    shen-cl.static-library-path
    :LISP-FILES shen-cl.*object-files*
    :EPILOGUE-CODE '(shen-cl.init)
    :INIT-NAME "shen_init")
  (C:BUILD-SHARED-LIBRARY
    shen-cl.shared-library-path
    :LISP-FILES shen-cl.*object-files*
    :EPILOGUE-CODE '(shen-cl.init)
    :INIT-NAME "shen_init")
  (SI:QUIT))

#+SBCL
(SB-EXT:SAVE-LISP-AND-DIE
  shen-cl.executable-path
  :EXECUTABLE T
  :SAVE-RUNTIME-OPTIONS T
  :TOPLEVEL 'shen-cl.main)
