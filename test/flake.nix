{ pkgs, patcher }:
let
  fixtureFlake = pkgs.runCommandLocal "fixture-flake" { } ''
    mkdir -p $out
    cat << 'FLAKE' > $out/flake.nix
    {
      description = "Fixture Flake";
      outputs = { self, extraInput ? "default-input" }: {
        message = "unpatched";
        computed = extraInput + "-computed";
      };
    }
    FLAKE
  '';

  flakePatch = pkgs.writeText "flake.patch" ''
    --- a/flake.nix
    +++ b/flake.nix
    @@ -3,3 +3,3 @@
       outputs = { self, extraInput ? "default-input" }: {
    -    message = "unpatched";
    +    message = "patched-flake-output";
         computed = extraInput + "-computed";
  '';

  patchedFlake = patcher.flake {
    flake = fixtureFlake;
    patches = [ flakePatch ];
    inputs = {
      extraInput = "custom-input";
    };
  };
in
{
  testFlakeOutputPatched =
    if patchedFlake.message == "patched-flake-output" then
      "pass"
    else
      throw "Flake message mismatch: ${patchedFlake.message}";

  testFlakeInputForwarding =
    if patchedFlake.computed == "custom-input-computed" then
      "pass"
    else
      throw "Flake input forwarding mismatch: ${patchedFlake.computed}";

  testFlakeOutPathExposed =
    if patchedFlake ? outPath && builtins.pathExists (patchedFlake.outPath + "/flake.nix") then
      "pass"
    else
      throw "Flake outPath missing";
}
