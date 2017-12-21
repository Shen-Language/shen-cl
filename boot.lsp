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
(DEFCONSTANT KLAMBDA-PATH "./kernel/klambda/")
(DEFCONSTANT SOURCE-PATH "./src/")
(DEFCONSTANT BINARY-NAME "shen")

;
; Confirm Pre-Requisites
;

(WHEN (NOT (PROBE-FILE (FORMAT NIL "~A~A" KLAMBDA-PATH "core.kl")))
  (FORMAT T "~%")
  (FORMAT T "Directory ~S not found.~%" KLAMBDA-PATH)
  (FORMAT T "Run 'make fetch' to retrieve Shen Kernel sources.~%")
  (QUIT))

;
; Identify Environment
;

#+(AND (NOT WINDOWS) (OR WIN32 WIN64 MINGW32)) (PUSH :WINDOWS *FEATURES*)
#+(AND (NOT MACOS) (OR APPLE DARWIN)) (PUSH :MACOS *FEATURES*)

;
; OS-Specific Declarations
;

(DEFCONSTANT EXECUTABLE-SUFFIX (OR #+WINDOWS ".exe" ""))
(DEFCONSTANT STATIC-LIBRARY-SUFFIX (OR #+WINDOWS ".lib" ".a"))
(DEFCONSTANT SHARED-LIBRARY-SUFFIX (OR #+WINDOWS ".dll" #+MACOS ".dylib" ".so"))
(DEFCONSTANT OBJECT-SUFFIX (OR #+WINDOWS ".obj" ".o"))

;
; Implementation-Specific Declarations
;

(DEFCONSTANT COMPILED-SUFFIX (OR #+CCL (NAMESTRING *.FASL-PATHNAME*) #+SBCL ".fasl" ".fas"))
(DEFCONSTANT BINARY-FOLDER #+CLISP "clisp" #+CCL "ccl" #+ECL "ecl" #+SBCL "sbcl")

#+CLISP
(PROGN
  (SETQ CUSTOM:*COMPILE-WARNINGS* NIL)
  (SETQ *COMPILE-VERBOSE* NIL))

#+ECL
(PROGN
  (DEFVAR *object-files* NIL)
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

(DEFCONSTANT BINARY-PATH (FORMAT NIL "./bin/~A/" BINARY-FOLDER))
(DEFCONSTANT EXECUTABLE-PATH (FORMAT NIL "~A~A~A" BINARY-PATH BINARY-NAME EXECUTABLE-SUFFIX))
(DEFCONSTANT STATIC-LIBRARY-PATH (FORMAT NIL "~A~A~A" BINARY-PATH BINARY-NAME STATIC-LIBRARY-SUFFIX))
(DEFCONSTANT SHARED-LIBRARY-PATH (FORMAT NIL "~A~A~A" BINARY-PATH BINARY-NAME SHARED-LIBRARY-SUFFIX))
(ENSURE-DIRECTORIES-EXIST BINARY-PATH)

;
; Implementation-Specific Loading Procedure
;

#-ECL
(DEFUN compile-lsp (File)
  (LET ((LspFile (FORMAT NIL "~A~A.lsp" BINARY-PATH File)))
    (COMPILE-FILE LspFile)))

#+ECL
(DEFUN compile-lsp (File)
  (LET ((LspFile (FORMAT NIL "~A~A.lsp" BINARY-PATH File))
        (FasFile (FORMAT NIL "~A~A~A" BINARY-PATH File COMPILED-SUFFIX))
        (ObjFile (FORMAT NIL "~A~A~A" BINARY-PATH File OBJECT-SUFFIX)))
    (COMPILE-FILE LspFile :OUTPUT-FILE ObjFile :SYSTEM-P T)
    (PUSH ObjFile *object-files*)
    (C:BUILD-FASL FasFile :LISP-FILES (LIST ObjFile))))

;
; Shared Loading Procedure
;

(DEFUN import-lsp (File)
  (LET ((SrcFile (FORMAT NIL "~A~A.lsp" SOURCE-PATH File))
        (LspFile (FORMAT NIL "~A~A.lsp" BINARY-PATH File))
        (FasFile (FORMAT NIL "~A~A~A" BINARY-PATH File COMPILED-SUFFIX)))
    (copy-file SrcFile LspFile)
    (compile-lsp File)
    (LOAD FasFile)))

(DEFUN import-kl (File)
  (LET ((KlFile  (FORMAT NIL "~A~A.kl" KLAMBDA-PATH File))
        (LspFile (FORMAT NIL "~A~A.lsp" BINARY-PATH File))
        (FasFile (FORMAT NIL "~A~A~A" BINARY-PATH File COMPILED-SUFFIX)))
    (write-lsp-file LspFile (translate-kl (read-kl-file KlFile)))
    (compile-lsp File)
    (LOAD FasFile)))

(DEFUN read-kl-file (File)
  (WITH-OPEN-FILE
    (In File
      :DIRECTION :INPUT)
    (LET ((CleanedCode (clean-kl (READ-CHAR In NIL NIL) In NIL NIL)))
      (READ-FROM-STRING (FORMAT NIL "(~A)" (COERCE CleanedCode 'STRING))))))

(DEFUN clean-kl (Char In Chars InsideQuote)
  (IF (NULL Char)
    (REVERSE Chars)
    (clean-kl
      (READ-CHAR In NIL NIL)
      In
      (IF (AND (NOT InsideQuote) (MEMBER Char '(#\: #\; #\,) :TEST 'CHAR-EQUAL))
        (LIST* #\| Char #\| Chars)
        (CONS Char Chars))
      (IF (CHAR-EQUAL Char #\")
        (NOT InsideQuote)
        InsideQuote))))

(DEFUN translate-kl (KlCode)
  (MAPCAR #'(LAMBDA (X) (shen.kl-to-lisp NIL X)) KlCode))

(DEFUN write-lsp-file (File Code)
  (WITH-OPEN-FILE
    (Out File
      :DIRECTION         :OUTPUT
      :IF-EXISTS         :SUPERSEDE
      :IF-DOES-NOT-EXIST :CREATE)
    (FORMAT Out "~%")
    (MAPC #'(LAMBDA (X) (FORMAT Out "~S~%~%" X)) Code)
    File))

(DEFUN copy-file (SrcFile DestFile)
  (WITH-OPEN-FILE
    (In SrcFile
      :DIRECTION    :INPUT
      :ELEMENT-TYPE '(UNSIGNED-BYTE 8))
    (WITH-OPEN-FILE
      (Out DestFile
        :DIRECTION         :OUTPUT
        :IF-EXISTS         :SUPERSEDE
        :IF-DOES-NOT-EXIST :CREATE
        :ELEMENT-TYPE      '(UNSIGNED-BYTE 8))
      (LET ((Buf (MAKE-ARRAY 4096 :ELEMENT-TYPE (STREAM-ELEMENT-TYPE In))))
        (LOOP FOR Pos = (READ-SEQUENCE Buf In)
          WHILE (PLUSP Pos)
          DO (WRITE-SEQUENCE Buf Out :END Pos))))))

(COMPILE 'compile-lsp)
(COMPILE 'import-lsp)
(COMPILE 'import-kl)
(COMPILE 'read-kl-file)
(COMPILE 'clean-kl)
(COMPILE 'translate-kl)
(COMPILE 'write-lsp-file)
(COMPILE 'copy-file)

(import-lsp "primitives")
(import-lsp "backend")
(import-kl "toplevel")
(import-kl "core")
(import-kl "sys")
(import-kl "sequent")
(import-kl "yacc")
(import-kl "reader")
(import-kl "prolog")
(import-kl "track")
(import-kl "load")
(import-kl "writer")
(import-kl "macros")
(import-kl "declarations")
(import-kl "types")
(import-kl "t-star")
(import-lsp "overwrite")
(import-lsp "platform")

(FMAKUNBOUND 'compile-lsp)
(FMAKUNBOUND 'import-lsp)
(FMAKUNBOUND 'import-kl)
(FMAKUNBOUND 'read-kl-file)
(FMAKUNBOUND 'clean-kl)
(FMAKUNBOUND 'translate-kl)
(FMAKUNBOUND 'write-lsp-file)
(FMAKUNBOUND 'copy-file)

;
; Implementation-Specific Executable Output
;

#+CLISP
(PROGN
  (EXT:SAVEINITMEM
    EXECUTABLE-PATH
    :EXECUTABLE 0
    :QUIET T
    :INIT-FUNCTION 'shen-cl.toplevel)
  (QUIT))

#+CCL
(PROGN
  (CCL:SAVE-APPLICATION
    EXECUTABLE-PATH
    :PREPEND-KERNEL T
    :TOPLEVEL-FUNCTION 'shen-cl.toplevel)
  (CCL:QUIT))

#+ECL
(PROGN
  (C:BUILD-PROGRAM
    EXECUTABLE-PATH
    :LISP-FILES (REVERSE *object-files*)
    :EPILOGUE-CODE '(shen-cl.toplevel))
  (C:BUILD-STATIC-LIBRARY
    STATIC-LIBRARY-PATH
    :LISP-FILES (REVERSE *object-files*)
    :EPILOGUE-CODE '(shen-cl.init)
    :INIT-NAME "shen_init")
  (C:BUILD-SHARED-LIBRARY
    SHARED-LIBRARY-PATH
    :LISP-FILES (REVERSE *object-files*)
    :EPILOGUE-CODE '(shen-cl.init)
    :INIT-NAME "shen_init")
  (SI:QUIT))

#+SBCL
(SB-EXT:SAVE-LISP-AND-DIE
  EXECUTABLE-PATH
  :EXECUTABLE T
  :SAVE-RUNTIME-OPTIONS T
  :TOPLEVEL 'shen-cl.toplevel)
