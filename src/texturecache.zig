const zt = @import("zt");
const Texture = zt.gl.Texture;
const std = @import("std");
const gl = @import("gl");
const relpathToAbspath = @import("utils.zig").relpathToAbspath;

const allocator = std.heap.page_allocator;

var path2tex = std.StringHashMap(Texture).init(allocator);

// TODO: I am not sure anymore whether it is OK to have this cache alive across
//       multiple load / save cycles
//       well, it's a speedup for slide reloads!

// open img file relative to refpath (slideshow file)
pub fn getImg(p: []const u8, refpath: ?[]const u8) !?Texture {
    var tex: ?Texture = null;

    // std.log.debug("trying to load texture: {s}", .{p});
    if (path2tex.count() > 0) {
        if (path2tex.contains(p)) {
            return path2tex.get(p).?;
        }
    }
    var absp = try relpathToAbspath(p, refpath);
    tex = Texture.init(absp) catch null;
    if (tex) |*okTexture| {
        // okTexture.setLinearFilter();
        gl.glPixelStorei(gl.GL_UNPACK_ALIGNMENT, 1);
        okTexture.bind();
        const key = try allocator.dupe(u8, p);
        try path2tex.put(key, okTexture.*);
    }
    return tex;
}
