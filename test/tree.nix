{ pkgs, patcher }:
let
  baseTree = pkgs.runCommandLocal "base-tree" { } ''
    mkdir -p $out/sub
    echo "root original" > $out/root.txt
    echo "sub original" > $out/sub/nested.txt
  '';

  treePatch = pkgs.writeText "tree.patch" ''
    --- a/root.txt
    +++ b/root.txt
    @@ -1 +1 @@
    -root original
    +root patched
    --- a/sub/nested.txt
    +++ b/sub/nested.txt
    @@ -1 +1 @@
    -sub original
    +sub patched
    --- /dev/null
    +++ b/brand_new/created.txt
    @@ -0,0 +1 @@
    +new content
  '';

  patchedDir = patcher.tree {
    src = baseTree;
    patches = [ treePatch ];
  };

  # Full PR tree fixture to test diff -ruN normalization
  prTree = pkgs.runCommandLocal "pr-tree" { } ''
    mkdir -p $out/sub
    echo "root pr-tree" > $out/root.txt
    echo "sub original" > $out/sub/nested.txt
  '';

  patchedFromPrTree = patcher.tree {
    src = baseTree;
    patches = [ prTree ];
  };

  rootContent = builtins.readFile (patchedDir + "/root.txt");
  nestedContent = builtins.readFile (patchedDir + "/sub/nested.txt");
  newContent = builtins.readFile (patchedDir + "/brand_new/created.txt");
  prRootContent = builtins.readFile (patchedFromPrTree + "/root.txt");
in
{
  testTreeModifiedFiles =
    if
      pkgs.lib.hasInfix "root patched" rootContent && pkgs.lib.hasInfix "sub patched" nestedContent
    then
      "pass"
    else
      throw "Tree modified files mismatch";

  testTreeNewFileCreated =
    if pkgs.lib.hasInfix "new content" newContent then
      "pass"
    else
      throw "Tree new file creation mismatch";

  testTreeNormalizedPrTree =
    if pkgs.lib.hasInfix "root pr-tree" prRootContent then
      "pass"
    else
      throw "Tree PR tree normalization mismatch: ${prRootContent}";
}
