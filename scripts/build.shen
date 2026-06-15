\\ Copyright (c) 2012-2019 Bruno Deferrari.  All rights reserved.
\\ BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause

(set shen.x.factorise-defun.*selector-handlers* [])
(set shen.x.factorise-defun.*selector-handlers-reg* [])

(define shen.x.factorise-defun.apply-selector-handlers _ _ -> (fail))

\\ (load "kernel/klambda/extension-factorise-defun.kl")
\\ (shen.x.factorise-defun.initialise)
(define shen.x.factorise-defun.factorise-defun Defun -> Defun)
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
       "extension-expand-dynamic"
       "extension-launcher"
       "stlib"
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
  S -> (make-string "~R" (build.escape-string S)) where (string? S)
  [Quote Exp] -> (@s "'" (sexp->string Exp)) where (= Quote (shen-cl.cl quote))
  [Sexp | Sexps] -> (@s "(" (concat-strings (map (/. X (sexp->string X))
                                                 [Sexp | Sexps]))
                        ")")
  Sexp -> (make-string "~R" Sexp))

(define build.cased-symbol?
  [] -> false
  [C | Rest] -> (or (build.lowercase? C) (build.cased-symbol? Rest)))

(define build.lowercase?
  C -> (let N (string->n C)
         (and (>= N 97) (<= N 122))))

(define symbol->string
  S -> "|;|" where (= ; S)
  S -> "|:|" where (= : S)
  \\ A symbol whose name starts with ':' (e.g. the assignment operator ':=')
  \\ would be read back by Common Lisp as a keyword whose symbol-name drops
  \\ the colon -- ':=' becomes the keyword named "=", silently colliding with
  \\ '='. The kernel never relies on ':=' /= '=', so this stayed latent until
  \\ the standard library's vector macros (which DO distinguish them) were
  \\ enabled. Pipe-quote so it reads back as a symbol in the current package.
  S -> (@s "|" (str S) "|") where (build.colon-prefixed? (explode S))
  S -> (@s "|" (str S) "|") where (build.cased-symbol? (explode S))
  S -> (str S))

(define build.colon-prefixed?
  [C | _] -> true where (= ":" C)
  _ -> false)

(define build.escape-string
  S -> (build.escape-string-h (explode S)))

(define build.escape-string-h
  [] -> ""
  [C | Cs] -> (@s (n->string 92) (n->string 92) (build.escape-string-h Cs))
      where (= (string->n C) 92)
  [C | Cs] -> (@s (n->string 92) C (build.escape-string-h Cs))
      where (= (string->n C) 34)
  [C | Cs] -> (@s C (build.escape-string-h Cs)))

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
  [13 10 13 10 | _] Acc -> (bytes->string (reverse Acc) "") \\ CLRF on Windows
  [10 10 | _] Acc -> (bytes->string (reverse Acc) "")
  [Byte | Rest] Acc -> (extract-license Rest [Byte | Acc]))

(define bytes->string
  [] Acc -> Acc
  [92 92 32 | Rest] Acc -> (bytes->string Rest Acc)
  [Byte | Rest] Acc -> (bytes->string Rest (@s Acc (n->string Byte))))

(define kl-file-license?
  X -> false where (cons? X)
  _ -> true)

\\ Read a file as raw s-expressions, skipping reader-macro expansion.
\\ The .kl kernel sources are already KLambda, but a bootstrapping Shen
\\ (e.g. shen-scheme) would otherwise apply its stdlib macros while reading
\\ them and fail. Mirrors shen-scheme's build script.
(define read-file-unprocessed
  File -> (let Bytelist (read-file-as-bytelist File)
               S-exprs (trap-error (compile (/. X (shen.<s-exprs> X)) Bytelist)
                         (/. E (shen.reader-error (value shen.*residue*))))
            S-exprs))

(define compile-kl-file
  Prelude From To
  -> (let _ (output "Compiling ~R...~%" From)
          Out (open To out)
          Kl (read-file-unprocessed From)
          License (if (kl-file-license? (hd Kl)) (hd Kl) "")
          Defuns (if (kl-file-license? (hd Kl)) (tl Kl) Kl)
          Lisp (map (function compile-defun) Defuns)
          LispStr (map (function sexp->string) Lisp)
          _ (write-license-comment License Out)
          _ (pr Prelude Out)
          _ (for-each (/. S (pr (make-string "~A~%~%" S) Out) ) LispStr)
       (close Out)))

(define make-kl-code
  [define F | Rules] -> (shen.shen->kl-h [define F | Rules])
  [defcc F | Rules] -> (shen.shen->kl-h [defcc F | Rules])
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
