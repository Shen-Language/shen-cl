\* Copyright (c) 2012-2019 Bruno Deferrari.  All rights reserved.    *\
\* BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause *\

(shen-cl.initialise-compiler)

(assert-equal
 (shen-cl.optimize-boolean-check [(shen-cl.cl quote) true])
 (shen-cl.cl t))

(assert-equal
 (shen-cl.optimize-boolean-check [(shen-cl.cl quote) false])
 (shen-cl.cl nil))

(assert-equal
 (shen-cl.optimize-boolean-check [number? 1])
 [(shen-cl.cl numberp) 1])

(assert-equal
 (shen-cl.optimize-boolean-check [+ 1 2])
 [(shen-cl.kl shen-cl.true?) [+ 1 2]])

(assert-equal
 (shen-cl.optimize-boolean-check [let X 1 [number? X]])
 [(shen-cl.kl shen-cl.true?) [(shen-cl.kl let) X 1 [(shen-cl.kl number?) X]]])

(assert-equal
 (shen-cl.optimize-boolean-check [let X 1 [+ X X]])
 [(shen-cl.kl shen-cl.true?) [(shen-cl.kl let) X 1 [+ X X]]])

(assert-equal
 (shen-cl.optimize-boolean-check [(shen-cl.kl and) [(shen-cl.cl quote) true] [(shen-cl.cl quote) false]])
 [(shen-cl.cl and) (shen-cl.cl t) (shen-cl.cl nil)])

(assert-equal
 (shen-cl.prefix-op test)
 (intern "test"))

\\ compile-expression

(assert-equal
 (shen-cl.kl->lisp [])
 [(shen-cl.cl quote) []])

(assert-equal
 (shen-cl.kl->lisp true)
 [(shen-cl.cl quote) true])

(assert-equal
 (shen-cl.kl->lisp false)
 [(shen-cl.cl quote) false])

(assert-equal
 (shen-cl.kl->lisp {)
 [(shen-cl.cl quote) {])

(assert-equal
 (shen-cl.kl->lisp })
 [(shen-cl.cl quote) }])

(assert-equal
 (shen-cl.kl->lisp ;)
 [(shen-cl.cl quote) ;])

(assert-equal
 (shen-cl.kl->lisp ,)
 [(shen-cl.cl quote) ,])

(assert-equal
 (shen-cl.kl->lisp some-symbol)
 [(shen-cl.cl quote) some-symbol])

(assert-equal
 (shen-cl.kl->lisp [let A 1 [+ A A]])
 [(shen-cl.cl let) [[A 1]] [shen-cl.add A A]])

(assert-equal
 (shen-cl.kl->lisp [lambda X [= X 1]])
 [lambda X [(shen-cl.kl shen-cl.equal?) X 1]])

(assert-equal
 (shen-cl.compile-expression [and [some-func X] [= 1 2]] [X])
 [and [(shen-cl.prefix-op some-func) X] [(shen-cl.kl shen-cl.equal?) 1 2]])

(assert-equal
 (shen-cl.compile-expression [or [some-func X] [= 1 2]] [X])
 [or [(shen-cl.prefix-op some-func) X] [(shen-cl.kl shen-cl.equal?) 1 2]])

(assert-equal
 (shen-cl.kl->lisp [trap-error [+ 1 2] [lambda E 0]])
 [(shen-cl.kl trap-error) [(shen-cl.kl shen-cl.add) 1 2]
   [(shen-cl.kl lambda) E 0]])

(define default D E -> D)

(assert-equal
 (shen-cl.kl->lisp [trap-error [+ 1 2] [default 0]])
 [(shen-cl.kl trap-error) [(shen-cl.kl shen-cl.add) 1 2]
   [(shen-cl.cl funcall) [(shen-cl.kl lambda) X [(shen-cl.kl lambda) Y [(shen-cl.prefix-op default) X Y]]] 0]])

(assert-equal
 (shen-cl.kl->lisp [do 1 2])
 [(shen-cl.cl progn) 1 2])

(assert-equal
 (shen-cl.kl->lisp [freeze [print "hello"]])
 [(shen-cl.kl freeze) [(shen-cl.prefix-op print) "hello"]])

(assert-equal
 (shen-cl.kl->lisp [fail])
 [(shen-cl.prefix-op fail)])

(assert-equal
 (shen-cl.kl->lisp [blah 1 2])
 [(shen-cl.prefix-op blah) 1 2])

(assert-equal
 (shen-cl.kl->lisp 1)
 1)

(assert-equal
 (shen-cl.kl->lisp "string")
 "string")

