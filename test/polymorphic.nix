{ pkgs, patcher }:
let
  # 1. Target is a package
  dummyPkg = pkgs.stdenv.mkDerivation {
    name = "dummy";
    src = pkgs.emptyDirectory;
    dontUnpack = true;
    installPhase = "mkdir -p $out";
  };
  pkgPatch = pkgs.writeText "pkg.patch" ''
    --- /dev/null
    +++ b/test.txt
    @@ -0,0 +1 @@
    +pkg-ok
  '';
  patchedPkg = patcher.patch {
    target = dummyPkg;
    patches = [ pkgPatch ];
  };

  # 2. Target is a file
  baseFile = pkgs.writeText "file.txt" ''
    original
  '';
  filePatch = pkgs.writeText "file.patch" ''
    --- a/file.txt
    +++ b/file.txt
    @@ -1 +1 @@
    -original
    +file-ok
  '';
  patchedFile = patcher.patch {
    target = baseFile;
    patches = [ filePatch ];
  };

  # 3. Target is a tree
  baseTree = pkgs.runCommandLocal "t" { } ''
    mkdir -p $out
    echo "tree-original" > $out/a.txt
  '';
  treePatch = pkgs.writeText "tree.patch" ''
    --- a/a.txt
    +++ b/a.txt
    @@ -1 +1 @@
    -tree-original
    +tree-ok
  '';
  patchedTree = patcher.patch {
    target = baseTree;
    patches = [ treePatch ];
  };

  # 4. Target is a flake
  baseFlake = pkgs.runCommandLocal "flk" { } ''
    mkdir -p $out
    echo '{ outputs = { self }: { val = "flake-orig"; }; }' > $out/flake.nix
  '';
  flakePatch = pkgs.writeText "flk.patch" ''
    --- a/flake.nix
    +++ b/flake.nix
    @@ -1 +1 @@
    -{ outputs = { self }: { val = "flake-orig"; }; }
    +{ outputs = { self }: { val = "flake-ok"; }; }
  '';
  flakeTarget = {
    outPath = baseFlake;
    outputs = {
      val = "flake-orig";
    };
  };
  patchedFlake = patcher.patch {
    target = flakeTarget;
    patches = [ flakePatch ];
  };
in
{
  testPolyPackage =
    if patchedPkg ? patches && builtins.length patchedPkg.patches == 1 then
      "pass"
    else
      throw "Poly package failed";

  testPolyFile =
    if pkgs.lib.hasInfix "file-ok" (builtins.readFile patchedFile) then
      "pass"
    else
      throw "Poly file failed";

  testPolyTree =
    if pkgs.lib.hasInfix "tree-ok" (builtins.readFile (patchedTree + "/a.txt")) then
      "pass"
    else
      throw "Poly tree failed";

  testPolyFlake = if patchedFlake.val == "flake-ok" then "pass" else throw "Poly flake failed";
}
