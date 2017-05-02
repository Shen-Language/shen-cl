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

(DEFUN shen.kl-to-lisp (Locals Expr)
  (COND
    ((CONSP (MEMBER Expr Locals))
     Expr)

    ; Locals [type X _] -> (kl-to-lisp Locals X)
    ((AND
      (CONSP Expr)
      (EQ 'type (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (shen.kl-to-lisp Locals (CADR Expr)))

    ; Locals [lambda X Y] -> (let ChX (ch-T X) (protect [FUNCTION [LAMBDA [ChX] (kl-to-lisp [ChX | Locals] (SUBST ChX X Y))]]))
    ((AND
      (CONSP Expr)
      (EQ 'lambda (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (LET ((ChX (shen.ch-T (CADR Expr))))
      (LIST 'FUNCTION (CONS 'LAMBDA (CONS (LIST ChX) (CONS (shen.kl-to-lisp (CONS ChX Locals) (SUBST ChX (CADR Expr) (CADDR Expr))) ()))))))

    ; Locals [let X Y Z] -> (let ChX (ch-T X) (protect [LET [[ChX (kl-to-lisp Locals Y)]] (kl-to-lisp [ChX | Locals] (SUBST ChX X Z))]))
    ((AND
      (CONSP Expr)
      (EQ 'let (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (CONSP (CDDDR Expr))
      (NULL (CDDDDR Expr)))
     (LET ((ChX (shen.ch-T (CADR Expr))))
      (LIST 'LET (LIST (LIST ChX (shen.kl-to-lisp Locals (CADDR Expr)))) (shen.kl-to-lisp (CONS ChX Locals) (SUBST ChX (CADR Expr) (CADDDR Expr))))))

    ; _ [defun F Locals Code] -> (protect [DEFUN F Locals (kl-to-lisp Locals Code)])
    ((AND
      (CONSP Expr)
      (EQ 'defun (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (CONSP (CDDDR Expr))
      (NULL (CDDDDR Expr)))
     (LIST 'DEFUN (CADR Expr) (CADDR Expr) (shen.kl-to-lisp (CADDR Expr) (CADDDR Expr))))

    ; Locals [cond | Cond] -> (protect [COND | (MAPCAR (/. C (cond_code Locals C)) Cond)])
    ((AND (CONSP Expr) (EQ 'cond (CAR Expr)))
     (CONS 'COND (MAPCAR (FUNCTION (LAMBDA (C) (shen.cond_code Locals C))) (CDR Expr))))

    ; Params [F | X] ->
    ;   (let Arguments (protect (MAPCAR (/. Y (kl-to-lisp Params Y)) X))
    ;     (optimise-application
    ;       (cases
    ;         (protect (cons? (MEMBER F Params)))
    ;           [apply F [(protect LIST) | Arguments]]
    ;         (cons? F)
    ;           [apply (kl-to-lisp Params F) [(protect LIST) | Arguments]]
    ;         (partial-application? F Arguments)
    ;           (partially-apply F Arguments)
    ;         true
    ;           [(maplispsym F) | Arguments])))
    ((CONSP Expr)
     (LET ((Args (MAPCAR (FUNCTION (LAMBDA (Y) (shen.kl-to-lisp Locals Y))) (CDR Expr))))
      (shen.optimise-application
        (IF (CONSP (MEMBER (CAR Expr) Locals))
          (LIST 'shen.apply (CAR Expr) (CONS 'LIST Args))
          (IF (CONSP (CAR Expr))
            (LIST 'shen.apply (shen.kl-to-lisp Locals (CAR Expr)) (CONS 'LIST Args))
            (IF (shen.wrapper (shen.partial-application? (CAR Expr) Args))
              (shen.partially-apply (CAR Expr) Args)
              (CONS (shen.maplispsym (CAR Expr)) Args)))))))

    ; _ [] -> []
    ((NULL Expr)
     ())

    ; _ S -> (protect [QUOTE S])  where (protect (= (SYMBOLP S) T))
    ((EQ (SYMBOLP Expr) 'T)
     (LIST 'QUOTE Expr))

    ; _ X -> X
    (T
     Expr)))

(DEFUN shen.ch-T (X)
  (IF (EQ T X) 'T1957 X))

(DEFUN shen.apply (F Args)
  (LET ((FSym (shen.maplispsym F)))
    (trap-error
      (shen.apply-help FSym Args)
      #'(LAMBDA (E) (shen.analyse-application F FSym Args (error-to-string E))))))

(DEFUN shen.apply-help (F Args)
  (COND
    ((NULL Args)
     (FUNCALL F))
    ((AND (CONSP Args) (NULL (CDR Args)))
     (FUNCALL F (CAR Args)))
    ((CONSP Args)
     (shen.apply-help (FUNCALL F (CAR Args)) (CDR Args)))
    (T
     (shen.f_error 'shen.apply-help))))

(DEFUN shen.analyse-application (F FSym Args Message)
  (LET ((Lambda
         (IF (shen.wrapper (shen.partial-application? F Args))
          (shen.build-up-lambda-expression FSym F)
          (IF (shen.wrapper (shen.lazyboolop? F))
            (shen.build-up-lambda-expression FSym F)
            (simple-error Message)))))
    (shen.curried-apply Lambda Args)))

(DEFUN shen.build-up-lambda-expression (FSym F)
  (EVAL (shen.mk-lambda FSym (arity F))))

(DEFUN shen.lazyboolop? (Op)
  (IF (OR (EQ Op 'and) #| (EQ Op 'or) |#) ; TODO: why not return 'true for 'or?
    'true
    'false))

(DEFUN shen.curried-apply (F Args)
  (IF (CONSP Args)
    (LET* ((First (CAR Args))
           (Rest  (CDR Args))
           (App   (FUNCALL F First)))
      (IF (NULL Rest)
        App
        (shen.curried-apply App Rest)))
    (simple-error (cn "cannot apply " (shen.app F (FORMAT NIL "~%") 'shen.a)))))

(DEFUN shen.partial-application? (F Args)
  (LET ((Arity (trap-error (arity F) (FUNCTION (LAMBDA (E) -1)))))
    (IF (OR (shen.ABSEQUAL Arity -1)
            (shen.ABSEQUAL Arity (length Args))
            (shen.wrapper (shen.greater? (length Args) Arity)))
      'false
      'true)))

(DEFUN shen.partially-apply (F Args)
  (LET* ((Arity (arity F))
         (Lambda (shen.mk-lambda (LIST (shen.maplispsym F)) Arity)))
      (shen.build-partial-application Lambda Args)))

(DEFUN shen.optimise-application (Expr)
  (COND

    ; [hd X] -> (protect [CAR (optimise-application X)])
    ((AND
      (CONSP Expr)
      (EQ 'hd (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CDDR Expr)))
     (LIST 'CAR (shen.optimise-application (CADR Expr))))

    ; [tl X] -> (protect [CDR (optimise-application X)])
    ((AND
      (CONSP Expr)
      (EQ 'tl (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CDDR Expr)))
     (LIST 'CDR (shen.optimise-application (CADR Expr))))

    ; [cons X Y] -> (protect [CONS (optimise-application X) (optimise-application Y)])
    ((AND
      (CONSP Expr)
      (EQ 'cons (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (LIST 'CONS (shen.optimise-application (CADR Expr)) (shen.optimise-application (CADDR Expr))))

    ; [append X Y] -> (protect [APPEND (optimise-application X) (optimise-application Y)])
    ((AND
      (CONSP Expr)
      (EQ 'append (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (LIST 'APPEND (shen.optimise-application (CADR Expr)) (shen.optimise-application (CADDR Expr))))

    ; [reverse X] -> (protect [REVERSE (optimise-application X)])
    ((AND
      (CONSP Expr)
      (EQ 'reverse (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CDDR Expr)))
     (LIST 'REVERSE (shen.optimise-application (CADR Expr))))

    ; [if P Q R] -> (protect [IF (wrap P) (optimise-application Q) (optimise-application R)])
    ((AND
      (CONSP Expr)
      (EQ 'if (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (CONSP (CDDDR Expr))
      (NULL (CDDDDR Expr)))
     (LIST 'IF (shen.wrap (CADR Expr)) (shen.optimise-application (CADDR Expr)) (shen.optimise-application (CADDDR Expr))))

    ; [value [Quote X]] -> X where (= Quote (protect QUOTE))
    ((AND
      (CONSP Expr)
      (EQ 'value (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CADR Expr))
      (CONSP (CDADR Expr))
      (NULL (CDDADR Expr))
      (NULL (CDDR Expr))
      (EQ (CAADR Expr) 'QUOTE))
     (CADADR Expr))

    ; [+ 1 X] -> [(intern "1+") (optimise-application X)]
    ((AND
      (CONSP Expr)
      (EQ '+ (CAR Expr))
      (CONSP (CDR Expr))
      (shen.ABSEQUAL 1 (CADR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (LIST (intern "1+") (shen.optimise-application (CADDR Expr))))

    ; [+ X 1] -> [(intern "1+") (optimise-application X)]
    ((AND
      (CONSP Expr)
      (EQ '+ (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (shen.ABSEQUAL 1 (CADDR Expr))
      (NULL (CDDDR Expr)))
     (LIST (intern "1+") (shen.optimise-application (CADR Expr))))

    ; [- X 1] -> [(intern "1-") (optimise-application X)]
    ((AND
      (CONSP Expr)
      (EQ '- (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (shen.ABSEQUAL 1 (CADDR Expr))
      (NULL (CDDDR Expr)))
     (LIST (intern "1-") (shen.optimise-application (CADR Expr))))

    ; [X | Y] -> ((protect MAPCAR) (function optimise-application) [X | Y])
    ((CONSP Expr)
     (MAPCAR 'shen.optimise-application Expr))

    ; X -> X
    (T
     Expr)))

(DEFUN shen.mk-lambda (F Arity)
  (IF (shen.ABSEQUAL 0 Arity)
    F
    (LET ((Var (gensym 'V)))
      (LIST 'lambda Var (shen.mk-lambda (shen.endcons F Var) (1- Arity))))))

(DEFUN shen.endcons (F X)
  (IF (CONSP F)
    (APPEND F (LIST X))
    (LIST F X)))

(DEFUN shen.build-partial-application (F Args)
  (COND
    ((NULL Args)  F)
    ((CONSP Args) (shen.build-partial-application (LIST 'FUNCALL F (CAR Args)) (CDR Args)))
    (T            (shen.f_error 'shen.build-partial-application))))

(DEFUN shen.cond_code (Locals Clause)
  (IF (AND (CONSP Clause) (EQ (LIST-LENGTH Clause) 2))
    (LET ((Test   (CAR Clause))
          (Result (CADR Clause)))
      (LIST (shen.lisp_test Locals Test) (shen.kl-to-lisp Locals Result)))
    (shen.f_error 'shen.cond_code)))

(DEFUN shen.lisp_test (Locals Expr)
  (COND
    ((EQ 'true Expr)
     'T)
    ((AND (CONSP Expr) (EQ 'and (CAR Expr)))
     (CONS 'AND (MAPCAR (FUNCTION (LAMBDA (X) (shen.wrap (shen.kl-to-lisp Locals X)))) (CDR Expr))))
    (T
     (shen.wrap (shen.kl-to-lisp Locals Expr)))))

(DEFUN shen.wrap (Expr)
  (COND

    ; [cons? X] -> [(protect CONSP) X]
    ((AND
      (CONSP Expr)
      (EQ 'cons? (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CDDR Expr)))
     (CONS 'CONSP (CDR Expr)))

    ; [string? X] -> [(protect STRINGP) X]
    ((AND
      (CONSP Expr)
      (EQ 'string? (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CDDR Expr)))
     (CONS 'STRINGP (CDR Expr)))

    ; [number? X] -> [(protect NUMBERP) X]
    ((AND
      (CONSP Expr)
      (EQ 'number? (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CDDR Expr)))
     (CONS 'NUMBERP (CDR Expr)))

    ; [empty? X] -> [(protect NULL) X]
    ((AND
      (CONSP Expr)
      (EQ 'empty? (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CDDR Expr)))
     (CONS 'NULL (CDR Expr)))

    ; [and P Q] -> [(protect AND) (wrap P) (wrap Q)]
    ((AND
      (CONSP Expr)
      (EQ 'and (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (LIST* 'AND (shen.wrap (CADR Expr)) (shen.wrap (CADDR Expr)) NIL))

    ; [or P Q] -> [(protect OR) (wrap P) (wrap Q)]
    ((AND
      (CONSP Expr)
      (EQ 'or (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (LIST* 'OR (shen.wrap (CADR Expr)) (shen.wrap (CADDR Expr)) NIL))

    ; [not P] -> [(protect NOT) (wrap P)]
    ((AND
      (CONSP Expr)
      (EQ 'not (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CDDR Expr)))
     (LIST* 'NOT (shen.wrap (CADR Expr)) NIL))

    ; [equal? X []] -> [(protect NULL) X]
    ((AND
      (CONSP Expr)
      (EQ 'shen.equal? (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CADDR Expr))
      (NULL (CDDDR Expr)))
     (LIST* 'NULL (CADR Expr) NIL))

    ; [equal? [] X] -> [(protect NULL) X]
    ((AND
      (CONSP Expr)
      (EQ 'shen.equal? (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CADR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (CONS 'NULL (CDDR Expr)))

    ; [equal? X [Quote Y]] -> [(protect EQ) X [Quote Y]] where (and (= ((protect SYMBOLP) Y) (protect T)) (= Quote (protect QUOTE)))
    ; [equal? [Quote Y] X] -> [(protect EQ) [Quote Y] X] where (and (= ((protect SYMBOLP) Y) (protect T)) (= Quote (protect QUOTE)))
    ; [equal? [fail] X] -> [(protect EQ) [fail] X]
    ; [equal? X [fail]] -> [(protect EQ) X [fail]]
    ((OR
      (AND
        (CONSP Expr)
        (EQ 'shen.equal? (CAR Expr))
        (CONSP (CDR Expr))
        (CONSP (CDDR Expr))
        (CONSP (CADDR Expr))
        (CONSP (CDADDR Expr))
        (NULL (CDR (CDADDR Expr)))
        (NULL (CDDDR Expr))
        (EQ (SYMBOLP (CAR (CDADDR Expr))) 'T)
        (EQ (CAADDR Expr) 'QUOTE))
      (AND
        (CONSP Expr)
        (EQ 'shen.equal? (CAR Expr))
        (CONSP (CDR Expr))
        (CONSP (CADR Expr))
        (CONSP (CDADR Expr))
        (NULL (CDDADR Expr))
        (CONSP (CDDR Expr))
        (NULL (CDDDR Expr))
        (EQ (SYMBOLP (CADADR Expr)) 'T)
        (EQ (CAADR Expr) 'QUOTE))
      (AND
        (CONSP Expr)
        (EQ 'shen.equal? (CAR Expr))
        (CONSP (CDR Expr))
        (CONSP (CADR Expr))
        (EQ 'fail (CAADR Expr))
        (NULL (CDADR Expr))
        (CONSP (CDDR Expr))
        (NULL (CDDDR Expr)))
      (AND
        (CONSP Expr)
        (EQ 'shen.equal? (CAR Expr))
        (CONSP (CDR Expr))
        (CONSP (CDDR Expr))
        (CONSP (CADDR Expr))
        (EQ 'fail (CAADDR Expr))
        (NULL (CDADDR Expr))
        (NULL (CDDDR Expr))))
     (CONS 'EQ (CDR Expr)))

    ; [equal? S X] -> [(protect EQUAL) S X] where (string? S)
    ; [equal? X S] -> [(protect EQUAL) X S] where (string? S)
    ((OR
      (AND
        (CONSP Expr)
        (EQ 'shen.equal? (CAR Expr))
        (CONSP (CDR Expr))
        (CONSP (CDDR Expr))
        (NULL (CDDDR Expr))
        (STRINGP (CADR Expr)))
      (AND
        (CONSP Expr)
        (EQ 'shen.equal? (CAR Expr))
        (CONSP (CDR Expr))
        (CONSP (CDDR Expr))
        (NULL (CDDDR Expr))
        (STRINGP (CADDR Expr))))
     (CONS 'EQUAL (CDR Expr)))

    ; [equal? X N] -> [(protect EQL) X N] where (number? N)
    ((AND
      (CONSP Expr)
      (EQ 'shen.equal? (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr))
      (NUMBERP (CADDR Expr)))
     (LIST 'IF (LIST 'NUMBERP (CADR Expr)) (CONS '= (CDR Expr))))

    ; [equal? N X] -> [(protect EQL) X N] where (number? N)
    ((AND
      (CONSP Expr)
      (EQ 'shen.equal? (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr))
      (NUMBERP (CADR Expr)))
     (LIST 'IF (CONS 'NUMBERP (CDDR Expr)) (LIST '= (CADDR Expr) (CADR Expr))))

    ; [equal? X Y] -> [(protect shen.ABSEQUAL) X Y]
    ((AND
      (CONSP Expr)
      (EQ 'shen.equal? (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (CONS 'shen.ABSEQUAL (CDR Expr)))

    ; [greater? X Y] -> [> X Y]
    ((AND
      (CONSP Expr)
      (EQ 'shen.greater? (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (CONS '> (CDR Expr)))

    ; [greater-than-or-equal-to? X Y] -> [>= X Y]
    ((AND
      (CONSP Expr)
      (EQ 'shen.greater-than-or-equal-to? (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (CONS '>= (CDR Expr)))

    ; [less? X Y] -> [< X Y]    
    ((AND
      (CONSP Expr)
      (EQ 'shen.less? (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (CONS '< (CDR Expr)))

    ; [less-than-or-equal-to? X Y] -> [<= X Y]
    ((AND
      (CONSP Expr)
      (EQ 'shen.less-than-or-equal-to? (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (CONS '<= (CDR Expr)))

    ; X -> [wrapper X]
    (T
     (CONS 'shen.wrapper (CONS Expr NIL)))))

(DEFUN shen.wrapper (X)
  (COND
    ((EQ 'true X)  'T)
    ((EQ 'false X) ())
    (T (simple-error (cn "boolean expected: not " (shen.app X (FORMAT NIL "~%") 'shen.s))))))

(DEFUN shen.maplispsym (Symbol)
  (COND
    ((EQ Symbol '=)  'shen.equal?)
    ((EQ Symbol '>)  'shen.greater?)
    ((EQ Symbol '<)  'shen.less?)
    ((EQ Symbol '>=) 'shen.greater-than-or-equal-to?)
    ((EQ Symbol '<=) 'shen.less-than-or-equal-to?)
    ((EQ Symbol '+)  'shen.add)
    ((EQ Symbol '-)  'shen.subtract)
    ((EQ Symbol '/)  'shen.divide)
    ((EQ Symbol '*)  'shen.multiply)
    (T               Symbol)))
