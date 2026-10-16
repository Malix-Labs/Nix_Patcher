{ pkgs, patcher }:
let
  helloPatch = pkgs.writeText "hello.patch" ''
    --- a/src/hello.c
    +++ b/src/hello.c
    @@ -58,3 +58,4 @@
       puts (_("Hello, world!"));
     }
    +/* TEST_PATCH_PACKAGE_HELLO */
  '';

  patchedHello = patcher.package {
    pkg = pkgs.hello;
    patches = [ helloPatch ];
  };

  dummyPkg = pkgs.stdenv.mkDerivation {
    name = "dummy";
    dontUnpack = true;
    installPhase = "mkdir -p $out";
  };

  dummyPatch = pkgs.writeText "dummy.patch" ''
    --- /dev/null
    +++ b/test.txt
    @@ -0,0 +1 @@
    +hello
  '';

  patchedDummy = patcher.package {
    pkg = dummyPkg;
    patches = [ dummyPatch ];
  };

  patchedViaAlias = patcher.pkg {
    pkg = dummyPkg;
    patches = [ dummyPatch ];
  };
in
{
  testHelloHasPatches =
    if builtins.length patchedHello.patches >= 1 then "pass" else throw "Hello missing patch";

  testDummyHandlesMissingPatches =
    if builtins.length patchedDummy.patches == 1 then "pass" else throw "Dummy missing patch";

  testPkgAlias =
    if patchedViaAlias.drvPath == patchedDummy.drvPath then "pass" else throw "pkg alias mismatch";
}
