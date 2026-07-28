{
  description = "Vite+ (vp) CLI binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # bun2nix only instantiates its overlay for the systems of this input, and
    # its own default omits x86_64-darwin.
    systems.url = "github:nix-systems/default";

    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      bun2nix,
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ bun2nix.overlays.default ];
          };
        in
        {
          vp = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.vp;
        }
      );

      overlays.default = _final: prev: {
        vite-plus = self.packages.${prev.stdenv.hostPlatform.system}.vp;
      };
    };
}
