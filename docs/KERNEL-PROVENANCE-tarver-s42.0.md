# Kernel provenance: Tarver S42.0

> **Historical.** This lineage was superseded by the community ShenOSKernel
> 42.2 release (adopted wholesale). See
> [KERNEL-PROVENANCE-42.2.md](KERNEL-PROVENANCE-42.2.md). The build tooling
> described below (`scripts/assemble-tarver-kernel.sh`) was removed, and
> remains available in git history.

This branch assembles the Shen 42.0 kernel released by Mark Tarver as
`S42.zip` (official URL: <https://www.shenlanguage.org/Download/S42.zip>).

| Field | Value |
|---|---|
| Archive SHA-256 | `30abdc7e5a1e27b7a20109c1ed141e4712885e31f24d9710d16415fbbd4dfb23` |
| Last-Modified | 2026-08-25 |
| Immutable mirror tag | `s42-pristine-20260825` |

The archive contains the 15-file `S42/KLambda` reference kernel and Tarver's
standard library. As with S41.2, shen-cl builds a hybrid: these KLambda files
and StLib sources come from Tarver, while launcher/features/expand-dynamic,
ECL's precompiled `stlib.kl`, and certification tests are grafted from the
community ShenOSKernel-41.2 release until community S42 extensions are
published. The assembly script verifies the archive hash and keeps the
community graft version explicit.

The S42 archive reports `(version)` as `42`; this is the value used by the
CLI parity tests. Run `make fetch`, `make precompile SHEN=...`, and
`make build-sbcl` to regenerate local ignored kernel/compiled artifacts.
