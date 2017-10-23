# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)

## [Unreleased]

Nothing yet.

## [2.2.0] - 2017-08-23

### Added
- Added support for CCL (Clozure Common Lisp).
- Added support for ECL (Embeddable Common Lisp).
- Added `-q`|`--quiet` flag that sets `*hush*` to true, disabling most output.

### Changed
- Updated to ShenOS 20.1.
- Script arguments are now preceded by `-l`, all args go in `*argv*`.
- Made CLisp build output an executable like CCL and SBCL do.
- Refactored Makefile. Now `make fetch` must always be run before anything else.
- Moved most `*.lsp` and `*.shen` files under src/ directory.
- Changed build output directory from `native` to `bin`.

[Unreleased]: https://github.com/Shen-Language/shen-cl/compare/v2.2.0...HEAD
[2.2.0]: https://github.com/Shen-Language/shen-cl/compare/v2.1.0...v2.2.0
