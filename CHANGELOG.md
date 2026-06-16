# Change Log

This log starts from the code copied over from legacy projects [Shen-Language/shen-clisp](https://github.com/Shen-Language/shen-clisp) and [Shen-Language/shen-sbcl](https://github.com/Shen-Language/shen-sbcl).

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/).

## [Unreleased]

**Updated to Shen Open Source Kernel 41.1**

### Added

- GitHub Actions release workflow that builds and publishes prebuilt SBCL binaries for Linux (`x86_64`, `aarch64`) and macOS (`arm64`, plus a best-effort `x86_64`) on tagged releases.
- `thread` and `terminate` threading natives on SBCL (ported from the official S41.1 distribution), registered via `update-lambda-table`. The kernel's concurrency library (`kernel/lib/concurrency`) now loads and runs.

### Changed

- Build pipeline updated for kernel 41.1: integrated the `stlib` and `extension-expand-dynamic` kernel extensions, and dropped the `factorise-defun` extension (its optimization is now implemented natively).
- Test target now loads the kernel's `runme.shen` harness.
- `absvector` now initializes elements to the `(fail)` sentinel, matching the official S41.1 port and Shen/Scheme, so `<-vector` on an unset slot of a raw absvector signals "not found" instead of returning an implementation-defined value.
- `pos`, `tlstr`, `n->string` and `string->n` validate their arguments and signal the same descriptive errors as the official S41.1 port (e.g. `"ab" is not a unit string`) instead of leaking raw Common Lisp conditions.

### Fixed

- Fixed optimizations for addition and subtraction of 1.
- Fixed code generation for number equality checks when one of the arguments is a known number.
- `atom?` now recognizes Common Lisp `T` (used for the Shen variable `T`), fixing the Prolog `<hterm>` parser and the `montague.shen` type-checker test.
- CLisp support restored: `shen-cl.process-number` used a non-conforming `LOOP` (`for` clause after `while`) that indexed past the end of the string on CLISP; added the `shen.char-stoutput?` and `shen.write-string` stream primitives needed by the kernel's `pr` on implementations without the native `pr` override; on macOS the image is saved with `:executable t :script nil` (the `:executable 0` format fails Apple Silicon code-signature checks and is killed at exec).
- ECL support restored: startup no longer calls the removed `factorise-defun` extension; and every function `overwrite.lsp` redefines is proclaimed `NOTINLINE` before the kernel compiles, since ECL emits direct C calls for intra-file references, which silently bypassed the overrides (e.g. prolog's `atom?`, breaking datatypes mentioning the variable `T`).

### Performance

- O(N) native overrides for the reader primitives `shen.str->bytes`, `shen.bytes->string`, `shen.rfas-h` and `shen.reader-error-message`, replacing O(N²) recursive concatenation.
- `macroexpand` now extracts the macro functions once and uses an `EQ` fast-path to skip deep-equality checks when a macro leaves its input unchanged.
- Native KL `cond` factorization that groups consecutive clauses sharing a leading `and` test, reducing redundant guard evaluation.
- `(length X)` now compiles to Common Lisp's optimized `LIST-LENGTH` instead of the kernel's recursive `length` (ported from the official S41.1 backend).

## [3.0.3] - 2019-12-07

### Fixed

- Fixed override for `shen.dict-fold` that was not properly calling the curried function, which also broke `shen.dict-keys` and `shen.dict-values`.

## [3.0.2] - 2019-10-13

### Changed

- Overrides for `symbol?` and `variable?`. This speeds up the time it takes for `eval` to compile expressions considerably.

## [3.0.1] - 2019-10-13

### Changed

- `@p` and `vector` constructors are now overriden by better performing native implementations.
- `read-file-as-bytelist`, `shen.read-file-as-charlist` and `shen.read-file-as-charlist` are also overriden by native implementations.

## [3.0.0] - 2019-10-12

**Updated to Shen Open Source Kernel 22.2**

### Changed

- New compiler imported from Shen/Scheme. Generates code that performs better and allocates less memory.
- Common Lisp's read-table case rules are not modified anymore.
- Bootstraping from scratch requires a working Shen implementation to precompile the compiler code and kernel.

## [2.7.0] - 2019-10-03

**Updated to Shen Open Source Kernel 22.1**

### Changed

- Reintroduced backend written in Shen.
- Moved everything in the compiler from the `shen` namespace to `shen-cl`.
- Command-line handling has been replaced by the "launcher" kernel extension.
- `do` expressions now get compiled into `PROGN` expression, making them tail-call optimization friendly.

### Added

- Integrated "features" kernel extension.
- Integrated "launcher" kernel extension.
- Integrated "factorise-defun" kernel extension optimization.
- Source release which includes a pre-compiled `backend.lsp` file.
- `shen-cl.lisp-true?` to convert from CL to Shen booleans (counterpart to `shen-cl.true?`).

## [2.6.1] - 2019-09-17

**Updated to Shen Open Source Kernel 21.2**

### Changed

- `*port*` is now a string with a `major.minor.patch` format.
- Errors raised when evaluating `--load` and `--eval` arguments now print error and exit with code 1.

## [2.6.0] - 2019-09-04

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

[Unreleased]: https://github.com/Shen-Language/shen-cl/compare/v3.0.3...HEAD
[3.0.3]: https://github.com/Shen-Language/shen-cl/compare/v3.0.2...v3.0.3
[3.0.2]: https://github.com/Shen-Language/shen-cl/compare/v3.0.1...v3.0.2
[3.0.1]: https://github.com/Shen-Language/shen-cl/compare/v3.0.0...v3.0.1
[3.0.0]: https://github.com/Shen-Language/shen-cl/compare/v2.7.0...v3.0.0
[2.7.0]: https://github.com/Shen-Language/shen-cl/compare/v2.6.1...v2.7.0
[2.6.1]: https://github.com/Shen-Language/shen-cl/compare/v2.6.0...v2.6.1
[2.6.0]: https://github.com/Shen-Language/shen-cl/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/Shen-Language/shen-cl/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/Shen-Language/shen-cl/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/Shen-Language/shen-cl/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/Shen-Language/shen-cl/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/Shen-Language/shen-cl/compare/031d8f2a4bcdf95987dc074985875c24d6caa2f3...v2.1.0
