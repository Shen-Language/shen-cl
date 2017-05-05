[![Shen Version](https://img.shields.io/badge/shen-20.0-blue.svg)](https://github.com/Shen-Language)
[![Build Status](https://travis-ci.org/Shen-Language/shen-cl.svg?branch=master)](https://travis-ci.org/Shen-Language/shen-cl)

# Shen for Common Lisp

[Shen](http://www.shenlanguage.org) for Common Lisp by [Mark Tarver](http://marktarver.com/), with contributions by the [Shen Language Open Source Community](https://github.com/Shen-Language).

This codebase currently supports the following implementations:

  * [GNU CLisp](http://www.clisp.org/)
  * [Clozure Common Lisp](http://ccl.clozure.com/)
  * [Steel Bank Common Lisp](http://www.sbcl.org/)

This port is often considered the de-facto standard implementation of the Shen language. It is also the fastest known port, running the standard test suite in 4-8 seconds on SBCL, depending on hardware.

Bug reports, fixes and enhancements are welcome. If you intend to port Shen to another variety of Common Lisp, consider doing so as a pull request to this repo.

## Building

You will need to have the Common Lisp implementations you want to work with installed and available as the `Makefile` requires. Setup is different depending on operating system.

### Linux

CLisp and SBCL are available through `apt`. Just run `sudo apt install clisp sbcl`.

There is a [separately available package](http://mr.gy/blog/clozure-cl-deb.html) for Clozure. Run the following to download and install it:

```bash
wget http://mr.gy/blog/clozure-cl_1.11_amd64.deb
dpkg -i clozure-cl_1.11_amd64.deb
```

### macOS

CLisp, Clozure and SBCL can be acquired through Homebrew with `brew install clisp clozure-cl sbcl`.

### Windows

CLisp has an exe installer on [SoureForge](https://sourceforge.net/projects/clisp/files/clisp/2.49/).

Clozure will need to be installed manually:
  * Download the zip from [here](https://ccl.clozure.com/download.html) and extract it under `Program Files`.
  * Put a script named `ccl.cmd` in your `%PATH%` containing something like:

```batch
@echo off
"C:\Program Files\ccl\wx86cl64.exe" %*
```

SBCL has an msi package on its [download page](http://www.sbcl.org/platform-table.html).

The `Makefile` uses commands typically not found on Windows, so [GOW](https://github.com/bmatzelle/gow) is recommended.

### `Makefile` Operations

  * Fetch kernel sources, build and test all ports with `make all`.
  * Fetch kernel sources with `make fetch`.
  * Build and test the CLisp port with `make clisp`.
  * Build and test the Clozure port with `make ccl`.
  * Build and test the SBCL port with `make sbcl`.
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
