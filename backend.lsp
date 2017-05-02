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
    ((AND (CONSP Expr) (EQ 'type (CAR Expr)) (CONSP (CDR Expr)) (CONSP (CDDR Expr)) (NULL (CDDDR Expr)))
     (shen.kl-to-lisp Locals (CAR (CDR Expr))))
    ((AND (CONSP Expr) (EQ 'lambda (CAR Expr)) (CONSP (CDR Expr)) (CONSP (CDDR Expr)) (NULL (CDDDR Expr)))
     (LET ((ChX (shen.ch-T (CAR (CDR Expr)))))
      (LIST 'FUNCTION (CONS 'LAMBDA (CONS (LIST ChX) (CONS (shen.kl-to-lisp (CONS ChX Locals) (SUBST ChX (CADR Expr) (CADDR Expr))) ()))))))
    ((AND (CONSP Expr) (EQ 'let (CAR Expr)) (CONSP (CDR Expr)) (CONSP (CDDR Expr)) (CONSP (CDDDR Expr)) (NULL (CDDDDR Expr)))
     (LET ((ChX (shen.ch-T (CADR Expr))))
      (LIST 'LET (LIST (LIST ChX (shen.kl-to-lisp Locals (CADDR Expr)))) (shen.kl-to-lisp (CONS ChX Locals) (SUBST ChX (CADR Expr) (CADDDR Expr))))))
    ((AND (CONSP Expr) (EQ 'defun (CAR Expr)) (CONSP (CDR Expr)) (CONSP (CDDR Expr)) (CONSP (CDDDR Expr)) (NULL (CDDDDR Expr)))
     (LIST 'DEFUN (CADR Expr) (CADDR Expr) (shen.kl-to-lisp (CADDR Expr) (CADDDR Expr))))
    ((AND (CONSP Expr) (EQ 'cond (CAR Expr)))
     (CONS 'COND (MAPCAR (FUNCTION (LAMBDA (C) (shen.cond_code Locals C))) (CDR Expr))))
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
    ((NULL Expr)
     ())
    ((EQ (SYMBOLP Expr) (QUOTE T))
     (LIST (QUOTE QUOTE) Expr))
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

(DEFUN shen.optimise-application (V673)
  (COND
    ((AND (CONSP V673) (AND (EQ (QUOTE hd) (CAR V673)) (AND (CONSP (CDR V673)) (NULL (CDR (CDR V673)))))) (CONS (QUOTE CAR) (CONS (shen.optimise-application (CAR (CDR V673))) ())))
    ((AND (CONSP V673) (AND (EQ (QUOTE tl) (CAR V673)) (AND (CONSP (CDR V673)) (NULL (CDR (CDR V673)))))) (CONS (QUOTE CDR) (CONS (shen.optimise-application (CAR (CDR V673))) ())))
    ((AND (CONSP V673) (AND (EQ (QUOTE cons) (CAR V673)) (AND (CONSP (CDR V673)) (AND (CONSP (CDR (CDR V673))) (NULL (CDR (CDR (CDR V673)))))))) (CONS (QUOTE CONS) (CONS (shen.optimise-application (CAR (CDR V673))) (CONS (shen.optimise-application (CAR (CDR (CDR V673)))) ()))))
    ((AND (CONSP V673) (AND (EQ (QUOTE append) (CAR V673)) (AND (CONSP (CDR V673)) (AND (CONSP (CDR (CDR V673))) (NULL (CDR (CDR (CDR V673)))))))) (CONS (QUOTE APPEND) (CONS (shen.optimise-application (CAR (CDR V673))) (CONS (shen.optimise-application (CAR (CDR (CDR V673)))) ()))))
    ((AND (CONSP V673) (AND (EQ (QUOTE reverse) (CAR V673)) (AND (CONSP (CDR V673)) (NULL (CDR (CDR V673)))))) (CONS (QUOTE REVERSE) (CONS (shen.optimise-application (CAR (CDR V673))) ())))
    ((AND (CONSP V673) (AND (EQ (QUOTE if) (CAR V673)) (AND (CONSP (CDR V673)) (AND (CONSP (CDR (CDR V673))) (AND (CONSP (CDR (CDR (CDR V673)))) (NULL (CDR (CDR (CDR (CDR V673)))))))))) (CONS (QUOTE IF) (CONS (shen.wrap (CAR (CDR V673))) (CONS (shen.optimise-application (CAR (CDR (CDR V673)))) (CONS (shen.optimise-application (CAR (CDR (CDR (CDR V673))))) ())))))
    ((AND (CONSP V673) (AND (EQ (QUOTE value) (CAR V673)) (AND (CONSP (CDR V673)) (AND (CONSP (CAR (CDR V673))) (AND (CONSP (CDR (CAR (CDR V673)))) (AND (NULL (CDR (CDR (CAR (CDR V673))))) (AND (NULL (CDR (CDR V673))) (EQ (CAR (CAR (CDR V673))) (QUOTE QUOTE))))))))) (CAR (CDR (CAR (CDR V673)))))
    ((AND (CONSP V673) (AND (EQ (QUOTE +) (CAR V673)) (AND (CONSP (CDR V673)) (AND (shen.ABSEQUAL 1 (CAR (CDR V673))) (AND (CONSP (CDR (CDR V673))) (NULL (CDR (CDR (CDR V673))))))))) (CONS (intern "1+") (CONS (shen.optimise-application (CAR (CDR (CDR V673)))) ())))
    ((AND (CONSP V673) (AND (EQ (QUOTE +) (CAR V673)) (AND (CONSP (CDR V673)) (AND (CONSP (CDR (CDR V673))) (AND (shen.ABSEQUAL 1 (CAR (CDR (CDR V673)))) (NULL (CDR (CDR (CDR V673))))))))) (CONS (intern "1+") (CONS (shen.optimise-application (CAR (CDR V673))) ())))
    ((AND (CONSP V673) (AND (EQ (QUOTE -) (CAR V673)) (AND (CONSP (CDR V673)) (AND (CONSP (CDR (CDR V673))) (AND (shen.ABSEQUAL 1 (CAR (CDR (CDR V673)))) (NULL (CDR (CDR (CDR V673))))))))) (CONS (intern "1-") (CONS (shen.optimise-application (CAR (CDR V673))) ())))
    ((CONSP V673) (MAPCAR (QUOTE shen.optimise-application) V673))
    (T V673)))

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
   ((AND (CONSP Expr)
         (AND (EQ 'cons? (CAR Expr))
              (AND (CONSP (CDR Expr)) (NULL (CDR (CDR Expr))))))
    (CONS 'CONSP (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'string? (CAR Expr))
              (AND (CONSP (CDR Expr)) (NULL (CDR (CDR Expr))))))
    (CONS 'STRINGP (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'number? (CAR Expr))
              (AND (CONSP (CDR Expr)) (NULL (CDR (CDR Expr))))))
    (CONS 'NUMBERP (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'empty? (CAR Expr))
              (AND (CONSP (CDR Expr)) (NULL (CDR (CDR Expr))))))
    (CONS 'NULL (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'and (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (NULL (CDR (CDR (CDR Expr))))))))
    (CONS 'AND
          (CONS (shen.wrap (CAR (CDR Expr)))
                (CONS (shen.wrap (CAR (CDR (CDR Expr)))) NIL))))
   ((AND (CONSP Expr)
         (AND (EQ 'or (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (NULL (CDR (CDR (CDR Expr))))))))
    (CONS 'OR
          (CONS (shen.wrap (CAR (CDR Expr)))
                (CONS (shen.wrap (CAR (CDR (CDR Expr)))) NIL))))
   ((AND (CONSP Expr)
         (AND (EQ 'not (CAR Expr))
              (AND (CONSP (CDR Expr)) (NULL (CDR (CDR Expr))))))
    (CONS 'NOT (CONS (shen.wrap (CAR (CDR Expr))) NIL)))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.equal? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (AND (NULL (CAR (CDR (CDR Expr))))
                             (NULL (CDR (CDR (CDR Expr)))))))))
    (CONS 'NULL (CONS (CAR (CDR Expr)) NIL)))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.equal? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (NULL (CAR (CDR Expr)))
                        (AND (CONSP (CDR (CDR Expr)))
                             (NULL (CDR (CDR (CDR Expr)))))))))
    (CONS 'NULL (CDR (CDR Expr))))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.equal? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (AND (CONSP (CAR (CDR (CDR Expr))))
                             (AND (CONSP (CDR (CAR (CDR (CDR Expr)))))
                                  (AND
                                   (NULL (CDR (CDR (CAR (CDR (CDR Expr))))))
                                   (AND (NULL (CDR (CDR (CDR Expr))))
                                        (AND
                                         (EQ
                                          (SYMBOLP
                                           (CAR (CDR (CAR (CDR (CDR Expr))))))
                                          'T)
                                         (EQ (CAR (CAR (CDR (CDR Expr))))
                                             'QUOTE))))))))))
    (CONS 'EQ (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.equal? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CAR (CDR Expr)))
                        (AND (CONSP (CDR (CAR (CDR Expr))))
                             (AND (NULL (CDR (CDR (CAR (CDR Expr)))))
                                  (AND (CONSP (CDR (CDR Expr)))
                                       (AND (NULL (CDR (CDR (CDR Expr))))
                                            (AND
                                             (EQ
                                              (SYMBOLP
                                               (CAR (CDR (CAR (CDR Expr)))))
                                              'T)
                                             (EQ (CAR (CAR (CDR Expr)))
                                                 'QUOTE))))))))))
    (CONS 'EQ (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.equal? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CAR (CDR Expr)))
                        (AND (EQ 'fail (CAR (CAR (CDR Expr))))
                             (AND (NULL (CDR (CAR (CDR Expr))))
                                  (AND (CONSP (CDR (CDR Expr)))
                                       (NULL (CDR (CDR (CDR Expr)))))))))))
    (CONS 'EQ (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.equal? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (AND (CONSP (CAR (CDR (CDR Expr))))
                             (AND (EQ 'fail (CAR (CAR (CDR (CDR Expr)))))
                                  (AND (NULL (CDR (CAR (CDR (CDR Expr)))))
                                       (NULL (CDR (CDR (CDR Expr)))))))))))
    (CONS 'EQ (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.equal? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (AND (NULL (CDR (CDR (CDR Expr))))
                             (STRINGP (CAR (CDR Expr))))))))
    (CONS 'EQUAL (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.equal? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (AND (NULL (CDR (CDR (CDR Expr))))
                             (STRINGP (CAR (CDR (CDR Expr)))))))))
    (CONS 'EQUAL (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.equal? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (AND (NULL (CDR (CDR (CDR Expr))))
                             (NUMBERP (CAR (CDR (CDR Expr)))))))))
    (CONS 'IF
          (CONS (CONS 'NUMBERP (CONS (CAR (CDR Expr)) NIL))
                (CONS (CONS '= (CDR Expr)) NIL))))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.equal? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (AND (NULL (CDR (CDR (CDR Expr))))
                             (NUMBERP (CAR (CDR Expr))))))))
    (CONS 'IF
          (CONS (CONS 'NUMBERP (CDR (CDR Expr)))
                (CONS
                 (CONS '=
                       (CONS (CAR (CDR (CDR Expr)))
                             (CONS (CAR (CDR Expr)) NIL)))
                 NIL))))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.equal? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (NULL (CDR (CDR (CDR Expr))))))))
    (CONS 'shen.ABSEQUAL (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.greater? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (NULL (CDR (CDR (CDR Expr))))))))
    (CONS '> (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.greater-than-or-equal-to? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (NULL (CDR (CDR (CDR Expr))))))))
    (CONS '>= (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.less? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (NULL (CDR (CDR (CDR Expr))))))))
    (CONS '< (CDR Expr)))
   ((AND (CONSP Expr)
         (AND (EQ 'shen.less-than-or-equal-to? (CAR Expr))
              (AND (CONSP (CDR Expr))
                   (AND (CONSP (CDR (CDR Expr)))
                        (NULL (CDR (CDR (CDR Expr))))))))
    (CONS '<= (CDR Expr)))
   (T (CONS 'shen.wrapper (CONS Expr NIL)))))

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
    (T Symbol)))
