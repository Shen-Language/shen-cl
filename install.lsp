"Copyright (c) 2010-2015, Mark Tarver

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. The name of Mark Tarver may not be used to endorse or promote products
   derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY Mark Tarver ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Mark Tarver BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."

; Assumes *.kl files are in the ./kernel/klambda directory
; Creates intermediate code and binaries in a platform-specific sub-directory under ./native/

(PROCLAIM '(OPTIMIZE (DEBUG 0) (SPEED 3) (SAFETY 3)))
(IN-PACKAGE :CL-USER)
(SETF (READTABLE-CASE *READTABLE*) :PRESERVE)
(SETQ *language* "Common Lisp")
(SETQ *port* 2.0)
(SETQ *porters* "Mark Tarver")

#+CLISP
(PROGN
  (SETQ *implementation* "GNU CLisp")
  (SETQ *release* (LET ((V (LISP-IMPLEMENTATION-VERSION))) (SUBSEQ V 0 (POSITION #\SPACE V :START 0))))
  (SETQ *os* (OR #+WIN32 "Windows" #+LINUX "Linux" #+MACOS "macOS" #+UNIX "Unix" "Unknown"))
  (DEFCONSTANT COMPILED-SUFFIX ".fas")
  (DEFCONSTANT NATIVE-PATH "./native/clisp/")
  (DEFCONSTANT BINARY-PATH (FORMAT NIL "~A~A" NATIVE-PATH "shen.mem"))
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

(DEFUN import-kl (File)
  (LET ((KlFile       (FORMAT NIL "./kernel/klambda/~A.kl" File))
        (IntermedFile (FORMAT NIL "~A~A.intermed" NATIVE-PATH File))
        (LspFile      (FORMAT NIL "~A~A.lsp" NATIVE-PATH File))
        (ObjFile      (FORMAT NIL "~A~A~A" NATIVE-PATH File COMPILED-SUFFIX)))
    (prepare-kl KlFile IntermedFile)
    (translate-kl IntermedFile LspFile)
    (COMPILE-FILE LspFile)
    (LOAD ObjFile)))

(DEFUN prepare-kl (KlFile IntermedFile)
  (write-out-kl IntermedFile (read-in-kl KlFile)))

(DEFUN read-in-kl (File)
  (WITH-OPEN-FILE
    (In File :DIRECTION :INPUT)
    (kl-cycle (READ-CHAR In NIL NIL) In NIL 0)))

(DEFUN kl-cycle (Char In Chars State)
  (IF (NULL Char)
    (REVERSE Chars)
    (kl-cycle
      (READ-CHAR In NIL NIL)
      In
      (IF (AND (MEMBER Char '(#\: #\; #\,) :TEST 'CHAR-EQUAL) (= State 0))
        (APPEND (LIST #\| Char #\|) Chars)
        (CONS Char Chars))
      (IF (CHAR-EQUAL Char #\")
        (flip State)
        State))))

(DEFUN flip (State)
  (IF (ZEROP State) 1 0))

(DEFUN write-out-kl (File Chars)
  (WITH-OPEN-FILE
    (Out File
      :DIRECTION         :OUTPUT
      :IF-EXISTS         :SUPERSEDE
      :IF-DOES-NOT-EXIST :CREATE)
    (FORMAT Out "~{~C~}" Chars)))

(DEFUN translate-kl (InputFile OutputFile)
  (LET* ((KlCode (open-kl-file InputFile))
         (LispCode (MAPCAR #'(LAMBDA (X) (shen.kl-to-lisp NIL X)) KlCode)))
    (write-lsp-file OutputFile LispCode)))

(DEFUN open-kl-file (File)
  (WITH-OPEN-FILE (In File :DIRECTION :INPUT)
    (DO ((R T) (Rs NIL))
        ((NULL R) (NREVERSE (CDR Rs)))
        (SETQ R (READ In NIL NIL))
        (PUSH R Rs))))

(DEFUN write-lsp-file (File Code)
  (WITH-OPEN-FILE
    (Out File
      :DIRECTION         :OUTPUT
      :IF-EXISTS         :SUPERSEDE
      :IF-DOES-NOT-EXIST :CREATE)
    (FORMAT Out "~%")
    (MAPC #'(LAMBDA (X) (FORMAT Out "~S~%~%" X)) Code)
    File))

(DEFUN import-lsp (File)
  (LET ((LspFile (FORMAT NIL "~A.lsp" File))
        (ObjFile (FORMAT NIL "~A~A~A" NATIVE-PATH File COMPILED-SUFFIX)))
    (COMPILE-FILE LspFile :OUTPUT-FILE ObjFile)
    (LOAD ObjFile)))

(COMPILE 'read-in-kl)
(COMPILE 'kl-cycle)
(COMPILE 'flip)
(COMPILE 'write-out-kl)

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

(FMAKUNBOUND 'prepare-kl)
(FMAKUNBOUND 'translate-kl)
(FMAKUNBOUND 'open-kl-file)
(FMAKUNBOUND 'write-lsp-file)
(FMAKUNBOUND 'import-lsp)
(FMAKUNBOUND 'import-kl)

#+CLISP
(PROGN
  (EXT:SAVEINITMEM
    BINARY-PATH
    :INIT-FUNCTION 'shen-cl.toplevel)
  (QUIT))

#+CCL
(PROGN
  (CCL:SAVE-APPLICATION
    BINARY-PATH
    :PREPEND-KERNEL T
    :TOPLEVEL-FUNCTION 'shen-cl.toplevel)
  (CCL:QUIT))

#+SBCL
(SB-EXT:SAVE-LISP-AND-DIE
  BINARY-PATH
  :EXECUTABLE T
  :SAVE-RUNTIME-OPTIONS T
  :TOPLEVEL 'shen-cl.toplevel)
