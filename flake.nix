{
  description = "Prebuilt EDA tools for the UW-ASIC design template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";

    # VLSI netgen lives here. nixpkgs has no VLSI netgen under any attribute —
    # `nixpkgs.netgen` is a 3D tetrahedral mesh generator from ngsolve.org that shares
    # nothing with the LVS tool but a name. efabless already publishes netgen binaries to
    # openlane.cachix.org, so this repo re-exports rather than rebuilds it.
    nix-eda.url = "github:efabless/nix-eda";

    # The tools nothing else caches. These are the whole reason this repo exists:
    # everything else the template needs is already prebuilt somewhere public.
    #
    # SpiceRack was called PySpice until the rename; the module is `spicerack` now and
    # `testbenches` moved under it as a subpackage.
    spicerack.url = "github:OmarSiwy/SpiceRack";
    cktimg.url = "github:OmarSiwy/cktImg";
    # The Zig Verilog-A stack: VerA compiles Verilog-A, ESPice simulates it (no OSDI).
    # openvaf+vacask below is the OSDI stack, installed alongside it.
    # Both build CPU-only — ESPice's CUDA/HIP support is dev-shell only.
    espice.url = "github:OmarSiwy/ESPice";
    vera.url = "github:OmarSiwy/VerA";
    # Analog place-and-route. Bundles GPurify (a git dependency) for in-loop DRC/LVS.
    philis.url = "github:UW-ASIC/Philis";
    # gm/ID characterisation library (libGmIDVisualizer.so, loaded by ctypes via
    # GMID_LIB by AnalogIOC analog/docs/gmid.py).
    gmidvisualizer.url = "github:OmarSiwy/GmIDVisualizer";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      nix-eda,
      spicerack,
      cktimg,
      espice,
      vera,
      philis,
      gmidvisualizer,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        openvaf = import ./nix/openvaf.nix { inherit pkgs; };
        # VACASK compiles its device models with OpenVAF, so the two are always built
        # as a pair.
        vacask = import ./nix/vacask.nix {
          inherit pkgs openvaf;
        };
        # ASAP7 PDK root: models for ESPice (.hdl BSIM-CMG) and ngspice (OSDI), tech, DRM.
        asap7 = import ./nix/asap7.nix { inherit pkgs openvaf; };
        # x86_64-linux only: GmIDVisualizer's flake hardcodes that system, so on any other
        # this is null and the package is simply absent rather than an eval error in `all`.
        gmid = gmidvisualizer.packages.${system}.default or null;

        # VerA's own flake passes `--global-cache-dir`, which Zig 0.17's `zig build`
        # dropped, and leaves HOME at the sandbox's unwritable /homeless-shelter, so it
        # does not build as published; the same build, with the cache named by the
        # environment. ponytail: drop once VerA's flake does this itself.
        veraPkg = vera.packages.${system}.default.overrideAttrs (_: {
          buildPhase = ''
            runHook preBuild
            export HOME="$TMPDIR" ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
            zig build -Doptimize=ReleaseSafe --cache-dir .zig-cache
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            export HOME="$TMPDIR" ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
            zig build install -Doptimize=ReleaseSafe --prefix "$out" --cache-dir .zig-cache
            runHook postInstall
          '';
        });
      in
      {
        packages = {
          inherit openvaf vacask asap7;

          # Built by CI and pushed to cachix.
          spicerack = spicerack.packages.${system}.default;
          cktimg = cktimg.packages.${system}.default;
          vera = veraPkg;
          # CPU-only and statically linked — ESPice's flake builds -Dgpu=false for the
          # packaged binary, so this carries no CUDA/ROCm closure. Wrapped with ZIG for
          # `.hdl` models, whose builds cache under $ESPICE_CACHE / ~/.cache/espice.
          espice = espice.packages.${system}.default;
          # Also CPU-only; its `gpu` feature is opt-in. Ships bin/philis plus the rule
          # decks under share/philis/pdks, which `philis run` requires as an argument.
          philis = philis.packages.${system}.default;

          # Re-exported, not rebuilt. Pinning it here means the template takes one flake
          # input instead of two, and gets a netgen that is known to work with the rest.
          netgen = nix-eda.packages.${system}.netgen;

          # Everything at once, so CI is `nix build .#all` and the cache push picks up
          # the whole closure in one go.
          all = pkgs.symlinkJoin {
            name = "eda-packaged-all";
            paths = [
              spicerack.packages.${system}.default
              cktimg.packages.${system}.default
              veraPkg
              espice.packages.${system}.default
              philis.packages.${system}.default
              nix-eda.packages.${system}.netgen
              openvaf
              vacask
              asap7
            ]
            ++ pkgs.lib.optional (gmid != null) gmid;
          };
        }
        # lib/libGmIDVisualizer.so + headers + bin/gmid_runner.
        // pkgs.lib.optionalAttrs (gmid != null) { gmidvisualizer = gmid; };
      }
    );
}
