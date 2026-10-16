# Kernel provenance: ShenOSKernel 42.2

shen-cl builds from the **community** ShenOSKernel 42.2 release from
[Shen-Language/shen-sources](https://github.com/Shen-Language/shen-sources),
the kernel that upstream [shen-scheme 0.50](https://github.com/tizoc/shen-scheme/tree/v0.50)
ships. The release is used unmodified.

| Field | Value |
|---|---|
| Repository | `Shen-Language/shen-sources` |
| Tag | `shen-42.2` |
| Commit | `73507e069fe147aefb728d632c4ce40bc6a7b314` |
| Release asset | `ShenOSKernel-42.2.tar.gz` |
| Asset SHA-256 | `1d02273003654d34ec020ae67cb214ecec410dee3350419ff807d82b652678d8` (also pinned in shen-scheme 0.50's Makefile) |
| Release date | 2026-10-01 |
| `(version)` | `"42.2"` (set by `shen.initialise-environment` in `init.kl`) |

## Lineage decision

Tracking issue #21 (umbrella pyrex41/bifrost#26, pyrex41/yggdrasil#32) gave
two options. shen-cl takes **option (a): adopt ShenOSKernel-42.2 wholesale**.

Before this change shen-cl built a hybrid of Mark Tarver's S42.0 (`S42.zip`,
2026-08-25) and community 41.2 grafts. That history is recorded in
[`KERNEL-PROVENANCE-tarver-s42.0.md`](KERNEL-PROVENANCE-tarver-s42.0.md) and
[`KERNEL-PROVENANCE-tarver-s41.2.md`](KERNEL-PROVENANCE-tarver-s41.2.md). The two
lineages share a version number but differ in structure. Tarver's S42 keeps
initialisation inline in `declarations.kl`/`types.kl`, so its load order
matters, and it has no `shen.initialise`, `dict.kl`, `init.kl`, `stlib.kl` or
extension files. Community 42.2 ships all of these. In 42.2 every `.kl` file
contains only `defun`s, and `init.kl` builds the environment.

## How the kernel enters the build

- `make fetch` runs `scripts/fetch-kernel.sh`. The script downloads the
  release asset, or uses `KERNEL_ARCHIVE=path/to/ShenOSKernel-42.2.tar.gz`
  when given, and refuses any archive whose SHA-256 differs from the value
  above. It also checks that `VERSION` is `42.2` and extracts the tree
  unchanged as `kernel/` (gitignored, as before). Nothing is grafted, patched
  or dropped.
- `make precompile SHEN=...` compiles `kernel/klambda/*.kl` (the core files,
  `dict`, `init`, `extension-features`, `extension-expand-dynamic`,
  `extension-launcher`, `extension-programmable-pattern-matching`,
  `extension-namespaces`, `extension-type-annotations` and `stlib`), the
  port compiler to `compiled/*.lsp`.
- `boot.lsp` loads them, then calls `(shen.initialise)`,
  `(shen-cl.initialise)`, `(shen.x.features.initialise ...)`,
  `(stlib.initialise)`, and the pattern/namespace initializers.
  SBCL and CLISP bake the resulting state into the saved
  image. ECL cannot bake runtime state, so it runs the same sequence at startup
  (`shen-cl.toplevel`). All three implementations now use the same precompiled
  standard library. Under the Tarver hybrid, SBCL/CLISP loaded Tarver's StLib
  sources while ECL used a grafted 41.2 `stlib.kl`.

Namespaces, type annotations, and programmable patterns are bundled. Their
canonical extension tests run through `make test-extensions`.

## Port-upgrade audit (doc/port-upgrades.md, 42.0 to 42.2)

- **42.0 `update-lambda-table` invalidation.** shen-cl caches no lambda forms
  or arities of its own. `fn`, partial application and dynamic application go
  through the kernel's property store, so the kernel's invalidation applies
  as-is. A redefinition through arity 1, then 0, then 2 matches shen-scheme 0.50.
- **42.1 `shen.macroexpand-h` takes 4 args.** shen-cl's native `macroexpand`
  and `shen.macroexpand-h` fast paths (src/overwrite.lsp) now take and pass
  the handler registry `shen.*source-form-handlers*`. They walk with
  `shen.source-macro-walk`, so source-form handlers still run before ordinary
  macros, and fall back to plain `shen.walk` when no handlers are registered.
- **42.1 `shen.try-parse` / read loop.** shen-cl does not override
  `shen.try-parse`, `shen.read-loop` or the expansion step. It does override
  the character-stream input path. The kernel's `shen.my-read-byte` reads
  character streams via `(string->n (shen.read-unit-string S))`, which cannot
  signal EOF: `""` is not a unit string. shen-cl therefore overrides
  `shen.my-read-byte` to return `-1` at EOF. As a result, `read`/`lineread` on
  input that ends without a newline now parse it, matching shen-scheme 0.50.
  The REPL still exits cleanly at stdin EOF, but first evaluates a final form
  that has no trailing newline.
- **42.2 namespaces.** The bundled `extension-namespaces.kl` comes from the
  pinned 42.2 release and supports evaluated external-symbol expressions.
- **41.3 `input+`.** The port retains the two-place callable function as well
  as the source macro, so `(fn input+)` delegates to `shen.input-h+`.
- **Property store.** `*property-vector*` is a `shen.dict` again, which
  shen-cl maps to a CL hash table using Shen structural equality. The
  `(trap-error (get ..) ..)` to
  `shen-cl.get/or` peephole in `src/compiler.shen` was disabled for Tarver's
  absvector store and is restored. The kernel `hash` is still used unchanged.
- **Removed Tarver shims.** The `shen.repl`→`shen.shen` alias and the no-op
  `shen.initialise`, `shen.toplevel-display-exception` and
  `shen.set-lambda-form-entry` were removed from `src/overwrite.lsp`; 42.2
  defines all of them itself.

The branch integrates pyrex41/shen-cl through commit
`d59bf137863b16ad8b4febee7aa3d81a41599c14`. The additional port fixes,
extensions, and optimizations are applied outside the vendored kernel.
Generated Lisp receives the same accessor optimization used by `eval-kl`.
