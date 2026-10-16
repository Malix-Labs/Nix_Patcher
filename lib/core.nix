{
  pkgs ? null,
  lib,
}:
let
  hostPkgs = if pkgs != null then (pkgs.buildPackages or pkgs) else null;

  getHostPkgs =
    if hostPkgs != null then
      hostPkgs
    else
      throw "Nix_Patcher: 'pkgs' must be provided to build derivations. Please use 'patcher.forPkgs pkgs' or pass 'pkgs' to the patch function.";
in
rec {
  hostPkgs = getHostPkgs;

  /**
    Detects if a path, string, or flake input is a directory.
  */
  isDirectory =
    p:
    let
      targetPath =
        if lib.isAttrs p && p ? outPath then
          p.outPath
        else if lib.isPath p then
          p
        else if lib.isString p then
          p
        else
          null;
    in
    if targetPath != null then builtins.pathExists (targetPath + "/.") else false;

  /**
    Extracts the filesystem path from an input (string, path, or flake input attrset).
  */
  pathOf =
    p:
    if lib.isAttrs p && p ? outPath then
      p.outPath
    else if lib.isPath p then
      p
    else if lib.isString p then
      p
    else
      throw "Nix_Patcher: Expected a path, string, or flake input, got ${builtins.typeOf p}";

  /**
    Normalizes a patch input.
    If the patch is a raw file, returns its path directly.
    If the patch is an entire directory tree (e.g. a full PR branch),
    generates a unified diff with standard a/ and b/ headers against baseSrc using `diff -ruN`.
  */
  normalizePatch =
    { baseSrc, patch }:
    let
      patchPath = pathOf patch;
      basePath = pathOf baseSrc;
    in
    if isDirectory patch then
      hostPkgs.runCommandLocal "generated-tree.patch"
        {
          nativeBuildInputs = [
            hostPkgs.diffutils
            hostPkgs.gnused
          ];
          preferLocalBuild = true;
          allowSubstitutes = false;
        }
        ''
          diff -ruN "${basePath}" "${patchPath}" | \
            sed -E "s|^\-\-\- ${basePath}/?|--- a/|" | \
            sed -E "s|^\+\+\+ ${patchPath}/?|+++ b/|" > $out || true
        ''
    else
      patchPath;
}
