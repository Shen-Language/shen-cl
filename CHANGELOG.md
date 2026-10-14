# Change Log

This log starts from the code copied over from legacy projects [Shen-Language/shen-clisp](https://github.com/Shen-Language/shen-clisp) and [Shen-Language/shen-sbcl](https://github.com/Shen-Language/shen-sbcl).

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/).

## [Unreleased]

### Changed

- Integrate pyrex41/shen-cl through `d59bf13`, including its Nix environment,
  pattern factorizer, and kernel update.
- Bundle the 42.2 namespace, programmable pattern, and type annotation
  extensions, and derive the port compiler's callable metadata at build time.
- Emit direct predicates, literal equality tests, literal global assignments,
  and Boolean tests through `let`/`do`. Inline checked small primitives and
  expose predicate helpers before compiling the generated kernel.
- Expose checked fixnum and double-float arithmetic paths, avoid redundant
  double-float normalization, and inline numeric-literal and strict Boolean
  tests. General equality no longer repeats failed list comparisons.
- Avoid allocating a punctuation list on each reader character test, while
  preserving numeric equality and the classifier's replaceable global binding.
- Check ordinary tuple markers directly and compare vector elements with a
  checked index loop. General equality dispatches fixnum comparisons directly,
  retaining host-array checks and numeric equality across representations.
- Construct fresh unit strings directly in `pos` and `n->string`.
- Reject distinct symbols directly in general equality, preserving numeric paths.
- Apply accessor caching to generated kernel/StLib Lisp, with invalidation
  across writes, unknown calls, branches, and control-flow joins.
- Use structural dictionary keys with case-sensitive strings and numeric
  equality across representations. Preserve the unchanged public kernel `hash`.
- Retain dynamic kernel bindings and interactive redefinition. Optimization
  rationale and further opportunities are documented in
  [docs/SBCL-PERFORMANCE.md](docs/SBCL-PERFORMANCE.md).

- **Kernel: ShenOSKernel 42.2** (community `Shen-Language/shen-sources` tag
  `shen-42.2`, commit `73507e0`, `ShenOSKernel-42.2.tar.gz` SHA-256
  `1d02273003654d34ec020ae67cb214ecec410dee3350419ff807d82b652678d8`), the
  kernel shipped by shen-scheme 0.50, adopted wholesale. This replaces the
  Tarver S42.0 hybrid. `(version)` now reports `42.2`. See
  [docs/KERNEL-PROVENANCE-42.2.md](docs/KERNEL-PROVENANCE-42.2.md) (the old
  provenance doc is kept as history) and issue #21.
- `make fetch` now downloads the 42.2 release, verifies its pinned SHA-256 and
  extracts it unmodified (`scripts/fetch-kernel.sh`; pass `KERNEL_ARCHIVE=`
  to use a local tarball). `scripts/assemble-tarver-kernel.sh`,
  `fetch-tarver` and `fetch-community` were removed.
- Boot loads `dict.kl`, `init.kl` and `stlib.kl`, then runs
  `shen.initialise` and `stlib.initialise`. SBCL, CLISP and ECL now share the
  precompiled standard library; the ECL-only `stlib.kl` graft divergence is
  gone.
- The native `macroexpand`/`shen.macroexpand-h` overrides take the 42.1
  source-form handler registry (4th argument).
- The `(trap-error (get ..) ..)` to `shen-cl.get/or` compiler peephole is
  restored, because the property store is a dict again.
- Removed the Tarver-only shims (`shen.repl` alias, no-op `shen.initialise`,
  `shen.toplevel-display-exception`, `shen.set-lambda-form-entry`).

### Fixed

- Preserve repeated guard evaluation and errors in the backend pattern
  factoriser by sharing only stable parameter tests.
- Keep `(fn input+)` callable, correctly name the native `shen.pvar?`
  override, and accept integral floats in `integer?` without narrowing bignums.
- Avoid traversing identical equality operands and allocating escaped symbol
  strings when no escaping is needed.
- CLI tests require clean EOF handling and preserve quiet-mode file writes.

- `read`/`lineread` on a character stream (e.g. SBCL/ECL stdin) now parse
  input that ends at EOF without a trailing newline, instead of failing with
  `"" is not a unit string` (kernel 42.1 requirement). The REPL evaluates such
  a final form before exiting at EOF.
- `scripts/build.shen` quoted the fail object `shen.fail!` incorrectly when
  the bootstrapping Shen's `(fail)` was that symbol. `explode` prints it as
  `...`, so the case check failed and `(defun fail () ...)` was emitted as an
  unquoted `'shen.fail!`, which CL reads as a different, upcased symbol. The
  symbol's name is now exploded instead.
- `src/overwrite.lsp` is ASCII-only, so the CLISP build no longer fails under
  a C/POSIX locale.
- ECL no longer prints `;;; Loading .../cmp.fas` on stdout at startup.

### Added

- Optional SHA-256 host extension under `extensions/sha256/`, with explicit
  loading, feature registration, and its own documentation and tests.
- Performance documentation and extension/accessor regression targets,
  validated on SBCL 2.6.9.

### Earlier experimental kernel work

