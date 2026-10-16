{ pkgs, patcher }:
let
  baseFile = pkgs.writeText "sample.txt" ''
    line 1
    line 2
    line 3
  '';

  patch1 = pkgs.writeText "p1.patch" ''
    --- a/sample.txt
    +++ b/sample.txt
    @@ -1,3 +1,4 @@
     line 1
    +line 1.5
     line 2
     line 3
  '';

  patch2 = pkgs.writeText "p2.patch" ''
    --- a/sample.txt
    +++ b/sample.txt
    @@ -2,3 +2,4 @@
     line 1.5
     line 2
    +line 2.5
     line 3
  '';

  patchedSingle = patcher.file {
    file = baseFile;
    patches = [ patch1 ];
  };

  patchedDual = patcher.file {
    file = baseFile;
    patches = [
      patch1
      patch2
    ];
  };

  singleContent = builtins.readFile patchedSingle;
  dualContent = builtins.readFile patchedDual;
in
{
  testSingleFilePatch =
    if pkgs.lib.hasInfix "line 1.5" singleContent && !pkgs.lib.hasInfix "line 2.5" singleContent then
      "pass"
    else
      throw "Single patch failed: ${singleContent}";

  testDualSequentialPatch =
    if pkgs.lib.hasInfix "line 1.5" dualContent && pkgs.lib.hasInfix "line 2.5" dualContent then
      "pass"
    else
      throw "Dual sequential patch failed: ${dualContent}";
}
