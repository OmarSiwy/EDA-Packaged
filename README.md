# EDA-Packaged

Prebuilt EDA tools for the UW-ASIC design template, so that `./env.sh` is a download
instead of a Rust and Zig compile.

```bash
cachix use omarsiwy
```

That one line is the point of this repo.

## What is here, and what is deliberately not

| tool | where it comes from | why |
|------|--------------------|-----|
| `cktimg` | `github:OmarSiwy/cktImg` | built here — nothing else caches it |
| `despice` | `github:OmarSiwy/PySpice` | built here — nothing else caches it |
| `openvaf` | `github:arpadbuermen/OpenVAF` | built here — not in nixpkgs |
| `vacask` | `github:robtaylor/VACASK` | built here — not in nixpkgs |
| `netgen` | `github:efabless/nix-eda` | re-exported, already prebuilt upstream |

Everything else the template needs — xschem, klayout, ngspice, libngspice, magic-vlsi —
is in nixpkgs and already served by `cache.nixos.org`. Adding them here would mean
rebuilding and re-hosting binaries that Hydra has already built, which is worse than
doing nothing.

**netgen is re-exported rather than rebuilt.** nixpkgs has no VLSI netgen under any
attribute: `nixpkgs.netgen` is a 3D tetrahedral mesh generator from ngsolve.org and shares
nothing with the LVS tool but a name. efabless packages the real one in `nix-eda` and
publishes it to `openlane.cachix.org`, so pinning theirs costs a download and maintaining
our own would cost a derivation that goes stale. (An earlier attempt at exactly that got
as far as a binary that built cleanly and then died on a missing `tclnetgen.so`, because
netgen's Makefile pipes its build through `tee` and reports *tee's* exit status.)

**openvaf and vacask are built from source on every platform.** Neither is in nixpkgs and
nothing else caches them, which is the same reason `cktimg` and `despice` are here. VACASK
compiles its device models with OpenVAF, so the two are always built as a pair. Unlike the
flake inputs they are pinned by revision inside `nix/openvaf.nix` and `nix/vacask.nix` — a
bump is an edit to the `rev`/`hash` in those files, which `update.yml` does not do for you.

## Usage

```nix
{
  inputs.eda.url = "github:OmarSiwy/EDA-Packaged";

  # ...
  packages = [
    eda.packages.${system}.cktimg
    eda.packages.${system}.despice
    eda.packages.${system}.netgen
    eda.packages.${system}.openvaf
    eda.packages.${system}.vacask
  ];
}
```

Or directly:

```bash
nix build github:OmarSiwy/EDA-Packaged#cktimg
nix run  github:OmarSiwy/EDA-Packaged#cktimg -- --help
```

## Maintenance

Inputs are pinned in `flake.lock`, which means **a commit to cktImg or DeSpice does not
reach anyone until the lock moves.** That is the cost of a hub repo. `update.yml` bumps
the lock nightly and opens a PR; merging it rebuilds and repopulates the cache. To pull a
change through immediately:

```bash
nix flake update
git commit -am "chore: bump flake inputs" && git push
```

`build.yml` builds every package on Linux and macOS, smoke-tests each one, and pushes to
cachix. The smoke test exists because a package that builds but does not *run* is the
failure this repo would otherwise hand to everybody at once.

## Setup checklist

- [x] Create the `omarsiwy` cache at https://app.cachix.org
- [x] Add `CACHIX_AUTH_TOKEN` to this repo's Actions secrets
- [x] Push `cktImg` with `src/json_main.zig`

## Known gap

`despice` ships `pyspice_rs` but **not** the `testbenches` package — maturin only installs
the module named by `module-name`, so the other top-level package under `python-source`
is dropped. `from testbenches import ...` therefore fails against this build and needs a
DeSpice source checkout. Moving `python/testbenches` under `python/pyspice_rs/` upstream
would ship it as a subpackage and close this.
