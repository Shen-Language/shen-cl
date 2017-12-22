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

(DEFUN shen-cl.kl->lisp (Locals Expr)
  (COND
    ((CONSP (MEMBER Expr Locals))
     Expr)

    ; Locals [type X _] -> (kl->lisp Locals X)
    ((AND
      (CONSP Expr)
      (EQ 'type (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (shen-cl.kl->lisp Locals (CADR Expr)))

    ; Locals [lambda X Y] -> (let ChX (ch-T X) (protect [FUNCTION [LAMBDA [ChX] (kl->lisp [ChX | Locals] (SUBST ChX X Y))]]))
    ((AND
      (CONSP Expr)
      (EQ 'lambda (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (LET ((ChX (shen-cl.ch-T (CADR Expr))))
      (LIST 'FUNCTION (CONS 'LAMBDA (CONS (LIST ChX) (CONS (shen-cl.kl->lisp (CONS ChX Locals) (SUBST ChX (CADR Expr) (CADDR Expr))) ()))))))

    ; Locals [let X Y Z] -> (let ChX (ch-T X) (protect [LET [[ChX (kl->lisp Locals Y)]] (kl->lisp [ChX | Locals] (SUBST ChX X Z))]))
    ((AND
      (CONSP Expr)
      (EQ 'let (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (CONSP (CDDDR Expr))
      (NULL (CDDDDR Expr)))
     (LET ((ChX (shen-cl.ch-T (CADR Expr))))
      (LIST 'LET (LIST (LIST ChX (shen-cl.kl->lisp Locals (CADDR Expr)))) (shen-cl.kl->lisp (CONS ChX Locals) (SUBST ChX (CADR Expr) (CADDDR Expr))))))

    ; _ [defun F Locals Code] -> (protect [DEFUN F Locals (kl->lisp Locals Code)])
    ((AND
      (CONSP Expr)
      (EQ 'defun (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (CONSP (CDDDR Expr))
      (NULL (CDDDDR Expr)))
     (LIST 'DEFUN (CADR Expr) (CADDR Expr) (shen-cl.kl->lisp (CADDR Expr) (CADDDR Expr))))

    ; Locals [cond | Cond] -> (protect [COND | (MAPCAR (/. C (cond-code Locals C)) Cond)])
    ((AND (CONSP Expr) (EQ 'cond (CAR Expr)))
     (CONS
      'COND
      (APPEND
        (MAPCAR #'(LAMBDA (C) (shen-cl.cond-code Locals C)) (CDR Expr))
        '((T (simple-error "No condition was true"))))))

    ; Params [F | X] ->
    ;   (let Arguments (protect (MAPCAR (/. Y (kl->lisp Params Y)) X))
    ;     (optimise-application
    ;       (cases
    ;         (protect (cons? (MEMBER F Params)))
    ;           [apply F [(protect LIST) | Arguments]]
    ;         (cons? F)
    ;           [apply (kl->lisp Params F) [(protect LIST) | Arguments]]
    ;         (partial-application? F Arguments)
    ;           (partially-apply F Arguments)
    ;         true
    ;           [(maplispsym F) | Arguments])))
    ((CONSP Expr)
     (LET ((Args (MAPCAR #'(LAMBDA (Y) (shen-cl.kl->lisp Locals Y)) (CDR Expr))))
      (shen-cl.optimise-application
        (IF (CONSP (MEMBER (CAR Expr) Locals))
          (LIST 'shen-cl.apply (CAR Expr) (CONS 'LIST Args))
          (IF (CONSP (CAR Expr))
            (LIST 'shen-cl.apply (shen-cl.kl->lisp Locals (CAR Expr)) (CONS 'LIST Args))
            (IF (shen-cl.true? (shen-cl.partial-application? (CAR Expr) Args))
              (shen-cl.partially-apply (CAR Expr) Args)
              (CONS (shen-cl.maplispsym (CAR Expr)) Args)))))))

    ; _ [] -> []
    ((NULL Expr)
     ())

    ; _ S -> (protect [QUOTE S])  where (protect (= (SYMBOLP S) T))
    ((EQ (SYMBOLP Expr) 'T)
     (LIST 'QUOTE Expr))

    ; _ X -> X
    (T
     Expr)))

(DEFUN shen-cl.ch-T (X)
  (IF (EQ T X) 'T1957 X))

(DEFUN shen-cl.apply (F Args)
  (LET ((FSym (shen-cl.maplispsym F)))
    (trap-error
      (shen-cl.apply-help FSym Args)
      #'(LAMBDA (E) (shen-cl.analyse-application F FSym Args (error-to-string E))))))

(DEFUN shen-cl.apply-help (F Args)
  (COND
    ((NULL Args)
     (FUNCALL F))
    ((AND (CONSP Args) (NULL (CDR Args)))
     (FUNCALL F (CAR Args)))
    ((CONSP Args)
     (shen-cl.apply-help (FUNCALL F (CAR Args)) (CDR Args)))
    (T
     (shen-cl.f_error 'shen-cl.apply-help))))

(DEFUN shen-cl.analyse-application (F FSym Args Message)
  (LET ((Lambda
         (IF (shen-cl.true? (shen-cl.partial-application? F Args))
          (shen-cl.build-up-lambda-expression FSym F)
          (IF (shen-cl.true? (shen-cl.lazyboolop? F))
            (shen-cl.build-up-lambda-expression FSym F)
            (simple-error Message)))))
    (shen-cl.curried-apply Lambda Args)))

(DEFUN shen-cl.build-up-lambda-expression (FSym F)
  (EVAL (shen-cl.mk-lambda FSym (arity F))))

(DEFUN shen-cl.lazyboolop? (Op)
  (IF (OR (EQ Op 'and) #| (EQ Op 'or) |#) ; TODO: why not return 'true for 'or?
    'true
    'false))

(DEFUN shen-cl.curried-apply (F Args)
  (IF (CONSP Args)
    (LET* ((First (CAR Args))
           (Rest  (CDR Args))
           (App   (FUNCALL F First)))
      (IF (NULL Rest)
        App
        (shen-cl.curried-apply App Rest)))
    (simple-error (cn "cannot apply " (shen-cl.app F (FORMAT NIL "~%") 'shen-cl.a)))))

(DEFUN shen-cl.partial-application? (F Args)
  (LET ((Arity (trap-error (arity F) #'(LAMBDA (E) -1))))
    (IF (OR (shen-cl.== Arity -1)
            (shen-cl.== Arity (length Args))
            (shen-cl.true? (shen-cl.> (length Args) Arity)))
      'false
      'true)))

(DEFUN shen-cl.partially-apply (F Args)
  (LET* ((Arity (arity F))
         (Lambda (shen-cl.mk-lambda (LIST (shen-cl.maplispsym F)) Arity)))
      (shen-cl.build-partial-application Lambda Args)))

(DEFUN shen-cl.optimise-application (Expr)
  (COND

    ; [hd X] -> (protect [CAR (optimise-application X)])
    ((AND
      (CONSP Expr)
      (EQ 'hd (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CDDR Expr)))
     (LIST 'CAR (shen-cl.optimise-application (CADR Expr))))

    ; [tl X] -> (protect [CDR (optimise-application X)])
    ((AND
      (CONSP Expr)
      (EQ 'tl (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CDDR Expr)))
     (LIST 'CDR (shen-cl.optimise-application (CADR Expr))))

    ; [cons X Y] -> (protect [CONS (optimise-application X) (optimise-application Y)])
    ((AND
      (CONSP Expr)
      (EQ 'cons (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (LIST 'CONS (shen-cl.optimise-application (CADR Expr)) (shen-cl.optimise-application (CADDR Expr))))

    ; [append X Y] -> (protect [APPEND (optimise-application X) (optimise-application Y)])
    ((AND
      (CONSP Expr)
      (EQ 'append (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (LIST 'APPEND (shen-cl.optimise-application (CADR Expr)) (shen-cl.optimise-application (CADDR Expr))))

    ; [reverse X] -> (protect [REVERSE (optimise-application X)])
    ((AND
      (CONSP Expr)
      (EQ 'reverse (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CDDR Expr)))
     (LIST 'REVERSE (shen-cl.optimise-application (CADR Expr))))

    ; [if P Q R] -> (protect [IF (wrap P) (optimise-application Q) (optimise-application R)])
    ((AND
      (CONSP Expr)
      (EQ 'if (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (CONSP (CDDDR Expr))
      (NULL (CDDDDR Expr)))
     (LIST 'IF (shen-cl.wrap (CADR Expr)) (shen-cl.optimise-application (CADDR Expr)) (shen-cl.optimise-application (CADDDR Expr))))

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
      (shen-cl.== 1 (CADR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (LIST (intern "1+") (shen-cl.optimise-application (CADDR Expr))))

    ; [+ X 1] -> [(intern "1+") (optimise-application X)]
    ((AND
      (CONSP Expr)
      (EQ '+ (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (shen-cl.== 1 (CADDR Expr))
      (NULL (CDDDR Expr)))
     (LIST (intern "1+") (shen-cl.optimise-application (CADR Expr))))

    ; [- X 1] -> [(intern "1-") (optimise-application X)]
    ((AND
      (CONSP Expr)
      (EQ '- (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (shen-cl.== 1 (CADDR Expr))
      (NULL (CDDDR Expr)))
     (LIST (intern "1-") (shen-cl.optimise-application (CADR Expr))))

    ; [X | Y] -> ((protect MAPCAR) (function optimise-application) [X | Y])
    ((CONSP Expr)
     (MAPCAR 'shen-cl.optimise-application Expr))

    ; X -> X
    (T
     Expr)))

(DEFUN shen-cl.mk-lambda (F Arity)
  (IF (shen-cl.== 0 Arity)
    F
    (LET ((Var (gensym 'V)))
      (LIST 'lambda Var (shen-cl.mk-lambda (shen-cl.endcons F Var) (1- Arity))))))

(DEFUN shen-cl.endcons (F X)
  (IF (CONSP F)
    (APPEND F (LIST X))
    (LIST F X)))

(DEFUN shen-cl.build-partial-application (F Args)
  (COND
    ((NULL Args)  F)
    ((CONSP Args) (shen-cl.build-partial-application (LIST 'FUNCALL F (CAR Args)) (CDR Args)))
    (T            (shen-cl.f_error 'shen-cl.build-partial-application))))

(DEFUN shen-cl.cond-code (Locals Clause)
  (IF (AND (CONSP Clause) (EQ (LIST-LENGTH Clause) 2))
    (LET ((Test   (CAR Clause))
          (Result (CADR Clause)))
      (LIST (shen-cl.lisp-test Locals Test) (shen-cl.kl->lisp Locals Result)))
    (shen-cl.f_error 'shen-cl.cond-code)))

(DEFUN shen-cl.lisp-test (Locals Expr)
  (COND
    ((EQ 'true Expr)
     'T)
    ((AND (CONSP Expr) (EQ 'and (CAR Expr)))
     (CONS 'AND (MAPCAR #'(LAMBDA (X) (shen-cl.wrap (shen-cl.kl->lisp Locals X))) (CDR Expr))))
    (T
     (shen-cl.wrap (shen-cl.kl->lisp Locals Expr)))))

(DEFUN shen-cl.wrap (Expr)
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
     (LIST* 'AND (shen-cl.wrap (CADR Expr)) (shen-cl.wrap (CADDR Expr)) NIL))

    ; [or P Q] -> [(protect OR) (wrap P) (wrap Q)]
    ((AND
      (CONSP Expr)
      (EQ 'or (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (LIST* 'OR (shen-cl.wrap (CADR Expr)) (shen-cl.wrap (CADDR Expr)) NIL))

    ; [not P] -> [(protect NOT) (wrap P)]
    ((AND
      (CONSP Expr)
      (EQ 'not (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CDDR Expr)))
     (LIST* 'NOT (shen-cl.wrap (CADR Expr)) NIL))

    ; [shen-cl.= X []] -> [(protect NULL) X]
    ((AND
      (CONSP Expr)
      (EQ 'shen-cl.= (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CADDR Expr))
      (NULL (CDDDR Expr)))
     (LIST* 'NULL (CADR Expr) NIL))

    ; [shen-cl.= [] X] -> [(protect NULL) X]
    ((AND
      (CONSP Expr)
      (EQ 'shen-cl.= (CAR Expr))
      (CONSP (CDR Expr))
      (NULL (CADR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (CONS 'NULL (CDDR Expr)))

    ; [shen-cl.= X [Quote Y]] -> [(protect EQ) X [Quote Y]] where (and (= ((protect SYMBOLP) Y) (protect T)) (= Quote (protect QUOTE)))
    ; [shen-cl.= [Quote Y] X] -> [(protect EQ) [Quote Y] X] where (and (= ((protect SYMBOLP) Y) (protect T)) (= Quote (protect QUOTE)))
    ; [shen-cl.= [fail] X] -> [(protect EQ) [fail] X]
    ; [shen-cl.= X [fail]] -> [(protect EQ) X [fail]]
    ((OR
      (AND
        (CONSP Expr)
        (EQ 'shen-cl.= (CAR Expr))
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
        (EQ 'shen-cl.= (CAR Expr))
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
        (EQ 'shen-cl.= (CAR Expr))
        (CONSP (CDR Expr))
        (CONSP (CADR Expr))
        (EQ 'fail (CAADR Expr))
        (NULL (CDADR Expr))
        (CONSP (CDDR Expr))
        (NULL (CDDDR Expr)))
      (AND
        (CONSP Expr)
        (EQ 'shen-cl.= (CAR Expr))
        (CONSP (CDR Expr))
        (CONSP (CDDR Expr))
        (CONSP (CADDR Expr))
        (EQ 'fail (CAADDR Expr))
        (NULL (CDADDR Expr))
        (NULL (CDDDR Expr))))
     (CONS 'EQ (CDR Expr)))

    ; [shen-cl.= S X] -> [(protect EQUAL) S X] where (string? S)
    ; [shen-cl.= X S] -> [(protect EQUAL) X S] where (string? S)
    ((OR
      (AND
        (CONSP Expr)
        (EQ 'shen-cl.= (CAR Expr))
        (CONSP (CDR Expr))
        (CONSP (CDDR Expr))
        (NULL (CDDDR Expr))
        (STRINGP (CADR Expr)))
      (AND
        (CONSP Expr)
        (EQ 'shen-cl.= (CAR Expr))
        (CONSP (CDR Expr))
        (CONSP (CDDR Expr))
        (NULL (CDDDR Expr))
        (STRINGP (CADDR Expr))))
     (CONS 'EQUAL (CDR Expr)))

    ; [shen-cl.= X N] -> [(protect EQL) X N] where (number? N)
    ((AND
      (CONSP Expr)
      (EQ 'shen-cl.= (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr))
      (NUMBERP (CADDR Expr)))
     (LIST 'IF (LIST 'NUMBERP (CADR Expr)) (CONS '= (CDR Expr))))

    ; [shen-cl.= N X] -> [(protect EQL) X N] where (number? N)
    ((AND
      (CONSP Expr)
      (EQ 'shen-cl.= (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr))
      (NUMBERP (CADR Expr)))
     (LIST 'IF (CONS 'NUMBERP (CDDR Expr)) (LIST '= (CADDR Expr) (CADR Expr))))

    ; [shen-cl.= X Y] -> [(protect shen-cl.==) X Y]
    ((AND
      (CONSP Expr)
      (EQ 'shen-cl.= (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (CONS 'shen-cl.== (CDR Expr)))

    ; [shen-cl.> X Y] -> [> X Y]
    ((AND
      (CONSP Expr)
      (EQ 'shen-cl.> (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (CONS '> (CDR Expr)))

    ; [shen-cl.>= X Y] -> [>= X Y]
    ((AND
      (CONSP Expr)
      (EQ 'shen-cl.>= (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (CONS '>= (CDR Expr)))

    ; [shen-cl.< X Y] -> [< X Y]    
    ((AND
      (CONSP Expr)
      (EQ 'shen-cl.< (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (CONS '< (CDR Expr)))

    ; [shen-cl.<= X Y] -> [<= X Y]
    ((AND
      (CONSP Expr)
      (EQ 'shen-cl.<= (CAR Expr))
      (CONSP (CDR Expr))
      (CONSP (CDDR Expr))
      (NULL (CDDDR Expr)))
     (CONS '<= (CDR Expr)))

    ; X -> [shen-cl.true? X]
    (T
     (LIST* 'shen-cl.true? Expr NIL))))

(DEFUN shen-cl.true? (X)
  (COND
    ((EQ 'true X)  'T)
    ((EQ 'false X) ())
    (T (simple-error (cn "boolean expected: not ~A~%" X)))))

(DEFUN shen-cl.maplispsym (Symbol)
  (COND
    ((EQ Symbol '=)  'shen-cl.=)
    ((EQ Symbol '>)  'shen-cl.>)
    ((EQ Symbol '<)  'shen-cl.<)
    ((EQ Symbol '>=) 'shen-cl.>=)
    ((EQ Symbol '<=) 'shen-cl.<=)
    ((EQ Symbol '+)  'shen-cl.+)
    ((EQ Symbol '-)  'shen-cl.-)
    ((EQ Symbol '/)  'shen-cl./)
    ((EQ Symbol '*)  'shen-cl.*)
    (T               Symbol)))
