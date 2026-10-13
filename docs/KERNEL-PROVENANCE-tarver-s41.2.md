# Kernel provenance: Tarver S41.2 (2026-07-11 refresh)

## What this is

Mark Tarver re-uploaded a **restructured** kernel under the **same "41.2"
version number** to shenlanguage.org. This is a different distribution and
lineage from the community `ShenOSKernel-41.2`
(github.com/Shen-Language/shen-sources, tag `shen-41.2`) that shen-cl has
historically built from. To avoid confusion we refer to it as
**"S41.2 (2026-07-11 refresh)"**.

**Canonical source: the `pyrex41/shen-s41.1` mirror.** Because Tarver
re-uploads to shenlanguage.org in place (same name, same version string), the
authoritative pinned copy is the private mirror repo, which imports each upload
under a dated tag:

| | value |
|---|---|
| Canonical mirror | `pyrex41/shen-s41.1` (local: `/Users/reuben/projects/shen/shen-s41.1`) |
| Tag | `s41.2-pristine-20260711` |
| Commit | `11fc51b` (master) |
| Secondary URL | https://www.shenlanguage.org/Download/S41.2.zip |
| Last-Modified | 2026-07-11 |
| sha256 | `51becbfd60fa8c93c3f8ae5b20b948eaa84c4b1d14ad2f5d2a056002a53ee836` |

> Caveat: the shenlanguage.org URL is re-uploaded in place under the same name
> and version number; the sha256 pins the 2026-07-11 revision but a future
> re-upload changes the hash without changing the version string. Cite the
> mirror tag, not the URL, for reproducibility. The mirror also shows Tarver's
> S-lineage has shipped the 15-file KLambda layout (backend.kl included) since
> 41.1, so his `install.lsp` path is proven on this shape.

> The kernel itself is proven sound independently of this port: the shen-swift
> stage-2 target boots all 15 KLambda files on its KL interpreter
> (`*version*` = "41.2", 12/12 tests), and the yggdrasil shake of it works
> cross-lineage on the community-41.2 shen-cl host. Treat any *build* failure of
> this integration as harness/lineage-fit, not a kernel defect.

## How Tarver's refresh differs from community 41.2

Tarver's distribution ships `KLambda/` (uppercase), `Primitives/`, `Lib/`,
and root `install.lsp` + `backend.lsp` for a **direct SBCL install** (his new
`cl.*` KL->CommonLisp backend now lives inside the kernel as `backend.kl`,
replacing shen-cl's `compiler.shen` role). Its `KLambda/` set is 15 files:
`backend, core, declarations, load, macros, prolog, reader, sequent, sys,
t-star, toplevel, track, types, writer, yacc`.

**Removed vs community 41.2**: `compiler.kl` (shen-cl generates its own),
`dict.kl`, `init.kl`, `stlib.kl`, and every `extension-*.kl` (including the
launcher CLI shen-cl/yggdrasil depend on). Notable renames/moves:
`hush -> shen.hush`, `input+ -> shen.input-h+/shen.process-input+`,
`shen.initialise-lambda-forms -> shen.initialise-lambda-tables`, the REPL
entry `shen.repl -> shen.shen`, and the global property store moved from a
dict layer to a bucketed absvector `*property-vector*` with vector-based
`put`/`get`.

## Standalone canary (independent of shen-cl)

Tarver's own `install.lsp` was run under macOS SBCL 2.6.2 (feeding y/n:
stdlib=yes, concurrency/Tk/THORN/LogicLab=no). **Result: it builds and boots.**
It produced `sbcl-shen.exe`, `(+ 2 3)` = 5, `(version)` = "41.2", the standard
library typechecks and loads. (It loops on stdin EOF -- the long-standing
`shen.shen` behaviour, unrelated to the build.)

