[![Shen Version](https://img.shields.io/badge/shen-21.1-blue.svg)](https://github.com/Shen-Language)
[![Build Status](https://travis-ci.org/Shen-Language/shen-cl.svg?branch=master)](https://travis-ci.org/Shen-Language/shen-cl)

# Shen for Common Lisp

[Shen](http://www.shenlanguage.org) for Common Lisp by [Mark Tarver](http://marktarver.com/), with contributions by the [Shen Language Open Source Community](https://github.com/Shen-Language).

This codebase currently supports the following implementations:

  * [GNU CLisp](http://www.clisp.org/)
  * [Clozure Common Lisp](http://ccl.clozure.com/)
  * [Embeddable Common Lisp](https://common-lisp.net/project/ecl/)
  * [Steel Bank Common Lisp](http://www.sbcl.org/)

This port acts as the standard implementation of the Shen language. It is also the fastest known port, running the standard test suite in 4-8 seconds on SBCL, depending on hardware.

Bug reports, fixes and enhancements are welcome. If you intend to port Shen to another variety of Common Lisp, consider doing so as a pull request to this repo.

## Features

`shen-cl` supports calling underlying Common Lisp functions by prefixing them with `lisp.`.

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

Similarly to `lisp.`, Common Lisp code can be used inline through `shen-cl.eval-lisp`, which evaluates the given string as a lisp form and returns the result. Code evaluated this way exists in the `:COMMON-LISP-USER` package (rather than `:SHEN`) and with the reader in case insensitive mode, so it is ideal for accessing external lisp code.

```
(shen-cl.eval-lisp "(defun cl-plus-one (x) (+ 1 x))")
CL-PLUS-ONE

(shen-cl.eval-lisp "(cl-plus-one 1)")
2
```

Common Lisp code can be loaded from external files with `shen-cl.load-lisp`

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

The function `shen-cl.exit` is included, which takes a single integer argument, terminates the process, returning the argument as the exit code.

The function `LOAD-SHEN` is exported from the `:SHEN-UTILS` package which allows the loading of Shen files from Common Lisp code.

## Prerequisites

See [PREREQUISITES.md](PREREQUISITES.md) for information on what tools you will need installed to build and work on `shen-cl`.

## Building

The `Makefile` automates all build and test operations.

| Target    | Operation                             |
|:----------|:--------------------------------------|
| `fetch`   | Download and extract Shen sources.    |
| `build-X` | Build executable.                     |
| `test-X`  | Run test suite.                       |
| `X`       | Build and run test suite.             |
| `run-X`   | Start Shen REPL.                      |
| `release` | Creates archive of compiled binaries. |

`X` can be `clisp`, `ccl`, `ecl`, `sbcl` or it can be `all`, which will run the command for all of the preceding.

## Running

An executable is generated for each platform in its platform-specific output directory under `bin/` (e.g. `bin/sbcl/shen.exe`). Per typical naming conventions, it is named `shen.exe` on Windows systems and just `shen` on Unix-based systems.

Startup scripts can be specified on the command line by preceding them with a `-l` flag. If any startup scripts are specified this way, they will be loaded in order and then `(shen-cl.exit 0)` will be called. If none are, the Shen REPL will start as usual. Either way, all command line arguments will be accessible with `(value *argv*)`.

When starting Shen via `make`, command line arguments can be passed through like this: `make run-sbcl Args="-l bootstrap.shen -flag"`.

## Releasing

Archives of pre-built binaries are created using the `make release` command. They will appear under `release/`, named with the operating system and current git tag or short commit hash.

Currently, only the license file and the SBCL build are included (named `shen[.exe]`).

Each tagged release on the project downloads page should have a set of pre-built archives. Be sure to archive the build of that specific commit, like this:

```shell
make pure
git checkout v2.4.0
make fetch
make sbcl
make release
```
