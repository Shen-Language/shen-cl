# Change Log

This log starts from the code copied over from legacy projects [Shen-Language/shen-clisp](https://github.com/Shen-Language/shen-clisp) and [Shen-Language/shen-sbcl](https://github.com/Shen-Language/shen-sbcl).

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/).

## [Unreleased]

### Changed

- Upgrade to the community ShenOSKernel 43.1 kernel and its standard library
  and extensions, preserving the unmodified kernel archive and hash checks.
- Expose `char-stream?`, `read-unit-string`, and `write-string` under their
  public S43.1 names. Reuse native character stream detection and Unicode I/O,
  retaining the reader's EOF and final-input handling.

## [3.1.0]

### Changed

- Upgrade to the unmodified community ShenOSKernel 42.2 release, including
  its standard library, namespaces, programmable patterns, and type annotations.
  Kernel downloads verify the pinned SHA-256; a local archive supports offline
  builds. Integrate pyrex41/shen-cl through `d59bf13`.
- Share the standard library and initialization sequence across SBCL, CLISP,
  and ECL. Keep global function bindings and interactive redefinition.
- Improve SBCL code generation for predicates, literal equality, checked
  arithmetic, Boolean expressions, and global assignments. Retain general
  numeric behavior, overflow handling, and runtime checks.
- Reduce overhead and allocation in equality, dictionary lookup, tuple and
  Prolog-variable construction, string primitives, symbol classification,
  stream dispatch, and reader operations. Dictionary keys use Shen structural
  equality, including case-sensitive strings and equal numeric representations;
  the public kernel `hash` function is unchanged.
- Cache repeated pattern accessors in ordinary compilation and generated
  kernel Lisp, invalidating cached values across mutation, unknown calls,
  lexical scopes, and control-flow joins. Share pattern fallbacks instead of
  duplicating generated code. The default factorisation policy is unchanged.

### Fixed

- Preserve guard evaluation order, exception behavior, and tail positions
  when factorising patterns. Large patterns compile without exponential
  duplication or repeated accessor chains.
- Keep literal numeric comparisons followed by Prolog-variable tests correct
  on SBCL 2.2.9, avoiding its incorrect propagation of `eql` type constraints.
- Update native macro expansion to the 42.2 source-form handler protocol;
  derive the port compiler's callable metadata from its definitions.
- Preserve `(fn input+)`, recognize the Shen variable `T` in `atom?`, correctly
  name the native `shen.pvar?` override, and accept integral floats in
  `integer?` without narrowing bignums.
- Initialize raw vectors with the fail sentinel and preserve checked string
  and vector errors. Keep Shen vector bounds errors and native SBCL
  unbound-variable conditions efficient and catchable.
- Parse final input without a trailing newline and exit cleanly at stdin EOF.
  Preserve quiet-mode file writes and quote the fail symbol correctly during
  bootstrapping.
- Restore CLISP builds under C/POSIX locales, suppress ECL compiler output at
  startup, and preserve host overrides when compiling on ECL.
- Include documentation and optional extensions in source archives, and omit
  macOS archive metadata. Release automation validates the port version and
  publishes the precompiled source archive alongside platform binaries,
  including a tested Windows x64 ZIP distribution.

### Added

- Explicitly loaded SHA-256 host extension under `extensions/sha256/`, with
  separate documentation, feature registration, and tests.
- Optional Nix development environment, plus SBCL `thread` and `terminate`
  primitives for the kernel concurrency library.
- Regression coverage for the kernel upgrade, compiler, primitives, reader,
  streams, dictionaries, patterns, accessors, extensions, and command line.
- [SBCL optimization guide](docs/SBCL-PERFORMANCE.md) describing the retained
  optimizations, their correctness constraints, and further opportunities.
  Runtime and allocation investigations were validated on SBCL 2.6.9.

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

[Unreleased]: https://github.com/Shen-Language/shen-cl/compare/v3.1.0...HEAD
[3.1.0]: https://github.com/Shen-Language/shen-cl/compare/v3.0.3...v3.1.0
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
