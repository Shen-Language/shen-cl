[![Shen Version](https://img.shields.io/badge/shen-22.3-blue.svg)](https://github.com/Shen-Language)
[![Build Status](https://travis-ci.org/Shen-Language/shen-cl.svg?branch=master)](https://travis-ci.org/Shen-Language/shen-cl)

# Shen for Common Lisp

<img src="https://raw.githubusercontent.com/Shen-Language/shen-cl/master/assets/logo.png" align="right">

[Shen](http://www.shenlanguage.org) for Common Lisp by [Mark Tarver](http://marktarver.com/), with contributions by the [Shen Language Open Source Community](https://github.com/Shen-Language).

This codebase currently supports the following implementations:

  * [Armed Bear Common Lisp](https://abcl.org/)
  * [GNU CLisp](http://www.clisp.org/)
  * [Clozure Common Lisp](http://ccl.clozure.com/)
  * [Embeddable Common Lisp](https://common-lisp.net/project/ecl/)
  * [Steel Bank Common Lisp](http://www.sbcl.org/)

This port acts as the standard implementation of the Shen language. It is also the fastest known port, running the standard test suite in 4-8 seconds on SBCL, depending on hardware.

Bug reports, fixes and enhancements are welcome. If you intend to port Shen to another variety of Common Lisp, consider doing so as a pull request to this repo.

## Features

Documentation of native interop functions is in [INTEROP.md](INTEROP.md). These functions allow calling into Lisp from Shen and Shen from Lisp.

Also included is the function `cl.exit`, which takes an exit code, terminates the process, returning the given exit code.

## Prerequisites

See [PREREQUISITES.md](PREREQUISITES.md) for information on what tools you will need installed to build and work on `shen-cl`.

## Downloading

Pre-built binaries of the SBCL port are available on the [releases](https://github.com/Shen-Language/shen-cl/releases) page. Just make sure the executable is in your `PATH`.

There is also a [Homebrew formula](https://github.com/Shen-Language/homebrew-shen/blob/master/Formula/shen-sbcl.rb) for the SBCL build. It can be run like so:

```shell
brew install Shen-Language/homebrew-shen/shen-sbcl
```

## Building

The `Makefile` automates all build and test operations.

| Target       | Operation                                    |
|:-------------|:---------------------------------------------|
| `fetch`      | Download and extract Shen sources.           |
| `precompile` | Precompile kernel and compiler to Lisp code. |
| `build-X`    | Build executable.                            |
| `test-X`     | Run test suite.                              |
| `X`          | Build and run test suite.                    |
| `run-X`      | Start Shen REPL.                             |
| `release`    | Creates archive of compiled binaries.        |

`X` can be `abcl`, `clisp`, `ccl`, `ecl`, `sbcl` or it can be `all`, which will run the command for all of the preceding.

`precompile` is only required when bootstraping Shen/CL from this repository, the source release includes the precompiled files. The `SHEN` variable has to be defined and point to a working Shen executable that will be used to precompile the kernel and compiler code.

## Building from a precompiled sources release

The precompiled source relases (`shen-cl-vX.Y.Z-sources.{tar.gz,zip}`) contain all the `.lsp` files required to build a working Shen executable (precompiled from `.shen` sources). To do so, run the `build-X` make target:

```shell
# Produces an executable in bin/sbcl/shen
make build-sbcl
# Runs the created executable
make run-sbcl
```

## Running

An executable is generated for each platform in its platform-specific output directory under `bin/` (e.g. `bin/sbcl/shen.exe`). Per typical naming conventions, it is named `shen.exe` on Windows systems and just `shen` on Unix-based systems.

Running `shen --help` shows a full listing of command-line options:

When starting Shen via `make`, command line arguments can be passed through like this: `make run-sbcl Args="eval -l init.shen -e (run)"`.

## Releasing

Archives of pre-built binaries are created using the `make release` command. They will appear under `release/`, named with the operating system and current git tag or short commit hash.

Currently, only the license file and the SBCL build are included (named `shen[.exe]`).

Each tagged release on the project downloads page should have a set of pre-built archives. Be sure to archive the build of that specific commit, like this:

```shell
make pure
git checkout v3.0.3
make fetch
make precompile SHEN=shen-sbcl
make sbcl
make release
```
