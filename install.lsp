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

; Assumes *.kl files are in the ./kernel/klambda directory
; Creates intermediate code and binaries in a platform-specific sub-directory under ./native/

(PROCLAIM '(OPTIMIZE (DEBUG 0) (SPEED 3) (SAFETY 3)))
; (PROCLAIM '(OPTIMIZE (DEBUG 0) (SPEED 0) (SAFETY 3))) ; TODO: for ECL?
(IN-PACKAGE :CL-USER)
(SETF (READTABLE-CASE *READTABLE*) :PRESERVE)
(SETQ *language* "Common Lisp")
(SETQ *port* 2.1)
(SETQ *porters* "Mark Tarver")

#+CLISP
(PROGN
  (SETQ *implementation* "GNU CLisp")
  (SETQ *release* (LET ((V (LISP-IMPLEMENTATION-VERSION))) (SUBSEQ V 0 (POSITION #\SPACE V :START 0))))
  (SETQ *os* (OR #+WIN32 "Windows" #+LINUX "Linux" #+MACOS "macOS" #+UNIX "Unix" "Unknown"))
  (DEFCONSTANT COMPILED-SUFFIX ".fas")
  (DEFCONSTANT NATIVE-PATH "./native/clisp/")
  (DEFCONSTANT BINARY-PATH (FORMAT NIL "~A~A" NATIVE-PATH #+WIN32 "shen.exe" #-WIN32 "shen"))
  (SETQ CUSTOM:*COMPILE-WARNINGS* NIL)
  (SETQ *COMPILE-VERBOSE* NIL))

#+CCL
(PROGN
  (SETQ *implementation* "Clozure CL")
  (SETQ *release* (LISP-IMPLEMENTATION-VERSION))
  (SETQ *os* (OR #+WINDOWS "Windows" #+LINUX "Linux" #+DARWIN "macOS" #+UNIX "Unix" "Unknown"))
  (DEFCONSTANT COMPILED-SUFFIX (FORMAT NIL "~A" *.FASL-PATHNAME*))
  (DEFCONSTANT NATIVE-PATH "./native/ccl/")
  (DEFCONSTANT BINARY-PATH (FORMAT NIL "~A~A" NATIVE-PATH #+WINDOWS "shen.exe" #-WINDOWS "shen")))

#+ECL
(PROGN
  (SETQ *implementation* "ECL")
  (SETQ *release* (LISP-IMPLEMENTATION-VERSION))
  (SETQ *os* (OR #+(OR :WIN32 :MINGW32) "Windows" #+LINUX "Linux" #+APPLE "macOS" #+UNIX "Unix" "Unknown"))
  (SETQ BUILT-FILES '())
  (DEFCONSTANT COMPILED-SUFFIX ".fas")
  (DEFCONSTANT BUILT-SUFFIX ".o")
  (DEFCONSTANT NATIVE-PATH "./native/ecl/")
  (DEFCONSTANT BINARY-PATH (FORMAT NIL "~A~A" NATIVE-PATH #+(OR :WIN32 :MINGW32) "shen.exe" #-(OR :WIN32 :MINGW32) "shen"))
  (EXT:INSTALL-C-COMPILER))

#+SBCL
(PROGN
  (SETQ *implementation* "SBCL")
  (SETQ *release* (LISP-IMPLEMENTATION-VERSION))
  (SETQ *os* (OR #+WIN32 "Windows" #+LINUX "Linux" #+DARWIN "macOS" #+UNIX "Unix" "Unknown"))
  (DEFCONSTANT COMPILED-SUFFIX ".fasl")
  (DEFCONSTANT NATIVE-PATH "./native/sbcl/")
  (DEFCONSTANT BINARY-PATH (FORMAT NIL "~A~A" NATIVE-PATH #+WIN32 "shen.exe" #-WIN32 "shen"))
  (DECLAIM (SB-EXT:MUFFLE-CONDITIONS SB-EXT:COMPILER-NOTE))
  (SETF SB-EXT:*MUFFLED-WARNINGS* T))

(DEFUN import-lsp (File)
  (LET ((LspFile (FORMAT NIL "~A.lsp" File))
        (ObjFile (FORMAT NIL "~A~A~A" NATIVE-PATH File COMPILED-SUFFIX)))
    #-ECL
    (COMPILE-FILE LspFile :OUTPUT-FILE ObjFile)
    #+ECL
    (LET ((BuiltFile (FORMAT NIL "~A~A~A" NATIVE-PATH File BUILT-SUFFIX)))
      (COMPILE-FILE LspFile :SYSTEM-P T)
      (C:BUILD-FASL ObjFile :LISP-FILES (LIST BuiltFile))
      (SETQ BUILT-FILES (CONS BuiltFile BUILT-FILES)))
    (LOAD ObjFile)))

(DEFUN import-kl (File)
  (LET ((KlFile  (FORMAT NIL "./kernel/klambda/~A.kl" File))
        (LspFile (FORMAT NIL "~A~A.lsp" NATIVE-PATH File))
        (ObjFile (FORMAT NIL "~A~A~A" NATIVE-PATH File COMPILED-SUFFIX)))
    (write-lsp-file LspFile (translate-kl (read-kl-file KlFile)))
    #-ECL
    (COMPILE-FILE LspFile)
    #+ECL
    (LET ((BuiltFile (FORMAT NIL "~A~A~A" NATIVE-PATH File BUILT-SUFFIX)))
      (COMPILE-FILE LspFile :SYSTEM-P T)
      (C:BUILD-FASL ObjFile :LISP-FILES (LIST BuiltFile))
      (SETQ BUILT-FILES (CONS BuiltFile BUILT-FILES)))
    (LOAD ObjFile)))

(DEFUN read-kl-file (File)
  (WITH-OPEN-FILE
    (In File :DIRECTION :INPUT)
    (LET* ((CleanedCode (clean-kl (READ-CHAR In NIL NIL) In NIL NIL)))
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

(COMPILE 'import-lsp)
(COMPILE 'import-kl)
(COMPILE 'read-kl-file)
(COMPILE 'clean-kl)
(COMPILE 'translate-kl)
(COMPILE 'write-lsp-file)

(ENSURE-DIRECTORIES-EXIST NATIVE-PATH)

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
(load "platform.shen")

(FMAKUNBOUND 'import-lsp)
(FMAKUNBOUND 'import-kl)
(FMAKUNBOUND 'read-kl-file)
(FMAKUNBOUND 'clean-kl)
(FMAKUNBOUND 'translate-kl)
(FMAKUNBOUND 'write-lsp-file)

#+CLISP
(PROGN
  (EXT:SAVEINITMEM
    BINARY-PATH
    :EXECUTABLE 0
    :QUIET T
    :INIT-FUNCTION 'shen-cl.toplevel)
  (QUIT))

#+CCL
(PROGN
  (CCL:SAVE-APPLICATION
    BINARY-PATH
    :PREPEND-KERNEL T
    :TOPLEVEL-FUNCTION 'shen-cl.toplevel)
  (CCL:QUIT))

#+ECL
(PROGN
  (C:BUILD-PROGRAM
    BINARY-PATH
    :LISP-FILES (REVERSE BUILT-FILES)
    :PROLOGUE-CODE NIL
    :EPILOGUE-CODE '(shen-cl.toplevel))
  (SI:QUIT))

#+SBCL
(SB-EXT:SAVE-LISP-AND-DIE
  BINARY-PATH
  :EXECUTABLE T
  :SAVE-RUNTIME-OPTIONS T
  :TOPLEVEL 'shen-cl.toplevel)
