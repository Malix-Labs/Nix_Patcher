{
  file,
  core,
  lib,
}:
/**
  Patches a NixOS, Home Manager, or nix-darwin module and returns a self-contained
  module specification with `disabledModules` and `imports`.

  # Inputs

  - `module`: The relative module path to disable and patch (e.g. "services/web-servers/caddy/default.nix").
  - `patches`: One or more patches to apply to the module.
  - `src`: The repository containing the module (e.g. `nixpkgs`, `inputs.home-manager`, `inputs.darwin`).
  - `type`: Module system flavor: "nixos" (default), "home-manager", or "darwin".
  - `strip`: Strip level for patch paths (default: 1).
  - `pkgs`: Optional custom pkgs instance.
*/
{
  module,
  patches,
  src ? null,
  type ? "nixos",
  strip ? 1,
  pkgs ? null,
}:
let
  effectiveCore = if pkgs != null then import ./core.nix { inherit pkgs lib; } else core;
  resolvedSourcePath =
    if src == null then
      effectiveCore.pathOf module
    else
      let
        base = effectiveCore.pathOf src;
      in
      if type == "nixos" then
        "${base}/nixos/modules/${module}"
      else if type == "home-manager" || type == "darwin" then
        "${base}/modules/${module}"
      else
        "${base}/${module}";

  patchedFile = file {
    file = resolvedSourcePath;
    inherit patches strip pkgs;
  };
in
{
  disabledModules = [ module ];
  # Ensure the derivation is imported as a store path string
  imports = [ "${patchedFile}" ];
}
