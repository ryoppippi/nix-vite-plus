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
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
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
