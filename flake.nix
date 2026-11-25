{
  description = "Nix Patcher";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    systems.url = "github:nix-systems/default";
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = [
        inputs.git-hooks-nix.flakeModule
      ];

      flake = {
        lib = import ./lib {
          inherit (inputs.nixpkgs) lib;
        };
      };

      perSystem =
        {
          config,
          pkgs,
          ...
        }:
        {
          pre-commit.settings.hooks = {
            shfmt.enable = true;
            nixfmt.enable = true;
            shellcheck.enable = true;
            statix.enable = true;
            deadnix.enable = true;
            markdownlint = {
              enable = true;
              excludes = [
                "^LICENSE\\.md$"
                "^\\.github/.*"
              ];
              settings.configuration = {
                MD013 = false;
                MD024 = {
                  siblings_only = true;
                };
              };
            };
          };

          checks = {
            tests = (import ./test { inherit pkgs; }).check;
          };

          devShells.default = config.pre-commit.devShell;
        };
    };
}