**Is the canary image usable as a yggdrasil stage-1 host?** Not as-is. Its
saved toplevel is `shen.shen` (an interactive REPL). Piping
`(load "f.shen")` + an expression over stdin does evaluate correctly
(`(sq 9)` = 81), but the stock image (a) has no non-interactive launcher CLI
(`eval -l file -e expr`), (b) has no `cl.exit`, so it cannot exit
programmatically, and (c) loops forever in `shen.loop` at stdin EOF and then
aborts. The proper same-lineage stage-1 host is **this shen-cl S41.2 build**,
which adds the launcher CLI (`eval -q -l file -e expr`, verified) and clean EOF
exit on top of the same refreshed kernel.

## How shen-cl consumes it (hybrid)

shen-cl cannot use Tarver's distribution wholesale: its harness needs the
launcher, features and expand-dynamic extensions, which the refresh dropped.
`scripts/assemble-tarver-kernel.sh` builds a hybrid `kernel/`:

- **14 shared KLambda files** (core, declarations, load, macros, prolog,
  reader, sequent, sys, t-star, toplevel, track, types, writer, yacc) — from
  **Tarver's refresh**.
- **extension-features, extension-expand-dynamic, extension-launcher** — kept
  from the **community `shen-41.2`** release. The launcher is deliberate:
  Tarver's distribution ships no non-interactive CLI, and yggdrasil stage-1
  depends on `eval -l file -e expr`.
- **StLib (standard library)** — Tarver's **canonical StLib sources** (mirror
  `pyrex41/shen-upstream`, tag `s41.2-pristine-20260711`, `Lib/StLib`), copied
  to `kernel/lib/StLib`. SBCL and CLISP install it from source at build time by
  running `install.shen` through the freshly built image (typecheck + load),
  which the saved image then bakes in — exactly as Tarver's own `install.lsp`
  does. The former community `stlib.kl` graft is retired on these two hosts.
- **stlib.kl (community graft) — ECL ONLY.** ECL builds via `c:build-program`,
  which links object files rather than dumping an image, so it cannot bake the
  runtime state produced by loading StLib sources; and loading them at startup
  costs ~105s (ECL C-compiles each definition on load). So ECL alone keeps the
  precompiled community `stlib.kl`, imported under `#+ecl` in `boot.lsp` and
  replayed cheaply at startup. This is the one stdlib divergence across
  implementations; retiring it needs a StLib->`.lsp` packager (fleet follow-up).
