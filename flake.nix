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

    # The two tools nothing else caches. These are the whole reason this repo exists:
    # everything else the template needs is already prebuilt somewhere public.
    cktimg.url = "github:OmarSiwy/cktImg";
    despice.url = "github:OmarSiwy/PySpice";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      nix-eda,
      cktimg,
      despice,
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
      in
      {
        packages = {
          inherit openvaf vacask;

          # Built by CI and pushed to cachix.
          cktimg = cktimg.packages.${system}.default;
          despice = despice.packages.${system}.default;

          # Re-exported, not rebuilt. Pinning it here means the template takes one flake
          # input instead of two, and gets a netgen that is known to work with the rest.
          netgen = nix-eda.packages.${system}.netgen;

          # Everything at once, so CI is `nix build .#all` and the cache push picks up
          # the whole closure in one go.
          all = pkgs.symlinkJoin {
            name = "eda-packaged-all";
            paths = [
              cktimg.packages.${system}.default
              despice.packages.${system}.default
              nix-eda.packages.${system}.netgen
              openvaf
              vacask
            ];
          };
        };
      }
    );
}
