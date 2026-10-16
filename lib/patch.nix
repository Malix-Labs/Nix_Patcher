{
  package,
  file,
  tree,
  flake,
  core,
  lib,
}:
/**
  Polymorphic dispatcher that automatically selects the appropriate patcher
  based on the target type:
  - If `target ? overrideAttrs && target ? src` -> delegates to `lib.package` (0 ms, non-IFD)
  - If `target ? outputs && target ? outPath` -> delegates to `lib.flake`
  - If `target` is a single file (not a directory) -> delegates to `lib.file`
  - Otherwise -> delegates to `lib.tree`

  # Inputs

  - `target`: The entity to patch (package, file, directory, or flake).
  - `patches`: The patch or patches to apply.
  - Remaining arguments forwarded to the underlying patcher.
*/
{
  target,
  patches,
  ...
}@args:
let
  forwardArgs = builtins.removeAttrs args [ "target" ];
  isPackage = lib.isAttrs target && (target ? overrideAttrs) && (target ? src || target ? srcs);
  isFlake =
    lib.isAttrs target
    && (
      (target ? _type && target._type == "flake")
      || (target ? outputs && (builtins.isAttrs target.outputs || builtins.isFunction target.outputs))
    );
in
if isPackage then
  package (
    forwardArgs
    // {
      pkg = target;
      inherit patches;
    }
  )
else if isFlake then
  flake (
    forwardArgs
    // {
      flake = target;
      inherit patches;
    }
  )
else if !core.isDirectory target then
  file (
    forwardArgs
    // {
      file = target;
      inherit patches;
    }
  )
else
  tree (
    forwardArgs
    // {
      src = target;
      inherit patches;
    }
  )
