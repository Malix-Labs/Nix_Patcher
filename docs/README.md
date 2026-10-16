# Nix_Patcher

Declarative, zero-maintenance Nix library to patch external packages, files, modules, trees, and flakes with patches or PRs applied simultaneously.

## Setup

### Flakes

1. Add to `flake.nix`:

   ```nix
   inputs.patcher = {
     url = "github:Malix-Labs/Nix_Patcher";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```

2. Update lockfile:

   ```bash
   nix flake update patcher
   ```

### tack (<https://github.com/manic-systems/tack>)

1. Add dependency:

   ```bash
   tack add patcher https://github.com/Malix-Labs/Nix_Patcher
   ```

2. Import in Nix expression:

   ```nix
   patcher = import (import ./.tack).patcher { inherit pkgs; };
   ```

### npins (<https://github.com/andir/npins>)

1. Add dependency:

   ```bash
   npins add git https://github.com/Malix-Labs/Nix_Patcher -n patcher
   ```

2. Import in Nix expression:

   ```nix
   patcher = import (import ./npins).patcher { inherit pkgs; };
   ```

### niv (<https://github.com/nmattia/niv>)

1. Add dependency:

   ```bash
   niv add Malix-Labs/Nix_Patcher -n patcher
   ```

2. Import in Nix expression:

   ```nix
   patcher = import (import ./nix/sources.nix).patcher { inherit pkgs; };
   ```

### builtins.fetchGit

```nix
patcher = import (builtins.fetchGit {
  url = "https://github.com/Malix-Labs/Nix_Patcher.git";
  rev = "<COMMIT_HASH>";
}) { inherit pkgs; };
```

### builtins.getFlake

```nix
patcher = (builtins.getFlake "github:Malix-Labs/Nix_Patcher").lib.forPkgs pkgs;
```

## Core APIs

Nix_Patcher provides dedicated patchers for each level of the Nix evaluation stack:

* `lib.package` (alias `lib.pkg`): Non-IFD package patching via `overrideAttrs`.
* `lib.file`: Streaming single-file patching in an ultra-lightweight derivation.
* `lib.module`: System module patcher with automated `disabledModules` replacement.
* `lib.tree`: Copy-on-write directory patching via symlink forest and selective unlinking.
* `lib.flake`: Pure flake re-hydration and output evaluation without `--impure`.
* `lib.patch`: Polymorphic dispatcher automatically selecting the optimal patcher.

### 1. lib.package / lib.pkg

Applies patches to a Nixpkgs package without Import-From-Derivation (IFD). Evaluation cost is zero milliseconds because it appends patches directly to `overrideAttrs`.

```nix
patchedHello = patcher.package {
  pkg = pkgs.hello;
  patches = [
    ./fix-greeting.patch
    (fetchurl {
      url = "https://github.com/owner/repo/pull/123.patch";
      hash = "sha256-...";
    })
  ];
};
```

If a patch target is an entire directory tree (such as a full PR branch fetch), `lib.package` automatically normalizes it into a unified diff against package sources before applying.

### 2. lib.file

Applies unified diff patches to an individual file in a local micro-derivation. Tries `-p1` by default and falls back to `-p0` automatically.

```nix
patchedScript = patcher.file {
  file = ./scripts/deploy.sh;
  patches = [ ./patches/fix-flags.patch ];
};
```

### 3. lib.module

Patches an upstream NixOS, Home Manager, or nix-darwin module file and returns a module replacement specification with `disabledModules` and `imports`.

```nix
{
  imports = [
    (patcher.module {
      module = "services/networking/ssh.nix";
      src = nixpkgs;
      type = "nixos";
      patches = [ ./fix-sshd-config.patch ];
    })
  ];
}
```

The resulting attribute set seamlessly disables the upstream module path and imports the patched variant:

```nix
{
  disabledModules = [ "<nixpkgs>/nixos/modules/services/networking/ssh.nix" ];
  imports = [ "/nix/store/...-ssh.nix" ];
}
```

### 4. lib.tree

Applies patches to a full directory tree or source tree. Uses a copy-on-write symlink forest (`cp -as`), unlinks only the specific files modified by patches, and applies patches in batch.

```nix
patchedSrc = patcher.tree {
  src = inputs.my-upstream-repo;
  patches = [
    ./patches/feature-a.patch
    ./patches/feature-b.patch
  ];
};
```

Supports applying raw PR directory trees directly without manual diff generation:

```nix
patchedSrc = patcher.tree {
  src = inputs.base-repo;
  patches = [
    inputs.pr-1-tree
    ./additional-fix.patch
  ];
};
```

### 5. lib.flake

Applies patches to an upstream flake input and evaluates its outputs in 100% pure evaluation mode. Does not require `--impure` or `builtins.getFlake`.

```nix
patchedNixpkgs = patcher.flake {
  flake = inputs.nixpkgs;
  patches = [ ./nixpkgs-fix.patch ];
  inputs = { };
};

# Access patched flake outputs directly
myPackage = patchedNixpkgs.legacyPackages.x86_64-linux.my-tool;
```

### 6. lib.patch

Polymorphic entry point that inspects the target type and routes to the appropriate patcher:

* If target has `overrideAttrs` and `src` -> delegates to `lib.package`.
* If target has flake outputs -> delegates to `lib.flake`.
* If target is a single file -> delegates to `lib.file`.
* Otherwise -> delegates to `lib.tree`.

```nix
patchedEntity = patcher.patch {
  target = pkgs.hello; # Or a file path, tree, or flake input
  patches = [ ./fix.patch ];
};
```

## Architecture and Design Rationale

### Ephemeral 3-Way Merge vs Nix Tree Patching

In traditional Git workflows, merging multiple external PRs requires creating merge commits across branches. When done ephemerally in Git, Git must parse commit trees and resolve index blobs.

In Nix:

1. Package patching operates entirely in derivation attributes (`overrideAttrs`), with zero evaluation overhead and zero store duplication.
2. Single file patching isolates changes to a streaming `runCommandLocal` derivation.
3. Directory tree patching uses a copy-on-write symlink forest (`cp -as`) pointing back to the upstream store path. Only mutated files are unlinked and written, avoiding full directory copies.
4. Pure flake re-hydration imports the patched tree's `flake.nix` directly, preserving pure evaluation invariants without store-path context leakage.

## Development and Verification

Run test suites:

```bash
nix flake check --allow-import-from-derivation
```

Run pre-commit formatters:

```bash
nix fmt
```

Enter development shell:

```bash
nix develop
```
