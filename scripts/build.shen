\\ Copyright (c) 2012-2019 Bruno Deferrari.  All rights reserved.
\\ BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause

(load "kernel/klambda/extension-factorise-defun.kl")
(load "src/compiler.shen")

(shen-cl.initialise-compiler)
(set shen-cl.*compiling-shen-sources* true)

(set *maximum-print-sequence-size* 10000)

(set *shen-files*
      ["toplevel"
       "core"
       "sys"
       "dict"
       "sequent"
       "yacc"
       "reader"
       "prolog"
       "track"
       "load"
       "writer"
       "macros"
       "declarations"
       "types"
       "t-star"
       "init"
       "extension-features"
       "extension-launcher"
       "extension-factorise-defun"
       ])

(set *shen-cl-files* ["compiler"])

(define for-each
  _ [] -> true
  F [X | Rest] -> (do (F X) (for-each F Rest)))

(define sexp->string
  [] -> "()"
  true -> "|true|"
  false -> "|false|"
  Comma -> "|,|" where (= Comma ,)
  Sym -> (symbol->string Sym) where (symbol? Sym)
  [Quote Exp] -> (@s "'" (sexp->string Exp)) where (= Quote (shen-cl.cl quote))
  [Sexp | Sexps] -> (@s "(" (concat-strings (map (/. X (sexp->string X))
                                                 [Sexp | Sexps]))
                        ")")
  Sexp -> (make-string "~R" Sexp))

(define cased-symbol?
  [] -> false
  [C | Rest] -> (or (lowercase? C) (cased-symbol? Rest)))

(define lowercase?
  C -> (let N (string->n C)
         (and (>= N 97) (<= N 122))))

(define symbol->string
  S -> "|;|" where (= ; S)
  S -> "|:|" where (= : S)
  S -> (@s "|" (str S) "|") where (cased-symbol? (explode S))
  S -> (str S))

(define concat-strings
  [] -> ""
  [S | Ss] -> (@s S " " (concat-strings Ss)))

(define compile-defun
  Defun -> (shen-cl.kl->lisp Defun))

(define write-license-comment
  License Out -> (let LicenseBytes (map (function string->n) (explode License))
                      LicenseComment (bytes->string (add-comments LicenseBytes) ";; ")
                      _ (pr LicenseComment Out)
                      _ (pr "c#10;c#10;" Out)
                   done))

(define add-comments
  [] -> []
  [10 | Rest] -> [10 59 59 32 | (add-comments Rest)]
  [N | Rest] -> [N | (add-comments Rest)])

(define write-license-string
  License Out -> (do (pr "c#34;" Out)
                     (pr License Out)
                     (pr "c#34;c#10;c#10;" Out)))

(define file-license
  File -> (let Contents (read-file-as-bytelist File)
            (extract-license Contents [])))

(define extract-license
  [10 10 | Rest] Acc -> (bytes->string (reverse Acc) "")
  [Byte | Rest] Acc -> (extract-license Rest [Byte | Acc]))

(define bytes->string
  [] Acc -> Acc
  [92 92 32 | Rest] Acc -> (bytes->string Rest Acc)
  [Byte | Rest] Acc -> (bytes->string Rest (@s Acc (n->string Byte))))

(define compile-kl-file
  Prelude From To
  -> (let _ (output "Compiling ~R...~%" From)
          Out (open To out)
          Kl (read-file From)
          License (hd Kl)
          Defuns (tl Kl)
          Lisp (map (function compile-defun) Defuns)
          LispStr (map (function sexp->string) Lisp)
          _ (write-license-comment License Out)
          _ (pr Prelude Out)
          _ (for-each (/. S (pr (make-string "~A~%~%" S) Out) ) LispStr)
       (close Out)))

(define make-kl-code
  [define F | Rules] -> (shen.elim-def [define F | Rules])
  [defcc F | Rules] -> (shen.elim-def [defcc F | Rules])
  Code -> Code)

(define compile-shen-file
  From To -> (let Out (open To out)
                  Shen (read-file From)
                  License (file-license From)
                  _ (write-license-string License Out)
                  Kl (map (function make-kl-code) Shen)
                  _ (for-each (/. S (pr (make-string "~R~%~%" S) Out) )
                              Kl)
               (close Out)))

(define build
  -> (do (compile-shen-file "src/compiler.shen" "kernel/klambda/compiler.kl")
         (for-each (/. F (compile-kl-file
                          (package-prelude)
                          (@s "kernel/klambda/" F ".kl")
                          (@s "compiled/" F ".lsp")))
                   (value *shen-cl-files*))
         (for-each (/. F (compile-kl-file
                          (package-prelude)
                          (@s "kernel/klambda/" F ".kl")
                          (@s "compiled/" F ".lsp")))
                   (value *shen-files*))
         done))

(define write-string-to-file
  Body File -> (let Out (open File out)
                    _ (pr Body Out)
                 (close Out)))


(define package-prelude
  -> "(in-package :shen)c#10;c#10;")
