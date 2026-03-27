# nix-vite-plus

i'm too lazy to manage all dependencies. just download binary and execute it.

# How to use

## Run directly

```sh
nix run github:ryoppippi/nix-vite-plus -- --help
```

## Use as a package

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-vite-plus.url = "github:ryoppippi/nix-vite-plus";
  };

  outputs = { nixpkgs, nix-vite-plus, ... }:
    let
      system = "aarch64-darwin"; # change to your system
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ nix-vite-plus.packages.${system}.vp ];
      };
    };
}
```

## Use as an overlay

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-vite-plus.url = "github:ryoppippi/nix-vite-plus";
  };

  outputs = { nixpkgs, nix-vite-plus, ... }:
    let
      pkgs = import nixpkgs {
        system = "aarch64-darwin"; # change to your system
        overlays = [ nix-vite-plus.overlays.default ];
      };
    in
    {
      # `vite-plus` is now available in pkgs
      devShells.default = pkgs.mkShell {
        packages = [ pkgs.vite-plus ];
      };
    };
}
```
