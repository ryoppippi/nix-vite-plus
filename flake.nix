{
  description = "Vite+ (vp) CLI binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs (import ./nix/systems.nix);
    in
    {
      packages = forAllSystems (system: {
        vp = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
        default = self.packages.${system}.vp;
      });

      overlays.default = _final: prev: {
        vite-plus = self.packages.${prev.stdenv.hostPlatform.system}.vp;
      };
    };
}
