# Change Log

This log starts from the code copied over from legacy projects [Shen-Language/shen-clisp](https://github.com/Shen-Language/shen-clisp) and [Shen-Language/shen-sbcl](https://github.com/Shen-Language/shen-sbcl).

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/).

## [Unreleased]

### Changed
  - `*port*` is now a string with a `major.minor.patch` format.
  - Errors raised when evaluating `--load` and `--eval` arguments now print error and exit with code 1.

## [2.6.0] - 2017-09-04

### Added
  - `-s`/`--set` sets global symbols, removing use case for `*argv*`.
  - Automated binary builds for Linux, Windows and OSX through Travis.

### Changed
  - `*argv*` has been removed.
  - `-r` gets run in left-to-right order like other options.
  - `-v`, `-h` don't exit immediately after.
  - Unrecognized options cause exit with code `-1` instead of getting skipped.
  - REPL only starts by default if no command line options specified.
  - Amended `shen.credits` to explain exit command.
  - Improved help (`-h`) message.

## [2.5.0] - 2019-08-01

### Added
- `shen-cl.load-lisp`, `shen-cl.eval-lisp` that load and evals Lisp code in string form from Shen.
- `LOAD-SHEN` that loads Shen code from Lisp.
- `:SHEN` package where Shen code is defined by default.
- `-r`/`--repl` option to force running REPL even if other options would prevent REPL from running.
- `cl.exit` (cf. `shen-cl.exit`) as it is CL-specific function and not shen-cl-specific function.

### Changed
- `absvector?` no longer returns `true` for strings.
- `CF-VECTORS` can now compare empty absvectors.
- Shen code now gets defined in `:SHEN` package instead of `:COMMON-LISP` package.
- Makefile uses `curl` instead of `wget` on macOS.

## [2.4.0] - 2018-10-08

**Updated to Shen Open Source Kernel 21.1**

## [2.3.0] - 2018-06-01

**Updated to Shen Open Source Kernel 21.0**

### Added
- `make release` command that creates os-specific archive of compiled binaries.
- `dict.kl` to list of KL imports.
- `lisp.` form to embed literal Common Lisp code.

### Changed
- `cond` now raises an error when no condition is true, instead of returning `[]`.
- Reimplemented `lisp.` prefixed native calls in the compiler.

### Renamed
- `exit` -> `shen-cl.exit`.
- `read-char-code` -> `shen.read-char-code`

### Removed
- `command-line` - use `(value *argv*)` instead.

## [2.2.0] - 2017-08-23

### Added
- Support for ECL (Embeddable Common Lisp).
- `-q`|`--quiet` flag that sets `*hush*` to true, disabling most output.

### Changed
- Refactored Makefile. Now `make fetch` must always be run before anything else.
- Moved most `*.lsp` and `*.shen` files under src/ directory.
- Changed build output directory from `native` to `bin`.

## [2.1.0] - 2017-05-22

**Updated to Shen Open Source Kernel 20.1**

### Added
- Support for CCL (Clozure Common Lisp).
- Makefile.
- CHANGELOG.
- Travis-CI build script.

### Changed
- Made built process dependent on pre-built KL from https://github.com/Shen-Language/shen-sources/releases.
- Script arguments are now preceded by `-l`, all args go in `*argv*`.
- Made CLisp build output an executable like CCL and SBCL do.
- Cleaned up `backend.lsp`, as `backend.shen` was removed.
- Expanded README.

[Unreleased]: https://github.com/Shen-Language/shen-cl/compare/v2.6.0...HEAD
[2.6.0]: https://github.com/Shen-Language/shen-cl/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/Shen-Language/shen-cl/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/Shen-Language/shen-cl/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/Shen-Language/shen-cl/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/Shen-Language/shen-cl/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/Shen-Language/shen-cl/compare/031d8f2a4bcdf95987dc074985875c24d6caa2f3...v2.1.0
