# Interop

## Converting Between Shen and Lisp Data Types

Shen programs can convert from a Shen boolean to a CL boolean with `shen-cl.true?`.

```
(shen-cl.true? true)
T

(shen-cl.true? false)
NIL
```

## Qualifying Common Lisp Functions in Shen

Underlying Common Lisp functions can be qualified by prefixing them with `lisp.`.

```
(lisp.sin 6.28)
-0.0031853017931379904
```

Common Lisp code can also be injected inline using the `(lisp. "COMMON LISP SYNTAX")` syntax. The `lisp.` form takes a single string as its argument. Also keep in mind that shen-cl puts Common Lisp into case-sensitive mode where CL functions and symbols are upper-case so they don't conflict with symbols defined for Shen.

```
(lisp. "(SIN 6.28)")
-0.0031853017931379904

(lisp. "(sin 6.28)")
The function COMMON-LISP-USER::sin is undefined.
```

## Evaluating and Loading Common Lisp Code from Shen

Similarly to `lisp.`, Common Lisp code can be used inline through `shen-cl.eval-lisp`, which evaluates the given string as a lisp form and returns the result. Code evaluated this way exists in the `:COMMON-LISP-USER` package (rather than `:SHEN`) and with the reader in case insensitive mode, so it is ideal for accessing external lisp code.

```
(shen-cl.eval-lisp "(defun cl-plus-one (x) (+ 1 x))")
CL-PLUS-ONE

(shen-cl.eval-lisp "(cl-plus-one 1)")
2
```

Common Lisp code can be loaded from external files with `shen-cl.load-lisp`:

```
(shen-cl.load-lisp "~/quicklisp/setup.lisp")
T

(shen-cl.eval-lisp "(ql:quickload :infix-math)")
To load "infix-math":
  Load 1 ASDF system:
    infix-math
; Loading "infix-math"
.
[INFIX-MATH]

(shen-cl.eval-lisp "(infix-math:$ 2 + 2)")
4
```

Like `shen-cl.eval-lisp`, `shen-cl.load-lisp` also operates in the `:COMMON-LISP-USER` package and case insensitive mode.

## Loading Shen Code from Common Lisp

The function `LOAD-SHEN` is exported from the `:SHEN-UTILS` package which allows the loading of Shen files from Common Lisp code.

`LOAD-SHEN` will load Shen code into the `:SHEN` namespace in case-perserving mode, just like all other Shen code.
