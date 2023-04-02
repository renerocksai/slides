{
  description = "slides dev shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-22.11";
    flake-utils.url = "github:numtide/flake-utils";

    # required for latest zig
    zig.url = "github:mitchellh/zig-overlay";

    # for chromeos etc
    nixgl.url = "github:guibou/nixGL";

    # Used for shell.nix
    flake-compat = {
      url = github:edolstra/flake-compat;
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nixgl,
    ...
  } @ inputs: let
    overlays = [ nixgl.overlay ];

    # Our supported systems are the same supported systems as the Zig binaries
    systems = builtins.attrNames inputs.zig.packages;
  in
    flake-utils.lib.eachSystem systems (
      system: let
        pkgs = import nixpkgs {inherit overlays system; };
      in rec {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            # zigpkgs.master
            xorg.libX11 
            xorg.libX11.dev
            xorg.libXcursor
            xorg.libXinerama
            xorg.xinput
            xorg.libXrandr
            pkgs.gtk3
            libGL
            zig
            neovim
          ];

          buildInputs = with pkgs; [
            # we need a version of bash capable of being interactive
            # as opposed to a bash just used for building this flake 
            # in non-interactive mode
            bashInteractive 
          ];

          shellHook = ''
            # once we set SHELL to point to the interactive bash, neovim will 
            # launch the correct $SHELL in its :terminal 
            export SHELL=${pkgs.bashInteractive}/bin/bash
          '';
        };

        # this shell needs to be run with
        # nix develop --impure .#nixgl 
        devShells.nixgl = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            # zigpkgs.master
            xorg.libX11 
            xorg.libX11.dev
            xorg.libXcursor
            xorg.libXinerama
            xorg.xinput
            xorg.libXrandr
            pkgs.gtk3
            libGL
            zig
            neovim
            pkgs.nixgl.auto.nixGLDefault
          ];

          buildInputs = with pkgs; [
            # we need a version of bash capable of being interactive
            # as opposed to a bash just used for building this flake 
            # in non-interactive mode
            bashInteractive 
          ];

          shellHook = ''
            # once we set SHELL to point to the interactive bash, neovim will 
            # launch the correct $SHELL in its :terminal 
            export SHELL=${pkgs.bashInteractive}/bin/bash
            echo "run with:"
            echo "nixGL zig-out/bin/slides"
          '';
        };

        # For compatibility with older versions of the `nix` binary
        devShell = self.devShells.${system}.default;
      }
    );
}