(assert-equal
 (shen-cl.kl->lisp [defun some-name [A B C] [cons symbol [+ A B]]])
 [(shen-cl.cl defun) (shen-cl.prefix-op some-name) [A B C] [(shen-cl.cl cons) [(shen-cl.cl quote) symbol] [shen-cl.add A B]]])

(assert-equal
 (shen-cl.compile-expression [F 1 2 3] [F])
 [(shen-cl.cl funcall) [(shen-cl.cl funcall) [(shen-cl.cl funcall) F 1] 2] 3])

(assert-equal
 (shen-cl.kl->lisp [+ 1])
 [(shen-cl.cl funcall) [(shen-cl.kl lambda) Y [(shen-cl.kl lambda) Z [shen-cl.add Y Z]]] 1])

(define takes-3-args
  X Y Z -> X)

(define takes-0-args -> 0)

(assert-equal
 (shen-cl.compile-expression [takes-3-args A B] [A B])
 [(shen-cl.cl funcall) [(shen-cl.cl funcall) [(shen-cl.kl lambda) X [(shen-cl.kl lambda) Y [(shen-cl.kl lambda) Z [(shen-cl.prefix-op takes-3-args) X Y Z]]]] A] B])

(assert-equal
 (shen-cl.compile-expression [takes-3-args X Y Z symbol W] [X Y Z W])
 [(shen-cl.cl funcall) [(shen-cl.cl funcall) [(shen-cl.prefix-op takes-3-args) X Y Z] [(shen-cl.cl quote) symbol]] W])

(assert-equal
 (shen-cl.kl->lisp [takes-0-args])
 [(shen-cl.prefix-op takes-0-args)])

(assert-equal
 (shen-cl.kl->lisp [takes-0-args 1])
 [(shen-cl.cl funcall) [(shen-cl.prefix-op takes-0-args)] 1])

(assert-equal
 (shen-cl.kl->lisp [takes-?-args])
 [(shen-cl.prefix-op takes-?-args)])

(assert-equal
 (shen-cl.kl->lisp [takes-?-args 1 2 3])
 [(shen-cl.prefix-op takes-?-args) 1 2 3])

(assert-equal
 (shen-cl.kl->lisp [if [= 1 2] 1 2])
 [(shen-cl.cl if) [(shen-cl.cl eql) 1 2] 1 2])

(assert-equal
 (shen-cl.kl->lisp [cond [[= 1 2] 1] [[> 1 2] 2] [[= [] val] 0] [true 3]])
 [(shen-cl.cl cond)
     [[(shen-cl.cl eql) 1 2] 1]
     [[(shen-cl.cl >) 1 2] 2]
     [[(shen-cl.cl null) [(shen-cl.cl quote) val]] 0]
     [(shen-cl.cl t) 3]])

(set shen-cl.*compiling-shen-sources* true)

(assert-equal
 (shen-cl.kl->lisp [trap-error [value varname] [lambda E default]])
 (shen-cl.kl->lisp [shen-cl.value/or varname [freeze default]]))

(assert-equal
 (shen-cl.kl->lisp [trap-error [<-address Var [+ 10 10]] [lambda E default]])
 (shen-cl.kl->lisp [shen-cl.<-address/or Var [+ 10 10] [freeze default]]))

(assert-equal
 (shen-cl.kl->lisp [trap-error [<-vector Var [+ 10 10]] [lambda E default]])
 (shen-cl.kl->lisp [shen-cl.<-vector/or Var [+ 10 10] [freeze default]]))

(assert-equal
 (shen-cl.kl->lisp [trap-error [get Var prop Dict] [lambda E default]])
 (shen-cl.kl->lisp [shen-cl.get/or Var prop Dict [freeze default]]))

(assert-equal
  (shen-cl.compile-expression [X 1 2 3] [X])
  [(shen-cl.cl funcall) [(shen-cl.cl funcall) [(shen-cl.cl funcall) X 1] 2] 3])

(assert-equal
  (shen-cl.kl->lisp [let T 1 [+ T T]])
  [(shen-cl.cl let) [[SHEN-CL.SAFE-T 1]] [shen-cl.add SHEN-CL.SAFE-T SHEN-CL.SAFE-T]])

(if (= (language) "Common Lisp")
    (do
      (assert-equal
        (shen-cl.kl->lisp [lisp. "(+ 1 2)"])
        [+ 1 2])

      (assert-equal
        (shen-cl.kl->lisp [lisp. "symbol"])
        symbol)

      (assert-equal
        (shen-cl.kl->lisp [lisp. "(lambda () 1)"])
        [lambda [] 1]))
    skip)
