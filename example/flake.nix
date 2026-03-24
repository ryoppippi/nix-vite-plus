{
  description = "Example project using vp-overlay";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    vp-overlay.url = "github:ryoppippi/vp-overlay";
  };

  outputs =
    {
      nixpkgs,
      vp-overlay,
      ...
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
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ vp-overlay.overlays.default ];
          };
        in
        {
          default = pkgs.mkShell {
            packages = [ pkgs.vite-plus ];
          };
        }
      );
    };
}
