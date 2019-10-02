\*

Copyright (c) 2010-2015, Mark Tarver

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
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*\

(package shen [shen-cl.lisp-function-name shen-cl.prefix? shen-cl.true? shen-cl.lisp-bool]

(define kl-to-lisp
  Params Param -> Param    where (cons? (lisp.member Param Params))
  Params [type X _] -> (kl-to-lisp Params X)
  Params [lambda X Y]
  -> (let ChX (ch-T X)
       (protect [FUNCTION [LAMBDA [ChX] (kl-to-lisp [ChX | Params] (lisp.subst ChX X Y))]]))
  Params [let X Y Z] -> (let ChX (ch-T X)
                          (protect [LET [[ChX (kl-to-lisp Params Y)]]
                                        (kl-to-lisp [ChX | Params] (lisp.subst ChX X Z))]))
  _ [defun F Params Code] -> (protect [DEFUN F Params (kl-to-lisp Params Code)])
  Params [cond | Cond] -> (protect [COND | (lisp.mapcar (/. C (cond_code Params C)) Cond)])
  _ [lisp. Code | More] -> (if (and (string? Code) (empty? More))
                             (lisp.read-from-string Code)
                             (simple-error "Argument to lisp. must be a literal string"))
  Params [F | X] -> (let Arguments (lisp.mapcar (/. Y (kl-to-lisp Params Y)) X)
                      (optimise-application
                       (cases (cons? (lisp.member F Params))
                              [apply F [(protect LIST) | Arguments]]
                              (cons? F) [apply (kl-to-lisp Params F)
                                               [(protect LIST) | Arguments]]
                              (partial-application? F Arguments)
                              (partially-apply F Arguments)
                              true [(maplispsym F) | Arguments])))
  _ [] -> []
  _ S -> (protect [QUOTE S])  where (protect (= (SYMBOLP S) T))
  _ X -> X)

(define ch-T
  X -> (protect T1957)	where (= (protect T) X)
  X -> X)

(define apply
  F Arguments -> (let FSym (maplispsym F)
                   (trap-error (apply-help FSym Arguments)
                               (/. E (analyse-application F FSym Arguments (error-to-string E))))))

(define apply-help
  FSym [] -> (lisp.funcall FSym)
  FSym [Argument] -> (lisp.funcall FSym Argument)
  FSym [Argument | Arguments] -> (apply-help (lisp.funcall FSym Argument) Arguments))

\\ Very slow if higher-order partial application is used; but accurate.
(define analyse-application
  F FSym Arguments Err
  -> (let Lambda (cases (partial-application? F Arguments) (build-up-lambda-expression FSym F)
                        (lazyboolop? F) (build-up-lambda-expression FSym F)
                        true (simple-error Err))
       (curried-apply Lambda Arguments)))

(define build-up-lambda-expression
  FSym F -> (lisp.eval (mk-lambda FSym (arity F))))

(define lazyboolop?
  and -> true
  or -> true
  _ -> false)

(define curried-apply
  F [X] -> (lisp.funcall F X)
  F [X | Y] -> (curried-apply (lisp.funcall F X) Y)
  F _ -> (error "cannot apply ~A~%" F))

(define partial-application?
  F Arguments -> (let Arity (trap-error (arity F) (/. E -1))
                   (cases (= Arity -1) false
                          (= Arity (length Arguments)) false
                          (> (length Arguments) Arity) false
                          true true)))

(define partially-apply
  F Arguments -> (let Arity (arity F)
                      Lambda (mk-lambda [(maplispsym F)] Arity)
                   (build-partial-application Lambda Arguments)))

(define optimise-application
  [hd X] -> (protect [CAR (optimise-application X)])
  [tl X] -> (protect [CDR (optimise-application X)])
  [cons X Y] -> (protect [CONS (optimise-application X) (optimise-application Y)])
  [append X Y] -> (protect [APPEND (optimise-application X) (optimise-application Y)])
  [reverse X] -> (protect [REVERSE (optimise-application X)])
  [if P Q R] -> (protect [IF (wrap P) (optimise-application Q) (optimise-application R)])
  [value [Quote X]] -> X  	       where (= Quote (protect QUOTE))
  [+ 1 X] -> [(intern "1+") (optimise-application X)]
  [+ X 1] -> [(intern "1+") (optimise-application X)]
  [- X 1] -> [(intern "1-") (optimise-application X)]
  [X | Y] -> (lisp.mapcar (/. App (optimise-application App)) [X | Y])
  X -> X)

(define mk-lambda
  F 0 -> F
  F N -> (let X (gensym (protect V))
           [lambda X (mk-lambda (endcons F X) (- N 1))]))

(define endcons
  [F | Y] X -> (append [F | Y] [X])
  F X -> [F X])

(define build-partial-application
  F [] -> F
  F [Argument | Arguments]
  -> (build-partial-application [(protect FUNCALL) F Argument] Arguments))

(define cond_code
  Params [Test Result] -> [(lisp_test Params Test)
                           (kl-to-lisp Params Result)])

(define lisp_test
  _ true -> (protect T)
  Params [and | Tests]
  -> [(protect AND) | (lisp.mapcar (/. X (wrap (kl-to-lisp Params X))) Tests)]
  Params Test -> (wrap (kl-to-lisp Params Test)))

(define wrap
  [cons? X] -> [(protect CONSP) X]
  [string? X] -> [(protect STRINGP) X]
  [number? X] -> [(protect NUMBERP) X]
  [empty? X] -> [(protect NULL) X]
  [and P Q] -> [(protect AND) (wrap P) (wrap Q)]
  [or P Q] -> [(protect OR) (wrap P) (wrap Q)]
  [not P] -> [(protect NOT) (wrap P)]
  [equal? X []] -> [(protect NULL) X]
  [equal? [] X] -> [(protect NULL) X]
  [equal? X [Quote Y]] -> [(protect EQ) X [Quote Y]]
      where (and (= ((protect SYMBOLP) Y) (protect T))
                 (= Quote (protect QUOTE)))
  [equal? [Quote Y] X] -> [(protect EQ) [Quote Y] X]
        where (and (= ((protect SYMBOLP) Y) (protect T))
                   (= Quote (protect QUOTE)))
  [equal? [fail] X] -> [(protect EQ) [fail] X]
  [equal? X [fail]] -> [(protect EQ) X [fail]]
  [equal? S X] -> [(protect EQUAL) S X]  where (string? S)
  [equal? X S] -> [(protect EQUAL) X S]  where (string? S)
  [equal? X N] -> [(protect EQL) X N]    where (number? N)
  [equal? N X] -> [(protect EQL) X N]    where (number? N)
  [equal? X Y] -> [shen.absequal X Y]
  [greater? X Y] -> [> X Y]
  [greater-than-or-equal-to? X Y] -> [>= X Y]
  [less? X Y] -> [< X Y]
  [less-than-or-equal-to? X Y] -> [<= X Y]
  X -> [shen-cl.true? X])

(define lisp-prefixed?
  [] -> false
  Sym -> (shen-cl.lisp-bool (shen-cl.prefix? (str Sym) "lisp."))
      where (shen-cl.lisp-bool (lisp.symbolp Sym))
  _ -> false)

(define maplispsym
  = -> equal?
  > -> greater?
  < -> less?
  >= -> greater-than-or-equal-to?
  <= -> less-than-or-equal-to?
  + -> add
  - -> subtract
  / -> divide
  * -> multiply
  F -> (shen-cl.lisp-function-name F) where (lisp-prefixed? F)
  F -> F)

)