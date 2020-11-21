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

(load "src/package.lsp") ; Package code must be loaded before boot
                         ; code so that boot.lisp can be in the SHEN
                         ; package.

(proclaim '(optimize (debug 0) (speed 3) (safety 3)))
(in-package :shen)
(defconstant source-path "./src/")
(defconstant compiled-path "./compiled/")

;
; Confirm Pre-Requisites
;

(when (not (probe-file (format nil "~A~A" compiled-path "compiler.lsp")))
  (format t "~%")
  (format t "Directory ~S not found.~%" compiled-path)
  (format t "Run 'make precompile' to precompile the kernel and compiler.~%")
  (quit))

;
; Implementation-Specific Declarations
;

#+abcl
(progn
  (defvar *compiled-files* nil)
  (defconstant compiled-suffix ".abcl")
  (defconstant binary-path "./bin/abcl/")
  (defconstant concatenated-fasl-path (format nil "~Ashen~A" binary-path compiled-suffix))
  (defconstant executable-name #+windows "shen.exe" #-windows "shen"))

#+clisp
(progn
  (defconstant compiled-suffix ".fas")
  (defconstant binary-path "./bin/clisp/")
  (defconstant executable-name #+win32 "shen.exe" #-win32 "shen")
  (setq custom:*compile-warnings* nil)
  (setq *compile-verbose* nil))

#+ccl
(progn
  (defconstant compiled-suffix (format nil "~A" *.fasl-pathname*))
  (defconstant binary-path "./bin/ccl/")
  (defconstant executable-name #+windows "shen.exe" #-windows "shen"))

#+ecl
(progn
  (defvar *object-files* nil)
  (defconstant compiled-suffix ".fas")
  (defconstant object-suffix #+(or :win32 :mingw32) ".obj" #-(or :win32 :mingw32) ".o")
  (defconstant binary-path "./bin/ecl/")
  (defconstant executable-name #+(or :win32 :mingw32) "shen.exe" #-(or :win32 :mingw32) "shen")
  (ext:install-c-compiler)
  (setq compiler::*compile-verbose* nil)
  (setq compiler::*suppress-compiler-messages* nil))

#+sbcl
(progn
  (defconstant compiled-suffix ".fasl")
  (defconstant binary-path "./bin/sbcl/")
  (defconstant executable-name #+win32 "shen.exe" #-win32 "shen")
  (declaim (sb-ext:muffle-conditions sb-ext:compiler-note))
  (setf sb-ext:*muffled-warnings* t))

;
; Implementation-Specific Loading Procedure
;

#-ecl
(defun compile-lsp (file)
  (let ((lsp-file (format nil "~A~A.lsp" binary-path file))
        (fas-file (format nil "~A~A~A" binary-path file compiled-suffix)))
    (compile-file lsp-file)
    #+abcl (push fas-file *compiled-files*)))

#+ecl
(defun compile-lsp (file)
  (let ((lsp-file (format nil "~A~A.lsp" binary-path file))
        (fas-file (format nil "~A~A~A" binary-path file compiled-suffix))
        (obj-file (format nil "~A~A~A" binary-path file object-suffix)))
    (compile-file lsp-file :output-file obj-file :system-p t)
    (push obj-file *object-files*)
    (c:build-fasl fas-file :lisp-files (list obj-file))))

;
; Shared Loading Procedure
;

(defun import-lsp (location file)
  (let ((src-file (format nil "~A~A.lsp" location file))
        (lsp-file (format nil "~A~A.lsp" binary-path file))
        (fas-file (format nil "~A~A~A" binary-path file compiled-suffix)))
    (|copy-file| src-file lsp-file)
    (compile-lsp file)
    (load fas-file)))

(defun |copy-file| (src-file dest-file)
  (with-open-file
    (in src-file
      :direction    :input
      :element-type '(unsigned-byte 8))
    (with-open-file
      (out dest-file
        :direction         :output
        :if-exists         :supersede
        :if-does-not-exist :create
        :element-type      '(unsigned-byte 8))
      (let ((buf (make-array 4096 :element-type (stream-element-type in))))
        (loop for pos = (read-sequence buf in)
          while (plusp pos)
          do (write-sequence buf out :end pos))))))

(compile 'compile-lsp)
(compile 'import-lsp)
(compile '|copy-file|)

(ensure-directories-exist binary-path)

(import-lsp source-path "package")
(import-lsp source-path "primitives")
(import-lsp source-path "native")
(import-lsp source-path "shen-utils")
(import-lsp compiled-path "compiler")
(import-lsp compiled-path "toplevel")
(import-lsp compiled-path "core")
(import-lsp compiled-path "sys")
(import-lsp compiled-path "dict")
(import-lsp compiled-path "sequent")
(import-lsp compiled-path "yacc")
(import-lsp compiled-path "reader")
(import-lsp compiled-path "prolog")
(import-lsp compiled-path "track")
(import-lsp compiled-path "load")
(import-lsp compiled-path "writer")
(import-lsp compiled-path "macros")
(import-lsp compiled-path "declarations")
(import-lsp compiled-path "types")
(import-lsp compiled-path "t-star")
(import-lsp compiled-path "init")
(import-lsp compiled-path "extension-features")
(import-lsp compiled-path "extension-launcher")
(import-lsp compiled-path "extension-factorise-defun")
(import-lsp source-path "overwrite")

#-ecl
(progn
 (|shen.x.factorise-defun.initialise|)
 (|shen.initialise|)
 (|shen-cl.initialise|)
 (|shen.x.features.initialise| '(
   |shen/cl|
   #+abcl  |shen/cl.abcl|
   #+clisp |shen/cl.clisp|
   #+ccl   |shen/cl.ccl|
   #+sbcl  |shen/cl.sbcl|
 )))

(fmakunbound 'compile-lsp)
(fmakunbound 'import-lsp)
(fmakunbound '|copy-file|)

;
; Implementation-Specific Executable Output
;

(defconstant executable-path (format nil "~A~A" binary-path executable-name))

#+abcl
(progn
  (system:concatenate-fasls (reverse *compiled-files*) concatenated-fasl-path)
  (ext:quit))

#+clisp
(progn
  (ext:saveinitmem
    executable-path
    :executable 0
    :quiet t
    :init-function '|shen-cl.toplevel|)
  (quit))

#+ccl
(progn
  (ccl:save-application
    executable-path
    :prepend-kernel t
    :toplevel-function '|shen-cl.toplevel|)
  (ccl:quit))

#+ecl
(progn
  (c:build-program
    executable-path
    :lisp-files (reverse *object-files*)
    :epilogue-code '(|shen-cl.toplevel|))
  (si:quit))

#+sbcl
(sb-ext:save-lisp-and-die
  executable-path
  :executable t
  :save-runtime-options t
  :toplevel '|shen-cl.toplevel|)
