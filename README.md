# Slides

My first steps creating a slideshow app in zig.



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

