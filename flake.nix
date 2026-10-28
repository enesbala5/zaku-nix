{
  description = "Nix package for the Zaku API client";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      version = "26.0";
      # Official release bundles. Upstream's Linux build vendors X11/xkb next
      # to the binary (rpath $ORIGIN/../lib) and leaves libc, libm, and libgcc_s
      # to the system. Wayland and EGL are dlopened.
      sources = {
        x86_64-linux = {
          arch = "x86_64";
          hash = "sha256-Q4b6x818/okbd5QLpnw5Lmh4NckQOnIrJV1xDCblXmc=";
        };
        aarch64-linux = {
          arch = "aarch64";
          hash = "sha256-Ld18anHPxVpR6zfGgVbiYHqMraqwoGwdHPWZxVtuYpE=";
        };
      };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          source = sources.${system};
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "zaku";
            inherit version;

            src = pkgs.fetchurl {
              url = "https://github.com/buildzaku/zaku/releases/download/${version}/Zaku-${version}-linux-${source.arch}.tar.gz";
              hash = source.hash;
            };

            sourceRoot = "zaku.app";

            nativeBuildInputs = [
              pkgs.patchelf
              pkgs.makeWrapper
            ];

            # Prebuilt binary. Strip would rewrite a binary we did not compile.
            dontStrip = true;

            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin $out/lib $out/libexec $out/share
              cp -a libexec/. $out/libexec/
              cp -a lib/. $out/lib/
              cp -a share/. $out/share/
              chmod 755 $out/libexec/zaku

              substituteInPlace $out/share/applications/dev.zaku.Zaku.desktop \
                --replace-fail 'TryExec=zaku' "TryExec=$out/bin/zaku" \
                --replace-fail 'Exec=zaku' "Exec=$out/bin/zaku"
              runHook postInstall
            '';

            # patchelf rewrites DT_RPATH into DT_RUNPATH unless --force-rpath.
            # RUNPATH is not used for a dependency's dependencies, so libxcb
            # would not find libXau.so.6 in $out/lib.
            postFixup = ''
              patchelf \
                --set-interpreter "$(< ${pkgs.stdenv.cc}/nix-support/dynamic-linker)" \
                --set-rpath '$ORIGIN/../lib:${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}' \
                --force-rpath \
                $out/libexec/zaku

              for lib in $out/lib/*; do
                patchelf --set-rpath '$ORIGIN' --force-rpath "$lib"
              done

              makeWrapper $out/libexec/zaku $out/bin/zaku \
                --prefix LD_LIBRARY_PATH : ${
                  pkgs.lib.makeLibraryPath [
                    pkgs.wayland
                    pkgs.libglvnd
                  ]
                } \
                --prefix XDG_DATA_DIRS : /run/opengl-driver/share
            '';

            meta = {
              description = "Fast, open-source API client";
              homepage = "https://zaku.dev";
              license = pkgs.lib.licenses.agpl3Plus;
              mainProgram = "zaku";
              platforms = [
                "x86_64-linux"
                "aarch64-linux"
              ];
              sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
            };
          };
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/zaku";
        };
      });
    };
}
