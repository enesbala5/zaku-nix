# Zaku for Nix

Nix package for [Zaku](https://github.com/buildzaku/zaku), a native API client. This flake installs the official Linux tarball (currently 26.0). It does not compile Zaku.

Upstream is a GPUI workspace that pins Rust 1.99 and git dependencies from Zed. The release tarball is the path that matches their Linux install script: `zaku.app/libexec/zaku` plus vendored X11/xkb libraries on `rpath` `$ORIGIN/../lib`.

The derivation then:

- points the dynamic linker at Nix's glibc (the binary needs glibc 2.39 or newer; it uses `pidfd_spawnp`)
- adds `libgcc_s` from nixpkgs
- puts `wayland` and `libglvnd` on `LD_LIBRARY_PATH` (both are dlopened, not in the tarball)
- adds `/run/opengl-driver/share` to `XDG_DATA_DIRS` so the Vulkan loader can see NixOS GPU drivers

To use, add it to a NixOS flake:

```nix
inputs = {
  # ...
  zaku.url = "github:enesbala5/zaku-nix";

  # optional: share one nixpkgs with the rest of the system
  zaku.inputs.nixpkgs.follows = "nixpkgs";
  # ...
};
```

## Packages

One package, also exposed as `default`, for `x86_64-linux` and `aarch64-linux`. `apps.default` runs it with `nix run`.

## Installation

```sh
nix profile install github:enesbala5/zaku-nix
```

```sh
nix run github:enesbala5/zaku-nix
```

Home Manager:

```nix
home.packages = [
  inputs.zaku.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

`zaku` is on `PATH`. The desktop file `dev.zaku.Zaku.desktop` and the hicolor icons are installed under `$out/share`.

## Bump

Edit `version` and the two `hash` values in [`flake.nix`](./flake.nix). Prefetch without building:

```sh
nix-prefetch-url --type sha256 \
  "https://github.com/buildzaku/zaku/releases/download/<VERSION>/Zaku-<VERSION>-linux-x86_64.tar.gz"
```

Repeat for `linux-aarch64`. Convert with `nix hash convert --hash-algo sha256 --to sri <base32>`.

## Caveats

- **Linux only.** macOS and Windows builds are not packaged.
- **NixOS Vulkan.** The wrapper looks for drivers in `/run/opengl-driver/share`, which `hardware.graphics.enable` provides. A non-NixOS Nix install that already has `/usr/share/vulkan` does not need that path; the prefix is harmless there only if that directory is absent or empty.
- **glibc 2.39+.** An older nixpkgs will patchelf the binary onto a glibc that cannot run it.
- **Pinned to the 26.0 release tarball**, not git `main`.

## License

[Zaku](https://github.com/buildzaku/zaku) is AGPL-3.0-or-later.

The Nix packaging in this repository is MIT.
