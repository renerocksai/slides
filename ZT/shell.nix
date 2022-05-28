let
  nixpkgs = builtins.fetchTarball {
    # nixpkgs 
    url = "https://github.com/NixOS/nixpkgs/archive/53578062a472fdd322492cf59f3699ab1231f6f2.tar.gz";
    sha256 = "05f5mxkh6mfpnf9809mqg312jqfdcmi2a0wqvsqfvm3cwlh2n35v";
  };
in
{ pkgs ? import nixpkgs { } }:

pkgs.mkShell {
  # for building
  buildInputs = with pkgs; [
    xorg.libX11 
    xorg.libX11.dev
    xorg.libXcursor
    xorg.libXinerama
    xorg.xinput
    xorg.libXrandr
    pkgs.gtk3
    libGL
    zig
  ];

  # for running tools in the shell
  nativeBuildInputs = with pkgs; [
    cmake
    gdb
    ninja
    qemu
  ] ++ (with llvmPackages_13; [
    clang
    clang-unwrapped
    lld
    llvm
  ]);

  hardeningDisable = [ "all" ];
  LD_LIBRARY_PATH = with pkgs ; "${libGL}/lib:${xorg.libX11}/lib";
}

