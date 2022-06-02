const zt = @import("zt");
const Texture = zt.gl.Texture;
const std = @import("std");
const gl = @import("gl");

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
    // std.log.debug("trying to load: {s} with refpath: {s} -> {s}", .{ p, refpath, absp });
    tex = Texture.init(absp) catch null;
    if (tex) |*okTexture| {
        // std.log.debug("storing {s} as {any}", .{ p, okTexture });
        // okTexture.setLinearFilter();
        gl.glPixelStorei(gl.GL_UNPACK_ALIGNMENT, 1);
        okTexture.bind();
        const key = try allocator.dupe(u8, p);
        try path2tex.put(key, okTexture.*);
    }
    return tex;
}

/// note that you need to dupe this if you store it somewhere
pub fn relpathToAbspath(relpath: []const u8, refpath: ?[]const u8) ![]const u8 {
    var absp: []const u8 = undefined;
    const static_buffer = struct {
        var b: [1024]u8 = undefined;
    };

    if (refpath) |rp| {
        const pwd = std.fs.path.dirname(rp);
        if (pwd == null) {
            absp = relpath;
        } else {
            absp = try std.fmt.bufPrint(&static_buffer.b, "{s}{c}{s}", .{ pwd, std.fs.path.sep, relpath });
        }
    } else {
        absp = relpath;
    }
    return absp;
}
