;; Copyright (c) 2026 shen-cl port authors. BSD 3-Clause License.
;; The source compiler replaces Shen/CL's active translator while loading.
;; Install its new host helpers without changing the bootstrap kernel's runtime.
;; Read the canonical definitions rather than keeping separate implementations.
(in-package :shen)
(with-open-file (in "src/primitives.lsp")
  (loop for form = (read in nil :eof) until (eq form :eof)
        when (and (consp form) (eq (car form) 'defun)
                  (member (second form) '(|shen-cl.numeric-equal|
                                         |shen-cl.increment| |shen-cl.decrement|)))
        do (eval form)))
