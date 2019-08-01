[![Shen Version](https://img.shields.io/badge/shen-21.1-blue.svg)](https://github.com/Shen-Language)
[![Build Status](https://travis-ci.org/Shen-Language/shen-cl.svg?branch=master)](https://travis-ci.org/Shen-Language/shen-cl)

# Shen for Common Lisp

<img src="https://raw.githubusercontent.com/Shen-Language/shen-cl/master/assets/logo.png" align="right">

[Shen](http://www.shenlanguage.org) for Common Lisp by [Mark Tarver](http://marktarver.com/), with contributions by the [Shen Language Open Source Community](https://github.com/Shen-Language).

This codebase currently supports the following implementations:

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

Startup scripts can be specified on the command line by preceding them with a `-l` flag. If any startup scripts are specified this way, they will be loaded in order and then `(cl.exit)` will be called. If none are, the Shen REPL will start as usual. Either way, all command line arguments will be accessible with `(value *argv*)`.

When starting Shen via `make`, command line arguments can be passed through like this: `make run-sbcl Args="-l bootstrap.shen -e (run)"`.

## Releasing

Archives of pre-built binaries are created using the `make release` command. They will appear under `release/`, named with the operating system and current git tag or short commit hash.

Currently, only the license file and the SBCL build are included (named `shen[.exe]`).

Each tagged release on the project downloads page should have a set of pre-built archives. Be sure to archive the build of that specific commit, like this:

```shell
make pure
git checkout v2.5.0
make fetch
make sbcl
make release
```
