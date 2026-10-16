{
  pkgs ? null,
  lib ? if pkgs != null then pkgs.lib else null,
}:
let
  effectiveLib =
    if lib != null then
      lib
    else if pkgs != null then
      pkgs.lib
    else
      (import <nixpkgs> { }).lib;

  mkPatcher =
    customPkgs:
    let
      lib = effectiveLib;
      core = import ./core.nix {
        pkgs = customPkgs;
        inherit lib;
      };
      package = import ./package.nix {
        inherit core lib;
      };
      file = import ./file.nix {
        inherit core lib;
      };
      module = import ./module.nix {
        inherit file core lib;
      };
      tree = import ./tree.nix {
        inherit core lib;
      };
      flake = import ./flake.nix {
        inherit tree lib;
      };
      patch = import ./patch.nix {
        inherit
          package
          file
          tree
          flake
          core
          lib
          ;
      };
    in
    {
      inherit
        package
        file
        module
        tree
        flake
        patch
        ;
      pkg = package;
      forPkgs = mkPatcher;
    };
in
mkPatcher pkgs
