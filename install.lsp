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

(DEFCONSTANT NATIVE-PATH
  #+CLISP "./native/clisp/"
  #+SBCL  "./native/sbcl/")

(DEFCONSTANT BINARY-SUFFIX
  #+CLISP ".fas"
  #+SBCL  ".fasl")

#+CLISP (DEFCONSTANT MEM-NAME "shen.mem")

#+SBCL (DEFCONSTANT EXECUTABLE-NAME #+WIN32 "shen.exe" #-WIN32 "shen")

(ENSURE-DIRECTORIES-EXIST NATIVE-PATH)

(PROCLAIM '(OPTIMIZE (DEBUG 0) (SPEED 3) (SAFETY 3)))
#+CLISP (SETQ CUSTOM:*COMPILE-WARNINGS* NIL)
#+CLISP (SETQ *COMPILE-VERBOSE* NIL)
#+SBCL  (DECLAIM (SB-EXT:MUFFLE-CONDITIONS SB-EXT:COMPILER-NOTE))
#+SBCL  (SETF SB-EXT:*MUFFLED-WARNINGS* T)
(IN-PACKAGE :CL-USER)

(SETF (READTABLE-CASE *READTABLE*) :PRESERVE)
(SETQ *language* "Common Lisp")
(SETQ *implementation* (LISP-IMPLEMENTATION-TYPE))
(SETQ *release*
  #+CLISP (LET ((V (LISP-IMPLEMENTATION-VERSION)))
    (SUBSEQ V 0 (POSITION #\SPACE V :START 0)))
  #+SBCL (LISP-IMPLEMENTATION-VERSION))
(SETQ *port* 2.0)
(SETQ *porters* "Mark Tarver")
(SETQ *os*
  (COND
    ((FIND :WIN32 *FEATURES*) "Windows")
    ((FIND :LINUX *FEATURES*) "Linux")
    ((FIND :OSX *FEATURES*) "Mac OSX")
    ((FIND :UNIX *FEATURES*) "Unix")))

(DEFUN import-kl (File)
  (LET ((KlFile       (FORMAT NIL "./kernel/klambda/~A.kl" File))
        (IntermedFile (FORMAT NIL "~A~A.intermed" NATIVE-PATH File))
        (LspFile      (FORMAT NIL "~A~A.lsp" NATIVE-PATH File))
        (ObjFile      (FORMAT NIL "~A~A~A" NATIVE-PATH File BINARY-SUFFIX)))
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
  (LET* ((KlCode (openfile InputFile))
         (LispCode (MAPCAR (FUNCTION (LAMBDA (X) (shen.kl-to-lisp NIL X))) KlCode)))
    (writefile OutputFile LispCode)))

(DEFUN openfile (File)
  (WITH-OPEN-FILE (In File :DIRECTION :INPUT)
    (DO ((R T) (Rs NIL))
        ((NULL R) (NREVERSE (CDR Rs)))
        (SETQ R (READ In NIL NIL))
        (PUSH R Rs))))

(DEFUN writefile (File Out)
  (WITH-OPEN-FILE
    (OUTSTREAM File
      :DIRECTION         :OUTPUT
      :IF-EXISTS         :SUPERSEDE
      :IF-DOES-NOT-EXIST :CREATE)
    (FORMAT OUTSTREAM "~%")
    (MAPC (FUNCTION (LAMBDA (X) (FORMAT OUTSTREAM "~S~%~%" X))) Out)
    File))

(DEFUN import-lsp (File)
  (LET ((LspFile (FORMAT NIL "~A.lsp" File))
        (ObjFile (FORMAT NIL "~A~A~A" NATIVE-PATH File BINARY-SUFFIX)))
    (COMPILE-FILE LspFile :OUTPUT-FILE ObjFile)
    (LOAD ObjFile)))

(COMPILE 'read-in-kl)
(COMPILE 'kl-cycle)
(COMPILE 'flip)
(COMPILE 'write-out-kl)

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
(FMAKUNBOUND 'writefile)
(FMAKUNBOUND 'openfile)
(FMAKUNBOUND 'import-lsp)
(FMAKUNBOUND 'import-kl)

#+CLISP (EXT:SAVEINITMEM
  (FORMAT NIL "~A~A" NATIVE-PATH MEM-NAME)
  :INIT-FUNCTION 'shen.byteloop)

#+CLISP (QUIT)

#+SBCL (SAVE-LISP-AND-DIE
  (FORMAT NIL "~A~A" NATIVE-PATH EXECUTABLE-NAME)
  :EXECUTABLE T
  :SAVE-RUNTIME-OPTIONS T
  :TOPLEVEL 'SHEN-TOPLEVEL)
