# The systems this flake builds for. bun2nix takes this as its `systems` input
# and `import`s it, so it has to evaluate to a bare list of system strings.
[
  "x86_64-linux"
  "aarch64-linux"
  "x86_64-darwin"
  "aarch64-darwin"
]
