(DEFPACKAGE :SHEN
  #+CLISP
  (:USE :COMMON-LISP
        :EXT)
  #+CCL
  (:USE :COMMON-LISP
        :CCL)
  #+ECL
  (:USE :COMMON-LISP
        :SI)
  #+SBCL
  (:USE :COMMON-LISP
        :SB-ALIEN))
