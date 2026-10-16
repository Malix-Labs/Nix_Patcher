{
  tree,
  lib,
}:
/**
  Applies patches to a Flake input and evaluates its outputs in pure mode.

  Re-hydrates the flake outputs without requiring `--impure` or `builtins.getFlake`.

  # Inputs

  - `flake`: The input flake (attribute set with outPath, path, or string).
  - `patches`: A single patch or list of patches to apply.
  - `inputs`: Optional attribute set of inputs to pass to the flake's `outputs` function.
  - `strip`: Strip level for patch paths (default: 1).
  - `pkgs`: Optional custom pkgs instance.
*/
{
  flake,
  patches,
  inputs ? { },
  strip ? 1,
  pkgs ? null,
}:
let
  patchedTree = tree {
    src = flake;
    inherit patches strip pkgs;
  };
  flakeExpr = import (patchedTree + "/flake.nix");
  resolvedSelf = flakeExpr.outputs ({ self = resolvedSelf; } // inputs);
in
if lib.isAttrs resolvedSelf then resolvedSelf // { outPath = patchedTree; } else resolvedSelf
