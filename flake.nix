{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:volesen/nixpkgs";
  };

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };

      moltenvk = pkgs.darwin.moltenvk.override {
        enableStatic = true;
      };

      frameworks = with pkgs.darwin.apple_sdk.frameworks;
        [
          # https://github.com/godotengine/godot/blob/3978628c6cc1227250fc6ed45c8d854d24c30c30/platform/macos/detect.py#L199
          Cocoa
          Carbon
          AudioUnit
          CoreAudio
          CoreMIDI
          IOKit
          GameController
          CoreHaptics
          CoreVideo
          AVFoundation
          CoreMedia
          QuartzCore
          Security
          # https://github.com/godotengine/godot/blob/3978628c6cc1227250fc6ed45c8d854d24c30c30/platform/macos/detect.py#L244C32-L244C79
          Metal
          IOSurface
          # Transitive frameworks
          AppKit
          Foundation
          CoreFoundation
          CoreGraphics
          ForceFeedback
          CoreServices
          DiskArbitration # Used by CoreServices
          Kernel
          CFNetwork
          ApplicationServices
          AudioToolbox
          CoreText
          CoreAudioTypes
          ColorSync
          ImageIO
          CoreData
          CoreImage
          OpenGL
          CloudKit
          CoreLocation
          UniformTypeIdentifiers
        ];

      frameworkPaths = builtins.concatStringsSep ", " (map (f: "\"${f}/Library/Frameworks\"") frameworks);

      godot = pkgs.darwin.apple_sdk.stdenv.mkDerivation {
        name = "godot4";

        version = "4.2.2-stable";

        src = pkgs.fetchFromGitHub {
          owner = "godotengine";
          repo = "godot";
          rev = "15073afe3856abd2aa1622492fe50026c7d63dc1";
          hash = "sha256-anJgPEeHIW2qIALMfPduBVgbYYyz1PWCmPsZZxS9oHI=";
        };

        sconsFlags = "platform=macos vulkan_sdk_path=${moltenvk}/lib";

        patchPhase = with pkgs.darwin.apple_sdk.frameworks; ''
          cat <<EOF >> platform/macos/detect.py
              # https://github.com/llvm/llvm-project/issues/48757
              env.Append(CCFLAGS=["-Wno-elaborated-enum-base"])
              env.Prepend(
                  CPPPATH=[
                      "${pkgs.darwin.libobjc}/include/",
                      "${pkgs.darwin.apple_sdk_11_0.libs.libDER}/include/",
                      "${pkgs.darwin.apple_sdk_11_0.libs.simd}/include/",
                  ]
              )
              env.Append(FRAMEWORKPATH=[${frameworkPaths}])
              env.Append(LINKFLAGS=["-L${pkgs.zlib}/lib/"])
          EOF
        '';

        nativeBuildInputs = frameworks ++ (with pkgs; [
          scons
          xcbuild
          moltenvk
        ]);

        buildInputs = with pkgs; [
          zlib
        ];

        installPhase = ''
          mkdir -p "$out/bin"
          cp bin/godot.* $out/bin/godot4
        '';

      };
    in
    {
      packages.aarch64-darwin.godot = godot;

      packages.aarch64-darwin.default = self.packages.aarch64-darwin.godot;

      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixpkgs-fmt;
    };
}