- **tests/, extensions/** — community (language-agnostic Shen).
- **dropped**: `dict.kl` (shen-cl uses native hash-table dicts),
  `init.kl` (the refresh folds its work into `declarations.kl` load-time
  forms), `compiler.kl` (generated by `make precompile`).

### What Tarver's `install.shen` does (and what we adopted)

`Lib/StLib/install.shen` is a Shen script that `cd`s into the StLib directory
and loads each module in a precise order, toggling `(tc +/-)` (type checking)
and `(factorise +/-)` around the files that need it: Symbols, then Maths
(macros, maths, rationals/complex/numerals with their `.dtype` datatype files),
Lists, Strings (+ smart), Vectors macros, IO (prettyprint/files), Tuples. It
then loads `package-stlib.shen` (which defines the `stlib` package as the union
of the module externals) and declares every external stlib function as a system
function via `(map (fn systemf) ...)`, finishing with `(preclude-all-but [])`
and `(cd "")`. shen-cl's `boot.lsp` adopts it verbatim: `(cd "kernel/lib/StLib")`,
`(load "install.shen")`, `(cd "")`. Its native load order already puts the Maths
datatypes before `Vectors/macros.shen`, so the `':='` vector-macro-vs-typechecker
hazard that forced a custom ordering under the community stlib is avoided by
construction.

The shen-cl `src/` side was adapted for the refresh (see
`src/overwrite.lsp`, `src/compiler.shen`, `boot.lsp`, `scripts/build.shen`):
the `get -> shen-cl.get/or` peephole was disabled (it assumed a hash-table
property store), the `hash` override was removed (the vector store buckets by
the kernel `hash`), boot load order was aligned to Tarver's `install.lsp`, and
four dropped-`init.kl` functions are shimmed: `shen.repl` (aliased to
`shen.shen`), a no-op `shen.initialise`, `shen.set-lambda-form-entry`, and
`shen.toplevel-display-exception`.

**Load order: read `install.lsp`, not `make.shen`.** The refreshed `types.kl`
runs ~161 top-level `(declare ..)` forms at load that invoke the typechecker;
they need globals set by `declarations.kl`, macro machinery from `macros.kl`,
and `shen.rectify-type` (moved into `t-star.kl`). So `declarations` must
precede `types`, and `t-star` must also precede `types`. `make.shen` gives the
`.shen` *compile* order, which is NOT a valid `.kl` *load* order. Tarver's
`install.lsp` is the authoritative runtime loader; `boot.lsp` now follows it
(`sys writer core reader declarations toplevel macros load prolog sequent track
t-star yacc types`, declarations 5th, types last). This is single-pass and
needs no two-phase boot (independently confirmed green by shen-rust
pyrex41/shen-rust#9 and shen-lua pyrex41/shen-lua#36).

## Status (macOS, arm64)

Per-implementation, building the same hybrid kernel + `compiled/*.lsp`:

| Implementation | Build | Kernel suite | StLib source | stlib fns + launcher |
|---|---|---|---|---|
| SBCL 2.6.2 | pass | 134/134 | Tarver source (baked) | `factorial`/`take`/`uppercase`, `eval -e`/`-q -l -e`, REPL, clean EOF |
| GNU CLISP 2.49.92 | pass | 134/134 | Tarver source (baked) | `factorial`/`take`/`uppercase`, `eval -l file -e expr` (clisp `-q` note) |
| ECL 26.5.5 | pass | 134/134 | community `stlib.kl` graft | `factorial`/`take`, `eval -e`/`-l -e`; ~1.5s startup |
| CCL | out of scope | — | — | no native Apple-Silicon build (see yggdrasil README) |

Notes:
- Compiler golden tests: pre-existing drift on master (`1+`/`EQUALP` mismatches
  and a `let-NIL` crash reproduce identically on the community-41.1 binary),
  unrelated to this change; the `get/or` assertion was updated for the disabled
  peephole.
- clisp intercepts a bare `-q` in its own runtime arg parser (clisp has a native
  `-q`), so `eval -q ...` swallows the result there; `eval -l file -e expr`
  works. Unrelated to the kernel refresh; yggdrasil uses SBCL as host.

## Verified as yggdrasil's stage-1 host

Using this branch's SBCL binary as `$YGGDRASIL_HOST`,
`yggdrasil shake tests/fib.shen` produces `kernel.kl` = **54 defuns / 13.4 KB**
(the documented figure) plus `fib.kl` + manifest
(`kernel-version=41.2-s41r.20260711`). `kernel.kl` is **byte-identical** to the
pre-StLib-change host (the shake slice is host-stdlib-independent), and the
shake is deterministic across runs. The user `<prog>.kl` differs only in gensym
variable numbering (the StLib source install consumes more gensyms before
shake); this is a variable rename, semantically identical, and consistent with
the fleet's "byte-identical kernel.kl + portable user KL" contract. This is the
designated same-lineage stage-1 host of record.

## Known remaining work

- **ECL StLib from source**: build a StLib -> `.lsp` packager so ECL can bake
  Tarver's StLib (like SBCL/CLISP) instead of the community `stlib.kl` graft.
  ECL's `c:build-program` cannot bake image-loaded state, and per-launch source
  install costs ~105s, so a precompiled artifact is required. This is the one
  remaining stdlib divergence; a coordinated fleet-wide follow-up.
- Decide whether to vendor the assembled kernel in-tree (Tarver's upstream is
  re-uploaded in place and unversioned) rather than fetch it.

## Upstream StLib source observations (Tarver bug-report material)

No patches were needed: Tarver's `Lib/StLib` sources load and typecheck cleanly
on shen-cl under SBCL and CLISP as-is (via his `install.shen`). Nothing to
report upstream from this pass.
