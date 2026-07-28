# bun2nix is not in nixpkgs, so `pkgs` cannot supply it on its own: either
# apply `bun2nix.overlays.default` to `pkgs` or pass `bun2nix` explicitly.
{
  pkgs,
  bun2nix ? pkgs.bun2nix,
  ...
}:
pkgs.callPackage ./package.nix { inherit bun2nix; }
