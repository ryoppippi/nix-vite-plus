{
  description = "Vite+ (vp) CLI binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      bun2nix,
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs (import ./nix/systems.nix);
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
