{
  description = "Development environment for nix-vite-plus";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        {
          config,
          pkgs,
          ...
        }:
        {
          treefmt = {
            projectRootFile = ".git/config";
            programs = {
              nixfmt.enable = true;
              deadnix.enable = true;
              statix.enable = true;
              typos.enable = true;
              oxfmt.enable = true;
            };
          };

          pre-commit.settings = {
            src = ./..;
            package = pkgs.prek;
            hooks = {
              treefmt = {
                enable = true;
                package = config.treefmt.build.wrapper;
              };
              gitleaks = {
                enable = true;
                name = "gitleaks";
                entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged --config ${./..}/.gitleaks.toml";
                language = "system";
                pass_filenames = false;
              };
            };
          };

          packages = {
            inherit (pkgs) typos typos-lsp;
          };

          devShells.default = pkgs.mkShellNoCC {
            inherit (config.pre-commit) shellHook;
            packages = [
              config.packages.typos
              config.packages.typos-lsp
              pkgs.gitleaks
            ];
          };
        };
    };
}
