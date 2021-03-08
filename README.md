# Slides

My first steps in [Zig](https://ziglang.org), towards creating a simple but powerful [imgui](https://github.com/ocornut/imgui/wiki#about-the-imgui-paradigm) based, OpenGL-rendered slideshow app in Zig.

**Danger - this is pre-alpha stuff**

This app will be much simpler for users than [Bûllets](https://github.com/renerocksai/bullets) while still being totally functional.

**Highlights:**
- Presentations are created in a simple text format, see below.
  - makes your slides totally GitHub-friendly
- One single (mostly static) executable - no install, no fuzz.
- Built-in editor: create, edit, and present in one small EXE.
  - for Windows, Linux (and Mac, if you build it yourself)

Example of the current format:

```
# -------------------------------------------------------------
# --define intro slide template
# -------------------------------------------------------------

# Background
@bg img=assets/nim/1.png
# or
# @bg color=#000000000

# title, subtitle, authors
@push intro_title    x=0 y=0 w=100 h=100 fontsize=16 color=#123456aa 
@push intro_subtitle x=0 y=0 w=100 h=100 fontsize=16 color=#123456aa 
@push intro_authors  x=0 y=0 w=100 h=100 fontsize=16 color=#123456aa 

# the following pushslide will cause the slide to be pushed, not rendered
@pushslide intro     fontsize=16 bullet_color=#12345678 color=#bbccddee


# #############################################################
# ##   S  L  I  D  E  S
# #############################################################

# -------------------------------------------------------------
@popslide intro
@pop intro_title    text=Artificial Voices in Human Choices
@pop intro_subtitle text=Milestone 3
@pop intro_subtitle text=Dr. Carolin Kaiser, Rene Schallner


```

# prerequisites


Clone [zig-upaya](https://github.com/prime31/zig-upaya):

```bash
$ git clone --recursive https://github.com/prime31/zig-upaya/
```
Clone this repository:

```bash
$ git clone renerocksai/slides
```

Create a link to zig-upaya:

```bash
$ cd slides
$ ln -s ../zig-upaya
```

If you name the link differently, then modify the following line in `build.zig` accordingly:

```zig
const upaya_dir = "./zig-upaya/";
```

... and also this line in `src/main.zig`:

```zig
const Texture = @import("../zig-upaya/src/texture.zig").Texture;
```


Note: On Windows, you probably have to move the entire `zig-upaya` directory into the `slides` directory.

# build and run

```bash
$ zig build slides
```

To just build: `zig build`. This will create the executable `slides` in `./zig-cache/bin/`.

## Tested with: 
- zig `0.8.0-dev.1120+300ebbd56`
- zig `0.8.0-dev.1141+68e772647`
- zig-upaya [prime31/zig-upaya@154417379bfaa36f51c3b1b438fa73cf563d90f0](https://github.com/prime31/zig-upaya/commit/154417379bfaa36f51c3b1b438fa73cf563d90f0).

