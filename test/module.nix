{ pkgs, patcher }:
let
  mockRepo = pkgs.runCommandLocal "mock-nixos-repo" { } ''
    mkdir -p $out/nixos/modules/services/web-servers/caddy
    cat << 'MODULE' > $out/nixos/modules/services/web-servers/caddy/default.nix
    { config, lib, ... }:
    {
      options.services.caddy.greeting = lib.mkOption {
        type = lib.types.str;
        default = "original";
      };
    }
    MODULE
  '';

  modulePatch = pkgs.writeText "caddy.patch" ''
    --- a/nixos/modules/services/web-servers/caddy/default.nix
    +++ b/nixos/modules/services/web-servers/caddy/default.nix
    @@ -2,6 +2,6 @@
     {
       options.services.caddy.greeting = lib.mkOption {
         type = lib.types.str;
    -    default = "original";
    +    default = "patched-greeting";
       };
     }
  '';

  modResult = patcher.module {
    module = "services/web-servers/caddy/default.nix";
    src = mockRepo;
    type = "nixos";
    patches = [ modulePatch ];
  };

  eval = pkgs.lib.evalModules {
    modules = [
      modResult
    ];
  };
in
{
  testDisabledModules =
    if modResult.disabledModules == [ "services/web-servers/caddy/default.nix" ] then
      "pass"
    else
      throw "disabledModules mismatch";

  testImportedModuleEvaluation =
    if eval.config.services.caddy.greeting == "patched-greeting" then
      "pass"
    else
      throw "Evaluated greeting mismatch: ${eval.config.services.caddy.greeting}";
}
