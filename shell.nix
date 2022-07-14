{ pkgs ? import <nixpkgs> { } }:

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
  ];

  # for running tools in the shell
  nativeBuildInputs = with pkgs; [
    cmake
    gdb
    ninja
    qemu
    glew
  ] ++ (with llvmPackages_13; [
    clang
    clang-unwrapped
    lld
    llvm
  ]);

  hardeningDisable = [ "all" ];
  LD_LIBRARY_PATH = with pkgs ; "${libGL}/lib:${xorg.libX11}/lib";
}

