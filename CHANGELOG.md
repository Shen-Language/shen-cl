# Change Log

This log starts from the code copied over from legacy projects [Shen-Language/shen-clisp](https://github.com/Shen-Language/shen-clisp) and [Shen-Language/shen-sbcl](https://github.com/Shen-Language/shen-sbcl).

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/).

## [Unreleased]

### Added
- `make release` command that creates os-specific archive of compiled binaries for each target CL implementation.
- ECL build emits static and shared libraries with os-specific suffixes (see `build.lisp`).

### Changed
- `cond` now raises an error when no condition is true, instead of returning `[]`.
- `cond` optimizes away clauses after clause with `true` condition.
- Lisp source files renamed from `*.lsp` to `*.lisp`.
- `boot.lsp` renamed to `build.lisp`.
- Replaced `platform.shen` with `platform.lisp`.
- Normalized use of `shen-cl.` prefix for internal functions.
- `hd` and `tl` now raise error when given an empty list.

### Fixed
- `T` can be used as a variable as `defun` and `lambda` parameter in addition to `let` variable.

## [2.2.0] - 2017-08-23

### Added
- Support for ECL (Embeddable Common Lisp).
- `-q`|`--quiet` flag that sets `*hush*` to true, disabling most output.

### Changed
- Refactored Makefile. Now `make fetch` must always be run before anything else.
- Moved most `*.lsp` and `*.shen` files under src/ directory.
- Changed build output directory from `native` to `bin`.

## [2.1.0] - 2017-05-22

### Added
- Support for CCL (Clozure Common Lisp).
- Makefile.
- CHANGELOG.
- Travis-CI build script.

### Changed
- Updated to ShenOS 20.1.
- Made built process dependent on pre-built KL from https://github.com/Shen-Language/shen-sources/releases.
- Script arguments are now preceded by `-l`, all args go in `*argv*`.
- Made CLisp build output an executable like CCL and SBCL do.
- Cleaned up `backend.lsp`, as `backend.shen` was removed.
- Expanded README.

[Unreleased]: https://github.com/Shen-Language/shen-cl/compare/v2.2.0...HEAD
[2.2.0]: https://github.com/Shen-Language/shen-cl/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/Shen-Language/shen-cl/compare/031d8f2a4bcdf95987dc074985875c24d6caa2f3...v2.1.0
