[![Shen Version](https://img.shields.io/badge/shen-20.0-blue.svg)](https://github.com/Shen-Language)
[![Build Status](https://travis-ci.org/Shen-Language/shen-cl.svg?branch=master)](https://travis-ci.org/Shen-Language/shen-cl)

# Shen for Common Lisp

[Shen](http://www.shenlanguage.org) for Common Lisp by [Mark Tarver](http://marktarver.com/), with contributions by the [Shen Language Open Source Community](https://github.com/Shen-Language).

This codebase currently supports the following implementations of Common Lisp:

  * [GNU CLisp](http://www.clisp.org/)
  * [Clozure Common Lisp](http://ccl.clozure.com/) (Work in Progress)
  * [Steel Bank Common Lisp](http://www.sbcl.org/)

This Common Lisp port is often considered the de-facto standard implementation of the Shen language. It is also the fastest known port, running the standard test suite in 4-8 seconds on SBCL, depending on hardware.

### Building

You will need to have the Common Lisp implementations you want to work with installed. These can be acquired with `apt` on linux or downloaded from the official websites linked above.

If you are running Windows, [GOW](https://github.com/bmatzelle/gow) is recommended as it comes with `make` as well as commands used in the `Makefile`.

`Makefile` operations:

  * Fetch kernel sources by running `make fetch`.
  * Build all ports by running `make`.
    * Build only the CLisp port with `make build-clisp`.
    * Build only the Clozure port with `make build-ccl`.
    * Build only the SBCL port with `make build-sbcl`.
  * Test all ports with `make test-all`.
    * Test only the CLisp port with `make test-clisp`.
    * Test only the Clozure port with `make test-ccl`.
    * Test only the SBCL port with `make test-sbcl`.
  * Run Shen REPL for CLisp port with `make run-clisp`.
  * Run Shen REPL for Clozure port with `make run-ccl`.
  * Run Shen REPL for SBCL port with `make run-sbcl`.

### Contributing

Bug reports, fixes and enhancements are welcome. If you intend to port Shen to another variety of Common Lisp, consider doing so as a pull request to this repo.
