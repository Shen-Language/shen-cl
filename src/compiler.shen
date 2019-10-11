\\ Copyright (c) 2012-2019 Bruno Deferrari.  All rights reserved.
\\ BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause

(package shen-cl [progn quote null car cdr t nil
                  numberp stringp consp funcall
                  list eq eql equal let*
                  lisp.defun lisp.lambda lisp.
                  %%return return %%goto-label go
                  %%let-label block tagbody]

(define initialise-compiler
  -> (do (set *compiling-shen-sources* false)
         (set *factorise-patterns* true)
         done))

(define kl Sym -> Sym)

\\ Overriden in overwrite.lsp for performance
(define cl Sym -> (intern (upcase Sym)))

(define unbound-symbol?
  Sym Scope -> (not (element? Sym Scope)) where (or (symbol? Sym) (= Sym ,))
  _ _ -> false)

(define merge-nested-repeats
  Op [Op Exp1 [Op | Exps]] -> [Op Exp1 | Exps]
  _ X -> X)

(define merge-nested-lets
  [Let [Binding] [Let* Bindings Body]] -> [Let* [Binding | Bindings] Body]
      where (and (= (cl let) Let)
                 (= (cl let*) Let*))
  [Let [Binding1] [Let [Binding2] Body]] -> [(cl let*) [Binding1 Binding2] Body]
      where (= (cl let) Let)
  X -> X)

(define compile-expression
  [] _ -> [(cl quote) []]
  true Scope -> [(cl quote) true]
  false Scope -> [(cl quote) false]
  Sym Scope -> (emit-symbol Sym) where (unbound-symbol? Sym Scope)
  [value Sym] Scope -> Sym where (unbound-symbol? Sym Scope)
  [let Var Value Body] Scope -> (merge-nested-lets
                                 (emit-let Var Value Body Scope))
  [cond | Clauses] Scope -> (emit-cond Clauses Scope)
  [if Test Then Else] Scope -> (emit-if Test Then Else Scope)
  [lambda Var Body] Scope -> (emit-lambda Var Body Scope)
  [and E1 E2] Scope -> [(kl and)
                         (compile-expression E1 Scope)
                         (compile-expression E2 Scope)]
  [or E1 E2] Scope -> [(kl or)
                        (compile-expression E1 Scope)
                        (compile-expression E2 Scope)]
  [trap-error Exp Handler] Scope -> (emit-trap-error Exp Handler Scope)
  [do E1 E2] Scope -> (merge-nested-repeats (cl progn)
                        [(cl progn)
                          (compile-expression E1 Scope)
                          (compile-expression E2 Scope)])
  [= A B] Scope -> (emit-equality-check A B Scope)
  [intern S] _ -> [(cl quote) (intern S)] where (string? S)
  [type Exp _] Scope -> (compile-expression Exp Scope)
  [lisp.lambda Vars Body] Scope -> [(cl lambda) Vars (compile-expression Body (append Vars Scope))]
  [lisp.defun Name Vars Body] _ -> [(cl defun) Name Vars (compile-expression Body Vars)]
  [lisp.block Name Body] Scope -> [(cl block) Name (compile-expression Body Scope)]
  [lisp. Code] _ -> (if (string? Code)
                        ((protect READ-FROM-STRING) Code)
                        (error "lisp. excepts a string, not ~A" Code))
  [%%return Exp] Scope -> [(cl return) (compile-expression Exp Scope)]
  [%%goto-label Label | _] Scope -> [(cl go) Label]
  [%%let-label [Label | _] LabelBody Body] Scope -> [(cl tagbody) (compile-expression Body Scope)
                                                      Label (compile-expression  LabelBody Scope)]
  [Op | Args] Scope -> (emit-application Op Args Scope)
  X _ -> X                      \* literal *\
  )

(define optimize-boolean-check
  \\ TODO: let, do, etc
  [cons? X] -> [(cl consp) X]
  [string? X] -> [(cl stringp) X]
  [number? X] -> [(cl numberp) X]
  [empty? X] -> [(cl null) X]
  [and P Q] -> [(cl and) (optimize-boolean-check P) (optimize-boolean-check Q)]
  [or P Q] -> [(cl or) (optimize-boolean-check P) (optimize-boolean-check Q)]
  [not P] -> [(cl not) (optimize-boolean-check P)]
  [equal? X [Quote []]] -> [(cl null) X] where (= Quote (cl quote))
  [equal? [Quote []] X] -> [(cl null) X] where (= Quote (cl quote))
  [equal? [fail] X] -> [(cl eq) [fail] X]
  [equal? X [fail]] -> [(cl eq) X [fail]]
  [equal? S X] -> [(cl equal) S X]  where (string? S)
  [equal? X S] -> [(cl equal) X S]  where (string? S)
  [equal? X N] -> [(cl eql) X N]    where (number? N)
  [equal? N X] -> [(cl eql) X N]    where (number? N)
  [equal? X [Quote S]] -> [(cl eq) X [Quote S]]    where (= (cl quote) Quote)
  [equal? [Quote S] X] -> [(cl eq) X [Quote S]]    where (= (cl quote) Quote)
  [equal? X Y] -> [(kl absequal) X Y]
  [greater? X Y] -> [(cl > )X Y]
  [greater-than-or-equal-to? X Y] -> [(cl >=) X Y]
  [less? X Y] -> [(cl < )X Y]
  [less-than-or-equal-to? X Y] -> [(cl <=) X Y]
  [Quote true] -> (cl t) where (= Quote (cl quote))
  [Quote false] -> (cl nil) where (= Quote (cl quote))
  Exp -> [true? Exp])

(define emit-symbol
  S -> [(cl quote) S])

(define subst*
  X X Body -> Body
  X Y Body -> (subst X Y Body))

(define ch-T
  X -> (cl safe-t) where (= (protect T) X)
  X -> X)

(define emit-let
   Var Value Body Scope
   -> (let ChVar (ch-T Var)
           ChBody (subst* ChVar Var Body)
       [(cl let) [[ChVar (compile-expression Value Scope)]]
        (compile-expression ChBody [ChVar | Scope])]))

(define emit-lambda
  Var Body Scope
  -> (let ChVar (ch-T Var)
          ChBody (subst* ChVar Var Body)
      [(kl lambda) ChVar
       (compile-expression ChBody [ChVar | Scope])]))

(define emit-if
  Test Then Else Scope
  -> [(cl if) (optimize-boolean-check (compile-expression Test Scope))
              (compile-expression Then Scope)
              (compile-expression Else Scope)])

(define emit-cond
  Clauses Scope -> [(cl cond) | (emit-cond-clauses Clauses Scope)])

(define emit-cond-clauses
  [] _ -> []
  [[Test Body] | Rest] Scope
  -> (let CompiledTest (optimize-boolean-check (compile-expression Test Scope))
          CompiledBody (compile-expression Body Scope)
          CompiledRest (emit-cond-clauses Rest Scope)
       [[CompiledTest CompiledBody]
        | CompiledRest]))

(define emit-trap-error
  [F | Rest] Handler Scope <- (emit-trap-error-optimize [F | Rest] Handler Scope)
      where (and (value *compiling-shen-sources*)
                 (element? F [value <-vector <-address get]))

  Exp Handler Scope
  -> [trap-error (compile-expression Exp Scope)
                 (compile-expression Handler Scope)])

\*
NOTE: This transformation assumes that:
- the operand expressions will not raise their own exception,
- the operands are of the right type,
- the Handler doesn't make use of the error
otherwise the result is not semantically equivalent to the original code.

For this reason it is only enabled when compiling the Shen Kernel sources
but not otherwise.
*\
(define emit-trap-error-optimize
  [value X] [lambda E Handler] Scope
  -> (compile-expression [shen-cl.value/or X [freeze Handler]] Scope)
  [<-vector X N] [lambda E Handler] Scope
  -> (compile-expression [shen-cl.<-vector/or X N [freeze Handler]] Scope)
  [<-address X N] [lambda E Handler] Scope
  -> (compile-expression [shen-cl.<-address/or X N [freeze Handler]] Scope)
  [get X P D] [lambda E Handler] Scope
  -> (compile-expression [shen-cl.get/or X P D [freeze Handler]] Scope)
  _ _ _ -> (fail))

(define emit-equality-check
  V1 V2 Scope -> [(kl equal?)
                   (compile-expression V1 Scope)
                   (compile-expression V2 Scope)])

(define emit-application
  Op Params Scope -> (emit-application* Op (arity Op) Params Scope))

(define is-partial-application?
  Op Arity Params -> (not (or (= Arity -1)
                              (= Arity (length Params)))))

(define take
  _ 0 -> []
  [X | Xs] N -> [X | (take Xs (- N 1))])

(define drop
  Xs 0 -> Xs
  [X | Xs] N -> (drop Xs (- N 1)))

\* TODO: optimize cases where the args are static values *\
(define emit-partial-application
  Op Arity Params Scope
  -> (let Args (map (/. P (compile-expression P Scope)) Params)
       (nest-call (nest-lambda Op Arity Scope) Args))
    where (> Arity (length Params))
  Op Arity Params Scope
  -> (let App (compile-expression [Op | (take Params Arity)] Scope)
          Rest (map (/. X (compile-expression X Scope)) (drop Params Arity))
       (nest-call App Rest))
    where (< Arity (length Params))
  _ _ _ _ -> (error "emit-partial-application called with non-partial application"))

(define dynamic-application?
  Op Scope -> (or (cons? Op) (element? Op Scope)))

(define emit-dynamic-application
  Op [] Scope -> [(cl funcall) (compile-expression Op Scope)] \* empty case *\
  Op Params Scope
  -> (let Args (map (/. P (compile-expression P Scope)) Params)
       (nest-call (compile-expression Op Scope)
                  Args)))

(define lisp-prefixed-h?
  [($ lisp.) | _] -> true
  _ -> false)

\\ Overriden in overwrite.lsp for performance
(define lisp-prefixed?
  Sym -> (lisp-prefixed-h? (explode Sym)) where (symbol? Sym)
  _ -> false)

\\ Overriden in overwrite.lsp for performance
(define remove-lisp-prefix
  Sym -> (remove-lisp-prefix (str Sym)) where (symbol? Sym)
  (@s "lisp." Rest) -> (intern Rest))

(define upcase
  Str -> (upcase-h (explode Str)))

(define upcase-h
  [] -> ""
  [Char | Rest] -> (cn (upcase-char Char) (upcase-h Rest)))

(define upcase-char
  Char -> (n->string (upcase-charcode (string->n Char))))

(define upcase-charcode
  N -> (- N 32) where (and (>= N 97) (<= N 122))
  N -> N)

(define qualify-op
  Sym -> (cl (remove-lisp-prefix Sym)) where (lisp-prefixed? Sym)
  Sym -> (kl Sym) where (symbol? Sym)
  NotSym -> NotSym)

(define not-fail
  Obj F -> (F Obj) where (not (= Obj (fail)))
  Obj _ -> Obj)

(define binary-op-mapping
  +               -> (kl add)
  -               -> (kl subtract)
  *               -> (kl multiply)
  /               -> (kl divide)
  >               -> (kl greater?)
  <               -> (kl less?)
  >=              -> (kl greater-than-or-equal-to?)
  <=              -> (kl less-than-or-equal-to?)
  cons            -> (cl cons)
  reverse         -> (cl reverse)
  append          -> (cl append)
  _               -> (fail))

(define unary-op-mapping
  hd              -> (cl car)
  tl              -> (cl cdr)
  _               -> (fail))

(define optimise-static-application
  [+ 1 X] -> [(intern "1+") X]
  [+ X 1] -> [(intern "1+") X]
  [- X 1] -> [(intern "1-") X]
  [Cons Exp [Quote []]] -> [(cl list) Exp]
      where (and (= (cl cons) Cons)
                 (= (cl quote) Quote))
  [Cons Exp [List | Elts]] -> [List Exp | Elts]
      where (and (= (cl cons) Cons)
                 (= (cl list) List))
  Exp -> Exp)

(define emit-static-application
  Op 2 Params Scope <- (not-fail
                        (binary-op-mapping Op)
                        (/. MappedOp
                            (let Args (map (/. P (compile-expression P Scope))
                                           Params)
                              [MappedOp | Args])))
  Op 1 Params Scope <- (not-fail
                        (unary-op-mapping Op)
                        (/. MappedOp
                            (let Args (map (/. P (compile-expression P Scope))
                                           Params)
                              [MappedOp | Args])))
  Op _ Params Scope -> (let Args (map (/. P (compile-expression P Scope))
                                      Params)
                         [(qualify-op Op) | Args]))

(define emit-application*
  Op Arity Params Scope
  -> (cases
      \* Known function without all arguments *\
      (is-partial-application? Op Arity Params)
      (emit-partial-application Op Arity Params Scope)
      \* Variables or results of expressions *\
      (dynamic-application? Op Scope)
      (emit-dynamic-application Op Params Scope)
      \* Known function with all arguments *\
      true
      (optimise-static-application
       (emit-static-application Op Arity Params Scope))))

(define nest-call
  Op [] -> Op
  Op [Arg | Args] -> (nest-call [(cl funcall) Op Arg] Args))

(define nest-lambda
  Callable Arity Scope -> (compile-expression Callable Scope)
     where (<= Arity 0)

  Callable Arity Scope
  -> (let ArgName (gensym (protect Y))
       [(kl lambda) ArgName
         (nest-lambda (merge-args Callable ArgName)
                      (- Arity 1)
                      [ArgName | Scope])]))

(define merge-args
  Op Arg -> (append Op [Arg]) where (cons? Op)
  Op Arg -> [Op Arg])

(define factorise-defun
  [defun Name Args [cond | Cases]] -> (add-block
                                       (shen.x.factorise-defun.factorise-defun
                                        [defun Name Args [cond | Cases]])))

(define add-block
  [defun Name Args Body] -> [defun Name Args [lisp.block [] Body]])

(define kl->lisp
  [defun Name Args [cond | Cases]] -> (kl->lisp
                                        (factorise-defun
                                          [defun Name Args [cond | Cases]]))
      where (value *factorise-patterns*)
  [defun Name Args Body] -> [(cl defun) (qualify-op Name) Args
                              (compile-expression Body Args)]
  Exp -> (compile-expression Exp []))

)
