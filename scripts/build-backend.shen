(set *maximum-print-sequence-size* 1000)

(define mk-kl
  File -> (let Shen (read-file File)
               KL (lisp.mapcar (/. X (produce-kl X)) Shen)
               KLString (code-string KL)
               WriteKL (write-to-file (cn File ".kl") KLString)
               CL (lisp.mapcar (/. X (shen.kl-to-lisp [] X)) KL)
               CLString (cn "(IN-PACKAGE :SHEN)c#10;c#10;" (code-string CL))
               WriteCL (write-to-file (cn File ".lsp") CLString)
               ok))

(define produce-kl
  [define F | Def] -> (shen.shen->kl F Def)
  Shen -> Shen)

(define code-string
  [] -> ""
  [KL | Code] -> (cn (make-string "~R ~%~%" KL) (code-string Code)))