- Update the supported Tarver kernel to S42.0 (`S42.zip`, SHA-256
  `30abdc7e5a1e27b7a20109c1ed141e4712885e31f24d9710d16415fbbd4dfb23`). The
  community 41.2 archive remains an explicit source for launcher/features and
  certification grafts until equivalent S42 extensions are available.

**Experimental: build against Mark Tarver's refreshed S41.2 kernel (2026-07-11)**

Tarver re-uploaded a restructured kernel under the same "41.2" version number
to shenlanguage.org (a different lineage from the community `shen-41.2`
release). This branch adapts the shen-cl harness to build against it as a
hybrid (Tarver's shared KLambda files + community launcher/features/
expand-dynamic/stlib grafts). See
[docs/KERNEL-PROVENANCE-tarver-s41.2.md](docs/KERNEL-PROVENANCE-tarver-s41.2.md).

### Added

- `scripts/assemble-tarver-kernel.sh` and the `make fetch-tarver` target,
  which fetch Tarver's S41.2 refresh (sha256-pinned) plus the community
  `shen-41.2` grafts and assemble the hybrid `kernel/` tree.
- Provenance doc recording the source URL, 2026-07-11 Last-Modified, sha256,
  the standalone `install.lsp` canary result, and the SBCL test status.

### Changed (standard library from Tarver source)

- SBCL and CLISP now install the standard library from Tarver's canonical StLib
  sources (`kernel/lib/StLib`, run via his `install.shen`) baked into the saved
  image at build time, retiring the community `stlib.kl` graft on those hosts.
  ECL alone keeps the precompiled `stlib.kl` (its `c:build-program` cannot bake
  image state, and per-launch source install costs ~105s); imported under
  `#+ecl` only. See [docs/KERNEL-PROVENANCE-tarver-s41.2.md](docs/KERNEL-PROVENANCE-tarver-s41.2.md).

### Changed (for the S41.2 refresh)

- `src/compiler.shen`: disabled the `(trap-error (get ..) ..) -> shen-cl.get/or`
  peephole; the refreshed kernel's property store is a bucketed absvector, not
  a CL hash-table.
- `src/overwrite.lsp`: removed the `hash` override (the vector store buckets by
  the kernel `hash`); shimmed four functions the refresh dropped with `init.kl`
  (`shen.repl` aliased to `shen.shen`, no-op `shen.initialise`,
  `shen.set-lambda-form-entry`, `shen.toplevel-display-exception`).
- `boot.lsp` / `scripts/build.shen`: dropped `dict`/`init` from the file lists
  (native dicts; init folded into `declarations.kl`), and moved `t-star` before
  `types` in boot load order (the refreshed `types.kl` calls `shen.rectify-type`
  at load time, which the refresh defines in `t-star.kl`).

### Fixed

- Compiling a function with many clauses sharing test prefixes (a plain
  dispatch table like `c1 a -> …  c1 b -> …  c2 a -> …`) no longer blows up
  exponentially. The pattern factoriser (`shen-cl.factorise-cases` in
  `src/overwrite.lsp`) groups consecutive clauses sharing a first test, and
  spliced the remaining clauses into BOTH the shared-test-failed path and the
  no-sub-test-matched fallthrough; each splice contained the next group's two
  splices, so generated code grew 2^groups (16 two-clause groups: 394 KL nodes
  → 2.1M Lisp nodes, 446s and heap exhaustion inside SBCL's `COMPILE`). The
  remaining clauses are now emitted once as a `tagbody` label that both paths
  `GO` to — the join the kernel's original `factorise-defun` extension used via
  `%%let-label`/`%%goto-label`/`%%return`, machinery `src/compiler.shen` had
  kept all along — with clause bodies `%%return`ing through the `(BLOCK NIL …)`
  that `add-block` already wraps around factorised defuns. Clause order and
  test/body evaluation order are unchanged; growth is now linear (16 groups:
  783 nodes, 0.03s; 200 groups compiles in 0.04s). The accessor-chain binding
  pass learned to walk `TAGBODY` statements (each from the tagbody's entry
  env, since `GO` joins mean no statement's bindings are guaranteed in
  another), so large patterns inside factored groups still compile cheaply.
  Regression-tested by `tests/pattern-tests.shen` (grouped-dispatch).

- Compiling a function that destructures a moderately large literal pattern
  (e.g. a ~100-leaf record) no longer exhausts SBCL's 1GB heap. The kernel's
  pattern compiler re-derives the full `hd`/`tl` accessor chain for every
  pattern element, so the emitted code grew with pattern-size × pattern-depth
  and the host compiler's cost grew far faster than that (~800MB consed for a
  12k-node form on SBCL). `eval-kl` now runs the KL→Lisp output through an
  accessor-chain binding pass (`shen-cl.bind-accessor-chains` in
  `src/primitives.lsp`) that computes each `CAR`/`CDR` step once, binds it to
  a function-local via an inline `SETQ` at its first occurrence, and
  references it thereafter — semantics, evaluation order and results are
  unchanged, and precompiled kernel sources (`compiled/*.lsp`) are
  byte-identical. Regression-tested by `tests/pattern-tests.shen`.

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
