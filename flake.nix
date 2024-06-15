{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });
    in
    {
      devShells = forEachSupportedSystem
        ({ pkgs }:
          let
            frameworks = pkgs.darwin.apple_sdk.frameworks;
          in
          {
            default = pkgs.mkShell {
              buildInputs = with frameworks; [
                Carbon
                Cocoa
                Foundation
                CoreFoundation
                SystemConfiguration
                CoreServices
                CoreAudio
                CoreGraphics
                AppKit
                IOKit
              ];
              packages = with pkgs; [ zig zls ];
              shellHook = ''
                NIX_CFLAGS_COMPILE="$(echo "$NIX_CFLAGS_COMPILE" | sed -e "s/-isysroot [^ ]*//")"
              '';
            };
          });
    };
}
