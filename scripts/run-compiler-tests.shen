\* Copyright (c) 2012-2019 Bruno Deferrari.  All rights reserved.    *\
\* BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause *\

(define subst-vars
  X X -> X

  [lambda X Body] [lambda Y RBody]
  -> [lambda X (subst X Y (subst-vars Body RBody))]

  [let [[X V]] Body] [let [[Y RV]] RBody]
  -> [let [[X (subst-vars V RV)]] (subst X Y (subst-vars Body RBody))]

  [X | Xs] [Y | Ys]
  -> [(subst-vars X Y) | (subst-vars Xs Ys)]

  _ Y -> Y)

(define assert-equal-h
  Exp X X -> (pr (make-string "[OK]    ~A = ~R ~%" Exp X))
  Exp X Y -> (pr (make-string "[ERROR] ~A = ~R ~%  got ~R~%" Exp Y X)))

(define assert-equal
  Exp X Y -> (assert-equal-h Exp X (subst-vars X Y)))

(define eval-cons
  [cons A B] -> (cons (eval-cons A) (eval-cons B))
  [X | Rest] -> [(eval-cons X) | (eval-cons Rest)]
  X -> X)

(defmacro assert-equal-macro
  [assert-equal Exp Result] ->
    [assert-equal (make-string "~R" (eval-cons Exp)) Exp Result])

(set *hush* true)

(load "src/compiler.shen")
(load "tests/compiler-tests.shen")
