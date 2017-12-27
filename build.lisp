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

; TODO: make better use of packages; put shen-cl in own package, put compled kl in another

(SETF (READTABLE-CASE *READTABLE*) :PRESERVE)
(PROCLAIM '(OPTIMIZE (DEBUG 0) (SPEED 3) (SAFETY 3)))
(IN-PACKAGE :CL-USER)
(DEFVAR shen-cl.klambda-path "./kernel/klambda/")
(DEFVAR shen-cl.source-path "./src/")
(DEFVAR shen-cl.binary-name "shen")
(DEFVAR shen-cl.source-suffix ".lisp")

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
  (SETQ CUSTOM:*SUPPRESS-CHECK-REDEFINITION* T)
  (SETQ *COMPILE-VERBOSE* NIL))

#+ECL
(PROGN
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
(DEFVAR shen-cl.code ())

;
; Implementation-Specific Compilation Procedure
;

; TODO: just eval the forms that would be written to kernel.lisp instead
#-ECL
(DEFUN shen-cl.compile-lisp (file)
  (LET ((lisp-file (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.source-suffix))
        (fas-file  (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.compiled-suffix)))
    (COMPILE-FILE lisp-file)
    (LOAD fas-file)))

#+ECL
(DEFUN shen-cl.compile-lisp (file)
  (LET ((lisp-file (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.source-suffix))
        (fas-file  (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.compiled-suffix))
        (obj-file  (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.object-suffix)))
    (COMPILE-FILE lisp-file :OUTPUT-FILE obj-file :SYSTEM-P T)
    (DEFVAR shen-cl.object-files (LIST obj-file))

    ; TODO: not necessary?
    ;(C:BUILD-FASL fas-file :LISP-FILES (LIST obj-file))
    ;(LOAD fas-file)
    ))

; TODO: new version of #+ECL shen-cl.compile-lisp (that doesn't work)
; (DEFUN shen-cl.compile-lisp (file)
;   (LET ((lisp-file (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.source-suffix))
;         (obj-file  (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.object-suffix)))
;     (COMPILE-FILE lisp-file :OUTPUT-FILE obj-file :SYSTEM-P T)
;     (DEFVAR shen-cl.object-files (LIST obj-file))))

;
; Shared Loading Procedure
;

(DEFUN shen-cl.slurp-file (file)
  (WITH-OPEN-FILE (stream file)
    (LET ((contents (MAKE-STRING (FILE-LENGTH stream))))
      (READ-SEQUENCE contents stream)
      contents)))

(DEFUN shen-cl.clean-kl-loop (s size index quoted chars)
  (IF (= index size)
    (COERCE (REVERSE chars) 'STRING)
    (LET ((ch (CHAR s index)))
      (shen-cl.clean-kl-loop
        s
        size
        (1+ index)
        (IF (CHAR-EQUAL ch #\")
          (NOT quoted)
          quoted)
        (IF (AND (NOT quoted) (MEMBER ch '(#\: #\; #\,) :TEST 'CHAR-EQUAL))
          (LIST* #\| ch #\| chars)
          (CONS ch chars))))))

(DEFUN shen-cl.clean-kl (s)
  (shen-cl.clean-kl-loop s (LENGTH s) 0 NIL ()))

(DEFUN shen-cl.import-lisp (file)
  (SETQ shen-cl.code (APPEND shen-cl.code
    (READ-FROM-STRING
      (FORMAT NIL "(~A)"
        (shen-cl.slurp-file
          (FORMAT NIL "~A~A~A" shen-cl.source-path file shen-cl.source-suffix)))))))

(DEFUN shen-cl.import-kl (file)
  (SETQ shen-cl.code (APPEND shen-cl.code
    (MAPCAR #'(LAMBDA (expr) (shen-cl.kl->lisp NIL expr))
      (READ-FROM-STRING
        (FORMAT NIL "(~A)"
          (shen-cl.clean-kl
            (shen-cl.slurp-file
              (FORMAT NIL "~A~A.kl" shen-cl.klambda-path file)))))))))

(DEFUN shen-cl.export-lisp (file)
  (WITH-OPEN-FILE
    (out (FORMAT NIL "~A~A~A" shen-cl.binary-path file shen-cl.source-suffix)
      :DIRECTION         :OUTPUT
      :IF-EXISTS         :SUPERSEDE
      :IF-DOES-NOT-EXIST :CREATE)
    (MAPC
      #'(LAMBDA (expr) (FORMAT out "~S~%~%" expr))
      (REMOVE-IF #'STRINGP shen-cl.code))
    (FORCE-OUTPUT out))) ; TODO: is this FORCE-OUTPUT necessary?

(COMPILE 'shen-cl.compile-lisp)
(COMPILE 'shen-cl.slurp-file)
(COMPILE 'shen-cl.clean-kl)
(COMPILE 'shen-cl.clean-kl-loop)
(COMPILE 'shen-cl.import-lisp)
(COMPILE 'shen-cl.import-kl)
(COMPILE 'shen-cl.export-lisp)

; TODO: don't forget to load these to read kl
(LOAD "./src/primitives.lisp")
(LOAD "./src/backend.lisp")

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

; TODO: maybe inline export-lisp and compile-lisp here
(shen-cl.export-lisp "kernel")

; TODO: strip out copyright notices from kernel.lisp
(shen-cl.compile-lisp "kernel")

; TODO: can clisp, ccl, sbcl be compiled externally like ecl so we
;       don't have to worry about namespace pollution?
(MAKUNBOUND 'shen-cl.klambda-path)
(MAKUNBOUND 'shen-cl.source-path)
(MAKUNBOUND 'shen-cl.binary-name)
(MAKUNBOUND 'shen-cl.source-suffix)
(MAKUNBOUND 'shen-cl.executable-suffix)
(MAKUNBOUND 'shen-cl.static-library-suffix)
(MAKUNBOUND 'shen-cl.shared-library-suffix)
(MAKUNBOUND 'shen-cl.object-suffix)
(MAKUNBOUND 'shen-cl.compiled-suffix)
(MAKUNBOUND 'shen-cl.binary-folder)
(MAKUNBOUND 'shen-cl.binary-path)
(MAKUNBOUND 'shen-cl.code)
(FMAKUNBOUND 'shen-cl.compile-lisp)
(FMAKUNBOUND 'shen-cl.slurp-file)
(FMAKUNBOUND 'shen-cl.clean-kl)
(FMAKUNBOUND 'shen-cl.clean-kl-loop)
(FMAKUNBOUND 'shen-cl.import-lisp)
(FMAKUNBOUND 'shen-cl.import-kl)
(FMAKUNBOUND 'shen-cl.export-lisp)

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


  ; TODO: remove when fixed
  (FORMAT T "~%~%~%building program: ~A~%~%~%" shen-cl.object-files)
  (FORCE-OUTPUT *STANDARD-OUTPUT*)


  (C:BUILD-PROGRAM
    shen-cl.executable-path
    :LISP-FILES shen-cl.object-files
    :EPILOGUE-CODE '(shen-cl.toplevel))
  (C:BUILD-STATIC-LIBRARY
    shen-cl.static-library-path
    :LISP-FILES shen-cl.object-files
    :EPILOGUE-CODE '(shen-cl.init)
    :INIT-NAME "shen_init")
  (C:BUILD-SHARED-LIBRARY
    shen-cl.shared-library-path
    :LISP-FILES shen-cl.object-files
    :EPILOGUE-CODE '(shen-cl.init)
    :INIT-NAME "shen_init")
  (SI:QUIT))

#+SBCL
(SB-EXT:SAVE-LISP-AND-DIE
  shen-cl.executable-path
  :EXECUTABLE T
  :SAVE-RUNTIME-OPTIONS T
  :TOPLEVEL 'shen-cl.toplevel)
