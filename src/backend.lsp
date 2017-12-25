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

    ; Retain empty lists and local variables
    ((OR (NULL Expr) (CONSP (MEMBER Expr Locals)))
     Expr)

    ; Quote idle symbols
    ((EQ (SYMBOLP Expr) 'T)
     (LIST 'QUOTE Expr))

    ; Handle special forms, function applications
    ((CONSP Expr)
     (COND

      ; Ignore type expressions
      ((shen-cl.form? 'type 3 Expr)
       (shen-cl.kl->lisp Locals (CADR Expr)))

      ; Build lambda, escaping param with shen-cl.rename and subtituting variable in body
      ((shen-cl.form? 'lambda 3 Expr)
       (LET ((Renamed (shen-cl.rename (CADR Expr))))
        (LIST
          'FUNCTION
          (LIST
            'LAMBDA
            (LIST Renamed)
            (shen-cl.kl->lisp
              (CONS Renamed Locals)
              (SUBST Renamed (CADR Expr) (CADDR Expr)))))))

      ; Flatten nested let's into single LET*
      ; TODO: SUBST symbol in body when shen-cl.rename changes it
      ((shen-cl.form? 'let 4 Expr)
       (LET* ((Lets (shen-cl.flatten-lets Expr))
              (Bindings (CAR Lets))
              (Body (CDR Lets)))
        (LIST
          'LET*
          (shen-cl.let-bindings Locals Bindings)
          (shen-cl.kl->lisp
            (APPEND (MAPCAR #'CAR Bindings) Locals)
            Body))))

      ; Flatten nested do's into single PROGN
      ((shen-cl.form? 'do 0 Expr)
       (CONS 'PROGN (MAPCAR #'(LAMBDA (X) (shen-cl.kl->lisp Locals X)) (shen-cl.flatten-dos Expr))))

      ; Rebuild cond, optimizing for true/false conditions, raising error if no condition is true
      ((shen-cl.form? 'cond 0 Expr)
       (CONS 'COND (shen-cl.build-cond Locals (CDR Expr))))

      ; Build defun
      ; TODO: consider SUBST of shen-cl.rename here, too
      ((shen-cl.form? 'defun 4 Expr)
       (LIST
        'DEFUN
        (CADR Expr)
        (CADDR Expr)
        (shen-cl.kl->lisp (CADDR Expr) (CADDDR Expr))))

      ; Function application
      (T
       (LET ((Args (MAPCAR #'(LAMBDA (Y) (shen-cl.kl->lisp Locals Y)) (CDR Expr))))
        (shen-cl.optimise-application
          (COND

            ; Application of function in local variable
            ((CONSP (MEMBER (CAR Expr) Locals))
             (LIST 'shen-cl.apply (CAR Expr) (CONS 'LIST Args)))

            ; Application of function result of expression
            ((CONSP (CAR Expr))
             (LIST 'shen-cl.apply (shen-cl.kl->lisp Locals (CAR Expr)) (CONS 'LIST Args)))

            ; Application of partial applied function
            ((shen-cl.true? (shen-cl.partial-application? (CAR Expr) Args))
             (shen-cl.partially-apply (CAR Expr) Args))

            ; Application of global function
            (T
             (CONS (shen-cl.maplispsym (CAR Expr)) Args))))))))

    ; Pass through anything else
    (T
     Expr)))

(DEFUN shen-cl.form? (Id Size Expr)
  (AND
    (CONSP Expr)
    (OR (= 0 Size) (EQ Size (LIST-LENGTH Expr)))
    (EQ Id (CAR Expr))))

(DEFUN shen-cl.rename (X)
  (IF (EQ T X) 'T1957 X))

(DEFUN shen-cl.flatten-dos (Expr)
  (IF (shen-cl.form? 'do 0 Expr)
    (MAPCAN #'shen-cl.flatten-dos (CDR Expr))
    (LIST Expr)))

(DEFUN shen-cl.flatten-lets (Expr)
  (IF (shen-cl.form? 'let 4 Expr)
    (LET ((R (shen-cl.flatten-lets (CADDDR Expr))))
      (CONS
        (CONS (LIST (shen-cl.rename (CADR Expr)) (CADDR Expr)) (CAR R))
        (CDR R)))
    (CONS
      ()
      Expr)))

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
  (IF (CONSP Expr)
    (COND

      ; hd -> CAR
      ((shen-cl.form? 'hd 2 Expr)
       (LIST 'CAR (shen-cl.optimise-application (CADR Expr))))

      ; tl -> CDR
      ((shen-cl.form? 'tl 2 Expr)
       (LIST 'CDR (shen-cl.optimise-application (CADR Expr))))

      ; cons -> CONS
      ((shen-cl.form? 'cons 3 Expr)
       (LIST 'CONS (shen-cl.optimise-application (CADR Expr)) (shen-cl.optimise-application (CADDR Expr))))

      ; append -> APPEND
      ((shen-cl.form? 'append 3 Expr)
       (LIST 'APPEND (shen-cl.optimise-application (CADR Expr)) (shen-cl.optimise-application (CADDR Expr))))

      ; reverse -> REVERSE
      ((shen-cl.form? 'reverse 2 Expr)
       (LIST 'REVERSE (shen-cl.optimise-application (CADR Expr))))

      ; if -> IF
      ((shen-cl.form? 'if 4 Expr)
       (LIST 'IF (shen-cl.wrap (CADR Expr)) (shen-cl.optimise-application (CADDR Expr)) (shen-cl.optimise-application (CADDDR Expr))))

      ; (value (QUOTE X)) -> X
      ((AND
        (shen-cl.form? 'value 2 Expr)
        (shen-cl.form? 'QUOTE 2 (CADR Expr)))
       (CADADR Expr))

      ; (+ 1 X) -> (1+ X)
      ((AND
        (shen-cl.form? '+ 3 Expr)
        (shen-cl.== 1 (CADR Expr)))
       (LIST (intern "1+") (shen-cl.optimise-application (CADDR Expr))))

      ; (+ X 1) -> (1+ X)
      ((AND
        (shen-cl.form? '+ 3 Expr)
        (shen-cl.== 1 (CADDR Expr)))
       (LIST (intern "1+") (shen-cl.optimise-application (CADR Expr))))

      ; (- X 1) -> (1- X)
      ((AND
        (shen-cl.form? '- 3 Expr)
        (shen-cl.== 1 (CADDR Expr)))
       (LIST (intern "1-") (shen-cl.optimise-application (CADR Expr))))

      ; Otherwise, optimize every sub-expression
      (T
       (MAPCAR 'shen-cl.optimise-application Expr)))

    ; Pass through anything else
    Expr))

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

(DEFUN shen-cl.let-bindings (Locals Bindings)
  (IF (CONSP Bindings)
    (LET ((Renamed (shen-cl.rename (CAAR Bindings))))
      (CONS
        (LIST Renamed (shen-cl.kl->lisp Locals (CADAR Bindings)))
        (shen-cl.let-bindings (CONS Renamed Locals) (CDR Bindings))))
    ()))

(DEFUN shen-cl.build-cond (Locals Clauses)
  (IF (CONSP Clauses)
    (IF (EQ 2 (LIST-LENGTH (CAR Clauses)))
      (LET ((Test   (CAAR Clauses))
            (Result (CADAR Clauses)))
        (COND
          ((EQ 'true Test)
           (LIST (LIST 'T (shen-cl.kl->lisp Locals Result))))
          ((EQ 'false Test)
           (shen-cl.build-cond Locals Clauses))
          (T
           (CONS
            (LIST (shen-cl.lisp-test Locals Test) (shen-cl.kl->lisp Locals Result))
            (shen-cl.build-cond Locals (CDR Clauses))))))
      (shen.f_error 'shen-cl.build-cond))
    (LIST (LIST 'T '(simple-error "No condition was true")))))

(DEFUN shen-cl.lisp-test (Locals Expr)
  (COND
    ((EQ 'true Expr)
     'T)
    ((AND (CONSP Expr) (EQ 'and (CAR Expr)))
     (CONS
      'AND
      (MAPCAR #'(LAMBDA (X) (shen-cl.wrap (shen-cl.kl->lisp Locals X))) (CDR Expr))))
    (T
     (shen-cl.wrap (shen-cl.kl->lisp Locals Expr)))))

(DEFUN shen-cl.wrap (Expr)
  (COND

    ; cons? -> CONSP
    ((shen-cl.form? 'cons? 2 Expr)
     (CONS 'CONSP (CDR Expr)))

    ; string? -> STRINGP
    ((shen-cl.form? 'string? 2 Expr)
     (CONS 'STRINGP (CDR Expr)))

    ; number? -> NUMBERP
    ((shen-cl.form? 'number? 2 Expr)
     (CONS 'NUMBERP (CDR Expr)))

    ; empty? -> NULL
    ((shen-cl.form? 'empty? 2 Expr)
     (CONS 'NULL (CDR Expr)))

    ; and -> AND
    ((shen-cl.form? 'and 3 Expr)
     (LIST 'AND (shen-cl.wrap (CADR Expr)) (shen-cl.wrap (CADDR Expr))))

    ; or -> OR
    ((shen-cl.form? 'or 3 Expr)
     (LIST 'OR (shen-cl.wrap (CADR Expr)) (shen-cl.wrap (CADDR Expr))))

    ; not -> NOT
    ((shen-cl.form? 'not 2 Expr)
     (LIST 'NOT (shen-cl.wrap (CADR Expr))))

    ; (shen-cl.= X ()) -> (NULL X)
    ((AND
      (shen-cl.form? 'shen-cl.= 3 Expr)
      (NULL (CADDR Expr)))
     (LIST 'NULL (CADR Expr)))
    ((AND
      (shen-cl.form? 'shen-cl.= 3 Expr)
      (NULL (CADR Expr)))
     (CONS 'NULL (CDDR Expr)))

    ; (shen-cl.= X (QUOTE Y)) -> (EQ X (QUOTE Y))
    ; (shen-cl.= X (fail)) -> (EQ X (fail))
    ((AND
      (shen-cl.form? 'shen-cl.= 3 Expr)
      (OR
        (AND
          (shen-cl.form? 'QUOTE 2 (CADDR Expr))
          (EQ 'T (SYMBOLP (CAR (CDADDR Expr)))))
        (AND
          (shen-cl.form? 'QUOTE 2 (CADR Expr))
          (EQ 'T (SYMBOLP (CADADR Expr))))
        (shen-cl.form? 'fail 1 (CADDR Expr))
        (shen-cl.form? 'fail 1 (CADR Expr))))
     (CONS 'EQ (CDR Expr)))

    ; (shen-cl.= X String) -> (EQUAL X String)
    ((AND
      (shen-cl.form? 'shen-cl.= 3 Expr)
      (OR
        (STRINGP (CADR Expr))
        (STRINGP (CADDR Expr))))
     (CONS 'EQUAL (CDR Expr)))

    ; (shen-cl.= X Number) -> (IF (NUMBERP X) (= X Number))
    ((AND
      (shen-cl.form? 'shen-cl.= 3 Expr)
      (NUMBERP (CADDR Expr)))
     (LIST 'IF (LIST 'NUMBERP (CADR Expr)) (CONS '= (CDR Expr))))
    ((AND
      (shen-cl.form? 'shen-cl.= 3 Expr)
      (NUMBERP (CADR Expr)))
     (LIST 'IF (CONS 'NUMBERP (CDDR Expr)) (LIST '= (CADDR Expr) (CADR Expr))))

    ; shen-cl.= -> shen-cl.==
    ((shen-cl.form? 'shen-cl.= 3 Expr)
     (CONS 'shen-cl.== (CDR Expr)))

    ; shen-cl.> -> >
    ((shen-cl.form? 'shen-cl.> 3 Expr)
     (CONS '> (CDR Expr)))

    ; shen-cl.>= -> >=
    ((shen-cl.form? 'shen-cl.>= 3 Expr)
     (CONS '>= (CDR Expr)))

    ; shen-cl.< -> <
    ((shen-cl.form? 'shen-cl.< 3 Expr)
     (CONS '< (CDR Expr)))

    ; shen-cl.<= -> <=
    ((shen-cl.form? 'shen-cl.<= 3 Expr)
     (CONS '<= (CDR Expr)))

    ; Otherwise, convert from Shen bool to Lisp bool with shen-cl.true?
    (T
     (LIST 'shen-cl.true? Expr))))

(DEFUN shen-cl.true? (X)
  (COND
    ((EQ 'true  X) 'T)
    ((EQ 'false X) ())
    (T (simple-error (cn "boolean expected: not ~A~%" X)))))

(DEFUN shen-cl.maplispsym (S)
  (COND
    ((EQ S '=)  'shen-cl.=)
    ((EQ S '>)  'shen-cl.>)
    ((EQ S '<)  'shen-cl.<)
    ((EQ S '>=) 'shen-cl.>=)
    ((EQ S '<=) 'shen-cl.<=)
    ((EQ S '+)  'shen-cl.+)
    ((EQ S '-)  'shen-cl.-)
    ((EQ S '/)  'shen-cl./)
    ((EQ S '*)  'shen-cl.*)
    (T          S)))
