# The systems this flake builds for. Keep this a subset of bun2nix's own
# `systems` input (nix-systems/triplet), which is what decides the systems its
# overlay is instantiated for: anything beyond that needs the input overridden
# too, or `pkgs.bun2nix` simply will not exist.
[
  "x86_64-linux"
  "aarch64-linux"
  "aarch64-darwin"
]
