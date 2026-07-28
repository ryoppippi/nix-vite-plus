{
  description = "Vite+ (vp) CLI binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # bun2nix only instantiates its overlay for the systems of this input, and
    # its own default omits x86_64-darwin.
    systems = {
      url = "path:./nix/systems.nix";
      flake = false;
    };

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
      bun2nix,
      # `systems` is only here to be followed into bun2nix
      ...
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
