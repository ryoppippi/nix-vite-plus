# vp-overlay

i'm too lazy to manage all dependencies. just download binary and execute it.

# How to use

## Run directly

```sh
nix run github:ryoppippi/vp-overlay -- --help
```

## Add to your flake.nix

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    vp-overlay.url = "github:ryoppippi/vp-overlay";
  };

  outputs = { nixpkgs, vp-overlay, ... }:
    let
      pkgs = import nixpkgs {
        system = "aarch64-darwin"; # change to your system
        overlays = [ vp-overlay.overlays.default ];
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
