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
| `spicerack` | `github:OmarSiwy/SpiceRack` | built here — nothing else caches it |
| `espice` | `github:OmarSiwy/ESPice` | built here — nothing else caches it |
| `vera` | `github:OmarSiwy/VerA` | built here — nothing else caches it |
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
nothing else caches them, which is the same reason the tools above are here. VACASK
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
    eda.packages.${system}.spicerack
    eda.packages.${system}.espice
    eda.packages.${system}.vera
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

## The two Verilog-A stacks

They run side by side rather than one replacing the other:

- **openvaf -> vacask** — works today. OpenVAF compiles `.va` to `.osdi`, VACASK loads it.
- **vera -> espice** — the Zig path. ESPice compiles all 39 of its device models from
  Verilog-A with VerA at build time. Usable, but pre-release: 26 of 616 fixtures disagree
  with ngspice and its own suite scores 492-518/616 run to run. Available, not a default.

`espice` is built CPU-only and statically linked (`-Dgpu=false`), so it carries no
CUDA/ROCm closure. Kernel work belongs in ESPice's own `nix develop`.
