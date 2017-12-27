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

(DEFUN shen-cl.kl->lisp (locals expr)
  (COND

    ; Retain empty lists and local variables
    ((NULL expr)
     ())
    ((AND (SYMBOLP expr) (MEMBER expr locals))
     (shen-cl.rename expr))

    ; Quote idle symbols
    ((SYMBOLP expr)
     (LIST 'QUOTE expr))

    ; Handle special forms, function applications
    ((CONSP expr)
     (COND

      ; Ignore type expressions
      ((shen-cl.form? 'type 3 expr)
       (shen-cl.kl->lisp locals (CADR expr)))

      ; TODO: factor out trivial lambdas:
      ;       (lambda X (f X)) -> (FUNCTION f)
      ;       where f is not a variable

      ; Build lambda, escaping param with shen-cl.rename
      ((shen-cl.form? 'lambda 3 expr)
       (LIST 'FUNCTION
        (LIST 'LAMBDA
          (LIST (shen-cl.rename (CADR expr)))
          (shen-cl.kl->lisp (CONS (CADR expr) locals) (CADDR expr)))))

      ; Flatten nested let's into single LET*
      ((shen-cl.form? 'let 4 expr)
       (LET* ((lets (shen-cl.flatten-lets expr)))
        (LIST 'LET*
          (shen-cl.let-bindings locals (CAR lets))
          (shen-cl.kl->lisp (APPEND (MAPCAR #'CAR (CAR lets)) locals) (CDR lets)))))

      ; Flatten nested do's into single PROGN
      ((shen-cl.form? 'do 0 expr)
       (CONS 'PROGN
        (MAPCAR #'(LAMBDA (X) (shen-cl.kl->lisp locals X)) (shen-cl.flatten-dos expr))))

      ; Rebuild cond, optimizing for true/false conditions, raising error if no condition is true
      ((shen-cl.form? 'cond 0 expr)
       (CONS 'COND
        (shen-cl.build-cond locals (CDR expr))))

      ; Build defun
      ((shen-cl.form? 'defun 4 expr)
       (LIST 'DEFUN
        (CADR expr)
        (MAPCAR #'shen-cl.rename (CADDR expr))
        (shen-cl.kl->lisp (CADDR expr) (CADDDR expr))))

      ; Function application
      (T
       (LET ((args (MAPCAR #'(LAMBDA (Y) (shen-cl.kl->lisp locals Y)) (CDR expr))))
        (shen-cl.optimise-application
          (COND

            ; Application of function in local variable
            ((CONSP (MEMBER (CAR expr) locals))
             (LIST 'shen-cl.apply
              (CAR expr)
              (CONS 'LIST args)))

            ; Application of function result of expression
            ((CONSP (CAR expr))
             (LIST 'shen-cl.apply
              (shen-cl.kl->lisp locals (CAR expr))
              (CONS 'LIST args)))

            ; Application of partial applied function
            ((shen-cl.partial-application? (CAR expr) args)
             (shen-cl.partially-apply (CAR expr) args))

            ; Application of global function
            (T
             (CONS (shen-cl.map-operator (CAR expr)) args))))))))

    ; Pass through anything else
    (T
     expr)))

(DEFUN shen-cl.form? (id size expr)
  (AND
    (CONSP expr)
    (OR (= 0 size) (EQ size (LIST-LENGTH expr)))
    (EQ id (CAR expr))))

(DEFUN shen-cl.rename (x)
  (IF (EQ 'T x) 'T1957 x))

(DEFUN shen-cl.flatten-dos (expr)
  (IF (shen-cl.form? 'do 0 expr)
    (MAPCAN #'shen-cl.flatten-dos (CDR expr))
    (LIST expr)))

(DEFUN shen-cl.flatten-lets (expr)
  (IF (shen-cl.form? 'let 4 expr)
    (LET ((lets    (shen-cl.flatten-lets (CADDDR expr)))
          (binding (LIST (CADR expr) (CADDR expr))))
      (CONS (CONS binding (CAR lets)) (CDR lets)))
    (CONS () expr)))

(DEFUN shen-cl.apply (fn args)
  (LET ((mapped-fn (shen-cl.map-operator fn)))
    (trap-error
      (shen-cl.apply-help mapped-fn args)
      #'(LAMBDA (e) (shen-cl.analyse-application fn mapped-fn args (error-to-string e))))))

(DEFUN shen-cl.apply-help (fn args)
  (COND
    ((NULL args)
     (FUNCALL fn))
    ((AND (CONSP args) (NULL (CDR args)))
     (FUNCALL fn (CAR args)))
    ((CONSP args)
     (shen-cl.apply-help (FUNCALL fn (CAR args)) (CDR args)))
    (T
     (shen.f_error 'shen-cl.apply-help))))

(DEFUN shen-cl.analyse-application (fn mapped-fn args message)
  (IF (OR (shen-cl.partial-application? fn args) (shen-cl.lazyboolop? fn))
    (shen-cl.curried-apply (shen-cl.build-up-lambda-expression mapped-fn fn) args)
    (simple-error message)))

(DEFUN shen-cl.build-up-lambda-expression (mapped-fn fn)
  (EVAL (shen-cl.mk-lambda mapped-fn (arity fn))))

(DEFUN shen-cl.lazyboolop? (op)
  (OR (EQ op 'and) (EQ op 'or)))

(DEFUN shen-cl.curried-apply (fn args)
  (IF (CONSP args)
    (LET ((app (FUNCALL fn (CAR args))))
      (IF (NULL (CDR args))
        app
        (shen-cl.curried-apply app (CDR args))))
    (simple-error (cn "cannot apply " (shen-cl.app fn (FORMAT NIL "~%") 'shen-cl.a)))))

(DEFUN shen-cl.partial-application? (fn args)
  (LET ((ar (trap-error (arity fn) #'(LAMBDA (E) -1))))
    (NOT (OR (= ar -1) (>= (LIST-LENGTH args) ar)))))

(DEFUN shen-cl.partially-apply (fn args)
  (shen-cl.build-partial-application
    (shen-cl.mk-lambda (LIST (shen-cl.map-operator fn)) (arity fn))
    args))

(DEFUN shen-cl.optimise-application (expr)
  (IF (CONSP expr)
    (COND

      ; cons -> CONS
      ((shen-cl.form? 'cons 3 expr)
       (LIST 'CONS
        (shen-cl.optimise-application (CADR expr))
        (shen-cl.optimise-application (CADDR expr))))

      ; append -> APPEND
      ((shen-cl.form? 'append 3 expr)
       (LIST 'APPEND
        (shen-cl.optimise-application (CADR expr))
        (shen-cl.optimise-application (CADDR expr))))

      ; reverse -> REVERSE
      ((shen-cl.form? 'reverse 2 expr)
       (LIST 'REVERSE (shen-cl.optimise-application (CADR expr))))

      ; if -> IF
      ((shen-cl.form? 'if 4 expr)
       (LIST 'IF
        (shen-cl.optimise-conditional (CADR expr))
        (shen-cl.optimise-application (CADDR expr))
        (shen-cl.optimise-application (CADDDR expr))))

      ; (value (QUOTE X)) -> X
      ((AND
        (shen-cl.form? 'value 2 expr)
        (shen-cl.form? 'QUOTE 2 (CADR expr)))
       (CADADR expr))

      ; (+ 1 X) -> (1+ X)
      ((AND
        (shen-cl.form? '+ 3 expr)
        (shen-cl.== 1 (CADR expr)))
       (LIST (intern "1+") (shen-cl.optimise-application (CADDR expr))))

      ; (+ X 1) -> (1+ X)
      ((AND
        (shen-cl.form? '+ 3 expr)
        (shen-cl.== 1 (CADDR expr)))
       (LIST (intern "1+") (shen-cl.optimise-application (CADR expr))))

      ; (- X 1) -> (1- X)
      ((AND
        (shen-cl.form? '- 3 expr)
        (shen-cl.== 1 (CADDR expr)))
       (LIST (intern "1-") (shen-cl.optimise-application (CADR expr))))

      ; Otherwise, optimize every sub-expression
      (T
       (MAPCAR 'shen-cl.optimise-application expr)))

    ; Pass through anything else
    expr))

(DEFUN shen-cl.mk-lambda (f ar)
  (IF (shen-cl.== 0 ar)
    f
    (LET ((v (GENSYM)))
      (LIST 'lambda v (shen-cl.mk-lambda (shen-cl.endcons f v) (1- ar))))))

(DEFUN shen-cl.endcons (fn x)
  (IF (CONSP fn)
    (APPEND fn (LIST x))
    (LIST fn x)))

(DEFUN shen-cl.build-partial-application (fn args)
  (COND
    ((NULL args)  fn)
    ((CONSP args) (shen-cl.build-partial-application (LIST 'FUNCALL fn (CAR args)) (CDR args)))
    (T            (shen.f_error 'shen-cl.build-partial-application))))

(DEFUN shen-cl.let-bindings (locals bindings)
  (IF (CONSP bindings)
    (LET ((name (CAAR bindings)))
      (CONS
        (LIST (shen-cl.rename name) (shen-cl.kl->lisp locals (CADAR bindings)))
        (shen-cl.let-bindings (CONS name locals) (CDR bindings))))
    ()))

(DEFUN shen-cl.build-cond (locals clauses)
  (IF (CONSP clauses)
    (IF (EQ 2 (LIST-LENGTH (CAR clauses)))
      (LET ((condition (CAAR clauses))
            (body      (CADAR clauses)))
        (COND
          ((EQ 'true condition)
           (LIST (LIST 'T (shen-cl.kl->lisp locals body))))
          ((EQ 'false condition)
           (shen-cl.build-cond locals clauses))
          (T
           (CONS
            (LIST (shen-cl.conditional locals condition) (shen-cl.kl->lisp locals body))
            (shen-cl.build-cond locals (CDR clauses))))))
      (shen.f_error 'shen-cl.build-cond))
    (LIST (LIST 'T '(simple-error "No condition was true")))))

(DEFUN shen-cl.conditional (locals expr)
  (COND
    ((EQ 'true expr)
     'T)
    ((EQ 'false expr)
     'NIL)
    ((AND (CONSP expr) (shen-cl.lazyboolop? (CAR expr)))
     (CONS
      (INTERN (STRING-UPCASE (SYMBOL-NAME (CAR expr))))
      (MAPCAR #'(LAMBDA (X) (shen-cl.optimise-conditional (shen-cl.kl->lisp locals X))) (CDR expr))))
    (T
     (shen-cl.optimise-conditional (shen-cl.kl->lisp locals expr)))))

(DEFUN shen-cl.optimise-conditional (expr)
  (COND

    ; cons? -> CONSP
    ((shen-cl.form? 'cons? 2 expr)
     (CONS 'CONSP (CDR expr)))

    ; string? -> STRINGP
    ((shen-cl.form? 'string? 2 expr)
     (CONS 'STRINGP (CDR expr)))

    ; number? -> NUMBERP
    ((shen-cl.form? 'number? 2 expr)
     (CONS 'NUMBERP (CDR expr)))

    ; empty? -> NULL
    ((shen-cl.form? 'empty? 2 expr)
     (CONS 'NULL (CDR expr)))

    ; and -> AND
    ((shen-cl.form? 'and 3 expr)
     (LIST 'AND
      (shen-cl.optimise-conditional (CADR expr))
      (shen-cl.optimise-conditional (CADDR expr))))

    ; or -> OR
    ((shen-cl.form? 'or 3 expr)
     (LIST 'OR
      (shen-cl.optimise-conditional (CADR expr))
      (shen-cl.optimise-conditional (CADDR expr))))

    ; not -> NOT
    ((shen-cl.form? 'not 2 expr)
     (LIST 'NOT (shen-cl.optimise-conditional (CADR expr))))

    ; (shen-cl.= X ()) -> (NULL X)
    ((AND
      (shen-cl.form? 'shen-cl.= 3 expr)
      (NULL (CADDR expr)))
     (LIST 'NULL (CADR expr)))
    ((AND
      (shen-cl.form? 'shen-cl.= 3 expr)
      (NULL (CADR expr)))
     (CONS 'NULL (CDDR expr)))

    ; (shen-cl.= X (QUOTE Y)) -> (EQ X (QUOTE Y))
    ; (shen-cl.= X (fail)) -> (EQ X (fail))
    ((AND
      (shen-cl.form? 'shen-cl.= 3 expr)
      (OR
        (AND
          (shen-cl.form? 'QUOTE 2 (CADDR expr))
          (EQ 'T (SYMBOLP (CAR (CDADDR expr)))))
        (AND
          (shen-cl.form? 'QUOTE 2 (CADR expr))
          (EQ 'T (SYMBOLP (CADADR expr))))
        (shen-cl.form? 'fail 1 (CADDR expr))
        (shen-cl.form? 'fail 1 (CADR expr))))
     (CONS 'EQ (CDR expr)))

    ; (shen-cl.= X String) -> (EQUAL X String)
    ((AND
      (shen-cl.form? 'shen-cl.= 3 expr)
      (OR
        (STRINGP (CADR expr))
        (STRINGP (CADDR expr))))
     (CONS 'EQUAL (CDR expr)))

    ; (shen-cl.= X Number) -> (IF (NUMBERP X) (= X Number))
    ((AND
      (shen-cl.form? 'shen-cl.= 3 expr)
      (NUMBERP (CADDR expr)))
     (LIST 'IF (LIST 'NUMBERP (CADR expr)) (CONS '= (CDR expr))))
    ((AND
      (shen-cl.form? 'shen-cl.= 3 expr)
      (NUMBERP (CADR expr)))
     (LIST 'IF (CONS 'NUMBERP (CDDR expr)) (CONS '= (CDR expr))))

    ; shen-cl.= -> shen-cl.==
    ((shen-cl.form? 'shen-cl.= 3 expr)
     (CONS 'shen-cl.== (CDR expr)))

    ; shen-cl.> -> >
    ((shen-cl.form? 'shen-cl.> 3 expr)
     (CONS '> (CDR expr)))

    ; shen-cl.>= -> >=
    ((shen-cl.form? 'shen-cl.>= 3 expr)
     (CONS '>= (CDR expr)))

    ; shen-cl.< -> <
    ((shen-cl.form? 'shen-cl.< 3 expr)
     (CONS '< (CDR expr)))

    ; shen-cl.<= -> <=
    ((shen-cl.form? 'shen-cl.<= 3 expr)
     (CONS '<= (CDR expr)))

    ; Otherwise, inject conversion from Shen bool to Lisp bool with shen-cl.true?
    (T
     (LIST 'shen-cl.true? expr))))

(DEFUN shen-cl.map-operator (s)
  (COND
    ((EQ s '=)  'shen-cl.=)
    ((EQ s '>)  'shen-cl.>)
    ((EQ s '<)  'shen-cl.<)
    ((EQ s '>=) 'shen-cl.>=)
    ((EQ s '<=) 'shen-cl.<=)
    ((EQ s '+)  'shen-cl.+)
    ((EQ s '-)  'shen-cl.-)
    ((EQ s '/)  'shen-cl./)
    ((EQ s '*)  'shen-cl.*)
    (T          s)))
