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

(PROCLAIM '(OPTIMIZE (DEBUG 0) (SPEED 3) (SAFETY 3)))
(IN-PACKAGE :SHEN)
(DEFCONSTANT SOURCE-PATH "./src/")
(DEFCONSTANT COMPILED-PATH "./compiled/")

;
; Confirm Pre-Requisites
;

(WHEN (NOT (PROBE-FILE (FORMAT NIL "~A~A" COMPILED-PATH "compiler.lsp")))
  (FORMAT T "~%")
  (FORMAT T "Directory ~S not found.~%" COMPILED-PATH)
  (FORMAT T "Run 'make precompile' to precompile the kernel and compiler.~%")
  (QUIT))

;
; Implementation-Specific Declarations
;

#+CLISP
(PROGN
  (DEFCONSTANT COMPILED-SUFFIX ".fas")
  (DEFCONSTANT BINARY-PATH "./bin/clisp/")
  (DEFCONSTANT EXECUTABLE-NAME #+WIN32 "shen.exe" #-WIN32 "shen")
  (SETQ CUSTOM:*COMPILE-WARNINGS* NIL)
  (SETQ *COMPILE-VERBOSE* NIL))

#+CCL
(PROGN
  (DEFCONSTANT COMPILED-SUFFIX (FORMAT NIL "~A" *.FASL-PATHNAME*))
  (DEFCONSTANT BINARY-PATH "./bin/ccl/")
  (DEFCONSTANT EXECUTABLE-NAME #+WINDOWS "shen.exe" #-WINDOWS "shen"))

#+ECL
(PROGN
  (DEFVAR *object-files* NIL)
  (DEFCONSTANT COMPILED-SUFFIX ".fas")
  (DEFCONSTANT OBJECT-SUFFIX #+(OR :WIN32 :MINGW32) ".obj" #-(OR :WIN32 :MINGW32) ".o")
  (DEFCONSTANT BINARY-PATH "./bin/ecl/")
  (DEFCONSTANT EXECUTABLE-NAME #+(OR :WIN32 :MINGW32) "shen.exe" #-(OR :WIN32 :MINGW32) "shen")
  (EXT:INSTALL-C-COMPILER)
  (SETQ COMPILER::*COMPILE-VERBOSE* NIL)
  (SETQ COMPILER::*SUPPRESS-COMPILER-MESSAGES* NIL))

#+SBCL
(PROGN
  (DEFCONSTANT COMPILED-SUFFIX ".fasl")
  (DEFCONSTANT BINARY-PATH "./bin/sbcl/")
  (DEFCONSTANT EXECUTABLE-NAME #+WIN32 "shen.exe" #-WIN32 "shen")
  (DECLAIM (SB-EXT:MUFFLE-CONDITIONS SB-EXT:COMPILER-NOTE))
  (SETF SB-EXT:*MUFFLED-WARNINGS* T))

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

(DEFUN import-lsp (Location File)
  (LET ((SrcFile (FORMAT NIL "~A~A.lsp" Location File))
        (LspFile (FORMAT NIL "~A~A.lsp" BINARY-PATH File))
        (FasFile (FORMAT NIL "~A~A~A" BINARY-PATH File COMPILED-SUFFIX)))
    (copy-file SrcFile LspFile)
    (compile-lsp File)
    (LOAD FasFile)))

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
(COMPILE 'copy-file)

(ENSURE-DIRECTORIES-EXIST BINARY-PATH)

(import-lsp SOURCE-PATH "package")
(import-lsp SOURCE-PATH "primitives")
(import-lsp SOURCE-PATH "native")
(import-lsp SOURCE-PATH "shen-utils")
(import-lsp COMPILED-PATH "compiler")
(import-lsp COMPILED-PATH "toplevel")
(import-lsp COMPILED-PATH "core")
(import-lsp COMPILED-PATH "sys")
(import-lsp COMPILED-PATH "dict")
(import-lsp COMPILED-PATH "sequent")
(import-lsp COMPILED-PATH "yacc")
(import-lsp COMPILED-PATH "reader")
(import-lsp COMPILED-PATH "prolog")
(import-lsp COMPILED-PATH "track")
(import-lsp COMPILED-PATH "load")
(import-lsp COMPILED-PATH "writer")
(import-lsp COMPILED-PATH "macros")
(import-lsp COMPILED-PATH "declarations")
(import-lsp COMPILED-PATH "types")
(import-lsp COMPILED-PATH "t-star")
(import-lsp COMPILED-PATH "init")
(import-lsp COMPILED-PATH "extension-features")
(import-lsp COMPILED-PATH "extension-launcher")
(import-lsp COMPILED-PATH "extension-factorise-defun")
(import-lsp SOURCE-PATH "overwrite")

#-ECL
(PROGN
 (|shen.initialise|)
 (|shen-cl.initialise|)
 (|shen.x.features.initialise| '(
   |shen/cl|
   #+CLISP |shen/cl.clisp|
   #+SBCL  |shen/cl.sbcl|
   #+CCL   |shen/cl.ccl|
 )))

(FMAKUNBOUND 'compile-lsp)
(FMAKUNBOUND 'import-lsp)
(FMAKUNBOUND 'copy-file)

;
; Implementation-Specific Executable Output
;

(DEFCONSTANT EXECUTABLE-PATH (FORMAT NIL "~A~A" BINARY-PATH EXECUTABLE-NAME))

#+CLISP
(PROGN
  (EXT:SAVEINITMEM
    EXECUTABLE-PATH
    :EXECUTABLE 0
    :QUIET T
    :INIT-FUNCTION '|shen-cl.toplevel|)
  (QUIT))

#+CCL
(PROGN
  (CCL:SAVE-APPLICATION
    EXECUTABLE-PATH
    :PREPEND-KERNEL T
    :TOPLEVEL-FUNCTION '|shen-cl.toplevel|)
  (CCL:QUIT))

#+ECL
(PROGN
  (C:BUILD-PROGRAM
    EXECUTABLE-PATH
    :LISP-FILES (REVERSE *object-files*)
    :EPILOGUE-CODE '(|shen-cl.toplevel|))
  (SI:QUIT))

#+SBCL
(SB-EXT:SAVE-LISP-AND-DIE
  EXECUTABLE-PATH
  :EXECUTABLE T
  :SAVE-RUNTIME-OPTIONS T
  :TOPLEVEL '|shen-cl.toplevel|)
