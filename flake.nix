{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };

      moltenvk-vulkan-sdk = builtins.fetchTarball {
        url = "https://github.com/KhronosGroup/MoltenVK/releases/download/v1.2.6/MoltenVK-macos.tar";
        sha256 = "sha256:10lrzjfs7ba2mfcmg5fjy5n1np5wrmxf6nqjqg02512whv2dhmcb";
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

        sconsFlags = "platform=macos vulkan_sdk_path=${moltenvk-vulkan-sdk}";

        patchPhase = with pkgs.darwin.apple_sdk.frameworks; ''
          # https://github.com/llvm/llvm-project/issues/48757
          echo '    env.Append(CCFLAGS=["-Wno-elaborated-enum-base"])' >> platform/macos/detect.py

          echo '    env.Prepend(CPPPATH=["${pkgs.darwin.libobjc}/include/", "${pkgs.darwin.apple_sdk_11_0.libs.libDER}/include/", "${pkgs.darwin.apple_sdk_11_0.libs.simd}/include/"])' >> platform/macos/detect.py
          echo '    env.Append(FRAMEWORKPATH=[${frameworkPaths}])' >> platform/macos/detect.py
          echo '    env.Append(LINKFLAGS=["-L${pkgs.zlib}/lib/"])' >> platform/macos/detect.py
        '';

        nativeBuildInputs = frameworks ++ (with pkgs; [
          scons
          xcbuild
        ]);

        buildInputs = with pkgs; [
          pkgs.zlib
        ];

        installPhase = ''
          mkdir -p "$out/bin"
          cp bin/godot.* $out/bin/godot4
        '';

      };
    in
    {

      packages.aarch64-darwin.godot = godot;
      packages.aarch64-darwin.moltenvk-vulkan-sdk = moltenvk-vulkan-sdk;

      packages.aarch64-darwin.default = self.packages.aarch64-darwin.godot;

      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixpkgs-fmt;

    };
}
