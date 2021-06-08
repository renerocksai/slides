#!/usr/bin/env bash

# This file is for cross-compiling to windows, on ubuntu
# See issue #8531 on github: https://github.com/ziglang/zig/issues/8531 - this 
# project, too, suffers from linker errors when building for windows with 
# anything other than Debug mode. Here, not even ReleaseSafe works.
# 
# The workaround is to take the failing zig build-exe command line, 
# add the flag `-fno-lto` to it (below this is done after the -O 
# flag.
# The result of build-exe is a directory containing slides.exe which we 
# conveniently copy to zig-cache/bin

RELMODE=ReleaseFast    # ReleaseFast produces .exe files that appear to work
                       # but seem to have troubles with font coloring 
                       # (text doesn't show, only becomes visible as a 
                       # shadow when a menu is activated)
RELMODE=ReleaseSafe
SRCDIR=.
odir=$(zig build-exe $SRCDIR/src/main.zig -lc -cflags -std=c99 -- $SRCDIR/zig-upaya/src/deps/sokol/compile_sokol.c -cflags -std=c99 -- $SRCDIR/zig-upaya/src/deps/stb/src/stb_impl.c -lc++ -luser32 -lgdi32 -cflags -Wno-return-type-c-linkage -std=c++11 -- $SRCDIR/zig-upaya/src/deps/imgui/cimgui/imgui/imgui.cpp -cflags -Wno-return-type-c-linkage -std=c++11 -- $SRCDIR/zig-upaya/src/deps/imgui/cimgui/imgui/imgui_demo.cpp -cflags -Wno-return-type-c-linkage -std=c++11 -- $SRCDIR/zig-upaya/src/deps/imgui/cimgui/imgui/imgui_draw.cpp -cflags -Wno-return-type-c-linkage -std=c++11 -- $SRCDIR/zig-upaya/src/deps/imgui/cimgui/imgui/imgui_widgets.cpp -cflags -Wno-return-type-c-linkage -std=c++11 -- $SRCDIR/zig-upaya/src/deps/imgui/cimgui/cimgui.cpp -cflags -Wno-return-type-c-linkage -std=c++11 -- $SRCDIR/zig-upaya/src/deps/imgui/temporary_hacks.cpp -lcomdlg32 -lole32 -luser32 -lshell32 -cflags -D_CRT_SECURE_NO_WARNINGS -D_CRT_SECURE_NO_DEPRECATE -- $SRCDIR/zig-upaya/src/deps/filebrowser/src/tinyfiledialogs.c -O$RELMODE -fno-lto --cache-dir $SRCDIR/zig-cache --global-cache-dir /home/rs/.cache/zig --name slides -target x86_64-windows-gnu --pkg-begin upaya $SRCDIR/zig-upaya/src/upaya.zig --pkg-begin stb $SRCDIR/zig-upaya/src/deps/stb/stb.zig --pkg-end --pkg-begin filebrowser $SRCDIR/zig-upaya/src/deps/filebrowser/filebrowser.zig --pkg-end --pkg-begin sokol $SRCDIR/zig-upaya/src/deps/sokol/sokol.zig --pkg-end --pkg-begin imgui $SRCDIR/zig-upaya/src/deps/imgui/imgui.zig --pkg-end --pkg-end --pkg-begin sokol $SRCDIR/zig-upaya/src/deps/sokol/sokol.zig --pkg-end --pkg-begin stb $SRCDIR/zig-upaya/src/deps/stb/stb.zig --pkg-end --pkg-begin imgui $SRCDIR/zig-upaya/src/deps/imgui/imgui.zig --pkg-end --pkg-begin filebrowser $SRCDIR/zig-upaya/src/deps/filebrowser/filebrowser.zig --pkg-end -I $SRCDIR/zig-upaya/src/deps/sokol -I $SRCDIR/zig-upaya/src/deps/stb/src -I $SRCDIR/zig-upaya/src/deps/imgui -I $SRCDIR/zig-upaya/src/deps/imgui/cimgui --enable-cache)

if [ $? -eq 0 ] ; then
    echo Output Directory: $odir
    mkdir -p zig-cache/bin
    cp -v $odir/slides.exe ./zig-cache/bin/
fi

