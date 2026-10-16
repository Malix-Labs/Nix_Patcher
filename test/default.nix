{
  pkgs ? (import <nixpkgs> { }),
  patcher ? (import ../lib { inherit pkgs; }),
}:
let
  inherit (pkgs) lib;

  suites = {
    package = import ./package.nix { inherit pkgs patcher; };
    file = import ./file.nix { inherit pkgs patcher; };
    module = import ./module.nix { inherit pkgs patcher; };
    tree = import ./tree.nix { inherit pkgs patcher; };
    flake = import ./flake.nix { inherit pkgs patcher; };
    polymorphic = import ./polymorphic.nix { inherit pkgs patcher; };
  };

  # Check that all assertions in all suites evaluate to "pass"
  allPassing = lib.all (suite: lib.all (v: v == "pass") (lib.attrValues suite)) (
    lib.attrValues suites
  );

  checkDrv =
    assert allPassing;
    pkgs.runCommandLocal "nix-patcher-tests" { } ''
      echo "All tests passed successfully!" > $out
    '';
in
suites
// {
  check = checkDrv;
}
