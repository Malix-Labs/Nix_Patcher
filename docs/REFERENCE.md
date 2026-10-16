# API Reference

Detailed technical reference for Nix_Patcher functions and configuration options.

## patcher.package

Applies one or more patches to an existing Nixpkgs package without Import-From-Derivation (IFD).

Evaluation overhead is zero milliseconds because patches are appended directly to the package derivation via `overrideAttrs`.

### Type

```text
package :: { pkg :: Derivation; patches :: Path | String | Derivation | [ Path | String | Derivation ]; } -> Derivation
```

### Inputs

* `pkg` (Derivation): The upstream package derivation to patch.
* `patches` (Path, String, Derivation, or List): A patch file, list of patch files, or complete PR branch directory trees.
* `pkgs` (Optional AttrSet): Custom Nixpkgs package set used if directory normalization is required.

### Aliases

* `patcher.pkg`: Identical to `patcher.package`.

### Example

```nix
patchedHello = patcher.package {
  pkg = pkgs.hello;
  patches = [
    ./fix-greeting.patch
    (pkgs.fetchpatch {
      url = "https://github.com/owner/repo/pull/123.patch";
      hash = "sha256-AAAA...";
    })
  ];
};
```

## patcher.file

Patches an individual file in a high-speed micro-derivation.

Streams patches sequentially using GNU patch. By default strips one directory component (`-p1`) and automatically falls back to `-p0` if `-p1` fails.

### Type

```text
file :: { file :: Path | String | Derivation; patches :: Path | String | Derivation | [ Path | String | Derivation ]; strip? :: Int; pkgs? :: AttrSet; } -> Derivation
```

### Inputs

* `file` (Path, String, or Derivation): Path to the target file.
* `patches` (Path, String, Derivation, or List): Patch or list of patches applied in sequential order.
* `strip` (Optional Int): Strip count passed to GNU patch `-p<n>`. Defaults to `1`.
* `pkgs` (Optional AttrSet): Custom Nixpkgs instance providing `hostPkgs.patch`.

### Example

```nix
patchedScript = patcher.file {
  file = ./scripts/entrypoint.sh;
  patches = [ ./patches/fix-options.patch ];
};
```

## patcher.module

Patches an upstream NixOS, Home Manager, or nix-darwin module file and returns a replacement module specification.

Produces an attribute set ready to be passed directly to `imports`, disabling the upstream module via `disabledModules` and importing the patched variant.

### Type

```text
module :: { module :: String | Path; patches :: Path | String | Derivation | [ Path | String | Derivation ]; src? :: Path | Derivation; type? :: String; strip? :: Int; pkgs? :: AttrSet; } -> AttrSet
```

### Inputs

* `module` (String or Path): Relative module path within upstream source or absolute file path.
* `patches` (Path, String, Derivation, or List): Patches to apply to the module file.
* `src` (Optional Path or Derivation): Upstream repository root (for example `nixpkgs`).
* `type` (Optional String): Module subsystem convention (`nixos`, `home-manager`, `darwin`, or `custom`).
* `strip` (Optional Int): Strip count passed to GNU patch. Defaults to `1`.
* `pkgs` (Optional AttrSet): Custom Nixpkgs instance.

### Output Structure

```nix
{
  disabledModules = [ "<upstream-path>" ];
  imports = [ "<patched-store-path>" ];
}
```

### Example

```nix
{
  imports = [
    (patcher.module {
      module = "services/security/fail2ban.nix";
      src = nixpkgs;
      type = "nixos";
      patches = [ ./patches/fail2ban-nftables.patch ];
    })
  ];
}
```

## patcher.tree

Patches an entire directory tree using a fast copy-on-write symlink forest.

Builds an ephemeral directory tree where all untouched files remain symbolic links to the original upstream store path. Only mutated files are selectively unlinked and written, minimizing build time and store consumption.

### Type

```text
tree :: { src :: Path | String | Derivation; patches :: Path | String | Derivation | [ Path | String | Derivation ]; strip? :: Int; pkgs? :: AttrSet; } -> Derivation
```

### Inputs

* `src` (Path, String, or Derivation): Source directory to patch.
* `patches` (Path, String, Derivation, or List): Patch files or directory trees (such as complete PR branches).
* `strip` (Optional Int): Strip count passed to GNU patch. Defaults to `1`.
* `pkgs` (Optional AttrSet): Custom Nixpkgs instance providing `hostPkgs.patch`.

### Example

```nix
patchedTree = patcher.tree {
  src = inputs.upstream-repo;
  patches = [
    ./patches/0001-fix-driver.patch
    inputs.pr-456-branch
  ];
};
```

## patcher.flake

Re-hydrates and patches an external Flake in pure evaluation mode.

Patches the flake repository tree via `patcher.tree` and imports its `flake.nix` outputs purely without requiring `--impure` or `builtins.getFlake`.

### Type

```text
flake :: { flake :: AttrSet | Path | String; patches :: Path | String | Derivation | [ Path | String | Derivation ]; inputs? :: AttrSet; strip? :: Int; pkgs? :: AttrSet; } -> AttrSet
```

### Inputs

* `flake` (AttrSet, Path, or String): Input flake or path containing `flake.nix`.
* `patches` (Path, String, Derivation, or List): Patches to apply to the flake repository.
* `inputs` (Optional AttrSet): Attribute set of inputs passed to the flake outputs function.
* `strip` (Optional Int): Strip count passed to GNU patch. Defaults to `1`.
* `pkgs` (Optional AttrSet): Custom Nixpkgs instance.

### Example

```nix
patchedFlake = patcher.flake {
  flake = inputs.upstream-flake;
  patches = [ ./patches/expose-custom-package.patch ];
  inputs = {
    inherit (inputs) nixpkgs;
  };
};

packageOutput = patchedFlake.packages.x86_64-linux.default;
```

## patcher.patch

Polymorphic patcher that automatically inspects target characteristics and routes to the optimal specialized patcher.

### Routing Rules

1. If target is an attribute set with `overrideAttrs` and `src` or `srcs`, delegates to `patcher.package`.
2. If target is an attribute set with flake `outputs`, delegates to `patcher.flake`.
3. If target is a single file, delegates to `patcher.file`.
4. Otherwise, delegates to `patcher.tree`.

### Type

```text
patch :: { target :: Any; patches :: Path | String | Derivation | [ Path | String | Derivation ]; ... } -> Any
```

### Example

```nix
# Automatically routed to lib.package
p1 = patcher.patch {
  target = pkgs.ripgrep;
  patches = [ ./ripgrep.patch ];
};

# Automatically routed to lib.tree
p2 = patcher.patch {
  target = ./source-directory;
  patches = [ ./feature.patch ];
};
```

## patcher.forPkgs

Binds Nix_Patcher to a specific Nixpkgs package set and returns an attribute set containing all patch functions pre-configured with that package set.

### Type

```text
forPkgs :: Pkgs -> AttrSet
```

### Example

```nix
customPatcher = patcher.forPkgs pkgsCross.aarch64-multiplatform;
crossPatched = customPatcher.tree {
  src = inputs.kernel-tree;
  patches = [ ./board-fix.patch ];
};
```
