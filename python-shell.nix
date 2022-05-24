# { pkgs ? import <nixpkgs> {} }: 
with import <nixpkgs> {};
with pkgs.python3Packages;

pkgs.mkShell {
  nativeBuildInputs = [
    glibcLocales # for character support (unicode etc)
    # glfw
    # zlib

    (python3.buildEnv.override {  
      #
      # these packages are required for virtualenv and pip to work:
      #
      extraLibs = [    
        python3Full
        # python36Packages.cffi
        # python36Packages.virtualenv
        # python36Packages.pip
        python3Packages.pillow
        python3Packages.fpdf

      ];
    })
  ];
  shellHook = ''
    # set SOURCE_DATE_EPOCH so that we can use python wheels
    SOURCE_DATE_EPOCH=$(date +%s)
    export LANG=en_US.UTF-8
    # export PYTHONPATH=$PWD
  '';
}
