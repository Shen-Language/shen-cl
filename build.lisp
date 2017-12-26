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

;
; Identify Environment
;

#+(AND (NOT WINDOWS) (OR WIN32 WIN64 MINGW32)) (PUSH :WINDOWS *FEATURES*)
#+(AND (NOT MACOS) (OR APPLE DARWIN)) (PUSH :MACOS *FEATURES*)

;
; Disable Debugging
;

(SETF *DEBUGGER-HOOK*
  #'(LAMBDA (Error H)
      (DECLARE (IGNORE H))
      (FORMAT T "~%~%Error: ~A~%~%" Error)
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

;
; Initial Setup
;

(SETF (READTABLE-CASE *READTABLE*) :PRESERVE)
(PROCLAIM '(OPTIMIZE (DEBUG 0) (SPEED 3) (SAFETY 3)))
(IN-PACKAGE :CL-USER)
(DEFVAR shen-cl.klambda-path "./kernel/klambda/")
(DEFVAR shen-cl.source-path "./src/")
(DEFVAR shen-cl.binary-name "shen")

;
; Confirm Pre-Requisites
;

(WHEN (NOT (PROBE-FILE (FORMAT NIL "~A~A" shen-cl.klambda-path "core.kl")))
  (FORMAT T "~%")
  (FORMAT T "Directory ~S not found.~%" shen-cl.klambda-path)
  (FORMAT T "Run 'make fetch' to retrieve Shen Kernel sources.~%")
  (QUIT))

;
; OS-Specific Declarations
;

(DEFVAR shen-cl.executable-suffix (OR #+WINDOWS ".exe" ""))
(DEFVAR shen-cl.static-library-suffix (OR #+WINDOWS ".lib" ".a"))
(DEFVAR shen-cl.shared-library-suffix (OR #+WINDOWS ".dll" #+MACOS ".dylib" ".so"))
(DEFVAR shen-cl.object-suffix (OR #+WINDOWS ".obj" ".o"))

;
; Implementation-Specific Declarations
;

(DEFVAR shen-cl.compiled-suffix (OR #+CCL (NAMESTRING *.FASL-PATHNAME*) #+SBCL ".fasl" ".fas"))
(DEFVAR shen-cl.binary-folder #+CLISP "clisp" #+CCL "ccl" #+ECL "ecl" #+SBCL "sbcl")

#+CLISP
(PROGN
  (SETQ CUSTOM:*COMPILE-WARNINGS* NIL)
  (SETQ *COMPILE-VERBOSE* NIL))

#+ECL
(PROGN
  (DEFVAR shen-cl.*object-files* NIL)
  (EXT:INSTALL-C-COMPILER)
  (SETQ COMPILER::*COMPILE-VERBOSE* NIL)
  (SETQ COMPILER::*SUPPRESS-COMPILER-MESSAGES* NIL))

#+SBCL
(PROGN
  (DECLAIM (SB-EXT:MUFFLE-CONDITIONS SB-EXT:COMPILER-NOTE))
  (SETF SB-EXT:*MUFFLED-WARNINGS* T))

;
; Shared Declarations
;

(DEFVAR shen-cl.binary-path (FORMAT NIL "./bin/~A/" shen-cl.binary-folder))
(DEFVAR shen-cl.executable-path (FORMAT NIL "~A~A~A" shen-cl.binary-path shen-cl.binary-name shen-cl.executable-suffix))
(DEFVAR shen-cl.static-library-path (FORMAT NIL "~A~A~A" shen-cl.binary-path shen-cl.binary-name shen-cl.static-library-suffix))
(DEFVAR shen-cl.shared-library-path (FORMAT NIL "~A~A~A" shen-cl.binary-path shen-cl.binary-name shen-cl.shared-library-suffix))
(ENSURE-DIRECTORIES-EXIST shen-cl.binary-path)

;
; Implementation-Specific Loading Procedure
;

#-ECL
(DEFUN shen-cl.compile-lsp (file)
  (LET ((lsp-file (FORMAT NIL "~A~A.lsp" shen-cl.binary-path file)))
    (COMPILE-FILE lsp-file)))

#+ECL
(DEFUN shen-cl.compile-lsp (file)
  (LET ((lsp-file (FORMAT NIL "~A~A.lsp" shen-cl.binary-path file))
        (fas-file (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.compiled-suffix))
        (obj-file (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.object-suffix)))
    (COMPILE-FILE lsp-file :OUTPUT-FILE obj-file :SYSTEM-P T)
    (PUSH obj-file shen-cl.*object-files*)
    (C:BUILD-FASL fas-file :LISP-FILES (LIST obj-file))))

;
; Shared Loading Procedure
;

(DEFUN shen-cl.import-lsp (file)
  (LET ((src-file (FORMAT NIL "~A~A.lsp" shen-cl.source-path file))
        (lsp-file (FORMAT NIL "~A~A.lsp" shen-cl.binary-path file))
        (fas-file (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.compiled-suffix)))
    (shen-cl.copy-file src-file lsp-file)
    (shen-cl.compile-lsp file)
    (LOAD fas-file)))

(DEFUN shen-cl.import-kl (file)
  (LET ((kl-file  (FORMAT NIL "~A~A.kl" shen-cl.klambda-path file))
        (lsp-file (FORMAT NIL "~A~A.lsp" shen-cl.binary-path file))
        (fas-file (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.compiled-suffix)))
    (shen-cl.write-lsp-file lsp-file (shen-cl.translate-kl (shen-cl.read-kl-file kl-file)))
    (shen-cl.compile-lsp file)
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
  (MAPCAR #'(LAMBDA (expr) (shen-cl.kl->lisp NIL expr)) kl-code))

(DEFUN shen-cl.write-lsp-file (file code)
  (WITH-OPEN-FILE
    (out file
      :DIRECTION         :OUTPUT
      :IF-EXISTS         :SUPERSEDE
      :IF-DOES-NOT-EXIST :CREATE)
    (FORMAT out "~%")
    (MAPC #'(LAMBDA (X) (FORMAT out "~S~%~%" X)) code)
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

(COMPILE 'shen-cl.compile-lsp)
(COMPILE 'shen-cl.import-lsp)
(COMPILE 'shen-cl.import-kl)
(COMPILE 'shen-cl.read-kl-file)
(COMPILE 'shen-cl.clean-kl)
(COMPILE 'shen-cl.translate-kl)
(COMPILE 'shen-cl.write-lsp-file)
(COMPILE 'shen-cl.copy-file)

(shen-cl.import-lsp "primitives")
(shen-cl.import-lsp "backend")
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
(shen-cl.import-lsp "overwrite")
(shen-cl.import-lsp "platform")

(MAKUNBOUND 'shen-cl.klambda-path)
(MAKUNBOUND 'shen-cl.source-path)
(MAKUNBOUND 'shen-cl.binary-name)
(MAKUNBOUND 'shen-cl.executable-suffix)
(MAKUNBOUND 'shen-cl.static-library-suffix)
(MAKUNBOUND 'shen-cl.shared-library-suffix)
(MAKUNBOUND 'shen-cl.object-suffix)
(MAKUNBOUND 'shen-cl.compiled-suffix)
(MAKUNBOUND 'shen-cl.binary-folder)
(FMAKUNBOUND 'shen-cl.compile-lsp)
(FMAKUNBOUND 'shen-cl.import-lsp)
(FMAKUNBOUND 'shen-cl.import-kl)
(FMAKUNBOUND 'shen-cl.read-kl-file)
(FMAKUNBOUND 'shen-cl.clean-kl)
(FMAKUNBOUND 'shen-cl.translate-kl)
(FMAKUNBOUND 'shen-cl.write-lsp-file)
(FMAKUNBOUND 'shen-cl.copy-file)

;
; Implementation-Specific Executable Output
;

#+CLISP
(PROGN
  (EXT:SAVEINITMEM
    shen-cl.executable-path
    :EXECUTABLE 0
    :QUIET T
    :INIT-FUNCTION 'shen-cl.toplevel)
  (QUIT))

#+CCL
(PROGN
  (CCL:SAVE-APPLICATION
    shen-cl.executable-path
    :PREPEND-KERNEL T
    :TOPLEVEL-FUNCTION 'shen-cl.toplevel)
  (CCL:QUIT))

#+ECL
(PROGN
  (SETQ shen-cl.*object-files* (REVERSE shen-cl.*object-files*))
  (C:BUILD-PROGRAM
    shen-cl.executable-path
    :LISP-FILES shen-cl.*object-files*
    :EPILOGUE-CODE '(shen-cl.toplevel))
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
  :TOPLEVEL 'shen-cl.toplevel)
