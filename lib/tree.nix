{ core, lib }:
/**
  Applies patches across an entire directory tree using a Copy-on-Write symlink forest.

  Optimizes evaluation time down to ~1.5s on massive repositories like nixpkgs,
  and avoids multi-hundred megabyte disk duplication.

  # Inputs

  - `src`: The directory, flake input, or path to patch.
  - `patches`: A single patch or list of patches (can be .patch files or full PR trees).
  - `strip`: Strip level for patch paths (default: 1).
  - `pkgs`: Optional custom pkgs instance.
*/
{
  src,
  patches,
  strip ? 1,
  pkgs ? null,
}:
let
  effectiveCore = if pkgs != null then import ./core.nix { inherit pkgs lib; } else core;
  srcPath = effectiveCore.pathOf src;
  dirName = baseNameOf (toString srcPath);
  patchList = if lib.isList patches then patches else [ patches ];
  normalizedPatches = map (
    p:
    if effectiveCore.isDirectory p then
      effectiveCore.normalizePatch {
        baseSrc = srcPath;
        patch = p;
      }
    else
      effectiveCore.pathOf p
  ) patchList;
in
effectiveCore.hostPkgs.runCommandLocal "${dirName}-patched"
  {
    nativeBuildInputs = [
      effectiveCore.hostPkgs.patch
      effectiveCore.hostPkgs.coreutils
    ];
    preferLocalBuild = true;
    allowSubstitutes = false;
  }
  ''
    mkdir -p "$out"
    # 1. Create a tree of symlinks pointing back to original store files
    cp -as "${srcPath}/." "$out/"
    chmod -R +w "$out"

    cd "$out"
    ${lib.concatMapStringsSep "\n" (p: ''
      # 2. Extract files touched by this patch
      files=$(grep -E '^\+\+\+ [ab]/' "${p}" 2>/dev/null | sed -E 's/^\+\+\+ [ab]\///' || true)
      for f in $files; do
        if [ -L "$f" ]; then
          # Break symlink: replace with real writable copy of the original file
          rm "$f"
          if [ -f "${srcPath}/$f" ]; then
            cp "${srcPath}/$f" "$f"
            chmod +w "$f"
          fi
        elif [ ! -e "$f" ]; then
          mkdir -p "$(dirname "$f")"
        fi
      done

      # 3. Apply the patch in non-interactive batch mode
      if ! patch --batch -N -s -p${toString strip} < "${p}"; then
        echo "Nix_Patcher: -p${toString strip} failed for ${baseNameOf (toString p)}, retrying with -p0..."
        patch --batch -N -s -p0 < "${p}"
      fi
    '') normalizedPatches}
  ''
