{ core, lib }:
/**
  Applies one or more patches to an individual file in a high-speed micro-derivation.

  Streams directly using GNU patch with fallback strip levels (-p1 then -p0).

  # Inputs

  - `file`: Path, string, or flake input pointing to the target file.
  - `patches`: A single patch or list of patches to apply sequentially.
  - `strip`: Strip level for patch paths (default: 1).
  - `pkgs`: Optional custom pkgs instance.
*/
{
  file,
  patches,
  strip ? 1,
  pkgs ? null,
}:
let
  effectiveCore = if pkgs != null then import ./core.nix { inherit pkgs lib; } else core;
  filePath = effectiveCore.pathOf file;
  fileName = baseNameOf (toString filePath);
  patchList = if lib.isList patches then patches else [ patches ];
  patchPaths = map effectiveCore.pathOf patchList;
in
effectiveCore.hostPkgs.runCommandLocal fileName
  {
    nativeBuildInputs = [ effectiveCore.hostPkgs.patch ];
    preferLocalBuild = true;
    allowSubstitutes = false;
  }
  ''
    current="${filePath}"
    step=0

    ${lib.concatMapStringsSep "\n" (p: ''
      next="./step-$step.tmp"
      if ! patch --batch -N -s -p${toString strip} -o "$next" < "${p}" "$current"; then
        echo "Nix_Patcher: -p${toString strip} failed for ${baseNameOf (toString p)}, retrying with -p0..."
        patch --batch -N -s -p0 -o "$next" < "${p}" "$current"
      fi
      current="$next"
      step=$((step + 1))
    '') patchPaths}

    cp "$current" $out
  ''
