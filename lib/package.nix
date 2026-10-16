{ core, lib }:
/**
  Applies one or more patches to a software package derivation via `overrideAttrs`.

  Executes during the build phase (Phase 2), incurring zero evaluation-time IFD
  when given standard patch files.

  # Inputs

  - `pkg`: The package derivation to patch (must support `overrideAttrs`).
  - `patches`: A list of patches (paths, flake inputs, or full PR trees).
*/
{
  pkg,
  patches,
  pkgs ? null,
}:
let
  effectiveCore = if pkgs != null then import ./core.nix { inherit pkgs lib; } else core;
  patchList = if lib.isList patches then patches else [ patches ];
  normalizedPatches = map (
    p:
    if effectiveCore.isDirectory p then
      effectiveCore.normalizePatch {
        baseSrc = pkg.src;
        patch = p;
      }
    else
      effectiveCore.pathOf p
  ) patchList;
in
pkg.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ normalizedPatches;
})
