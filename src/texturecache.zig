const upaya = @import("upaya");
const Texture = upaya.Texture;
const std = @import("std");

const allocator = std.heap.page_allocator;

var path2tex = std.StringHashMap(*upaya.Texture).init(allocator);

// open img file relative to refpath (slideshow file)
pub fn getImg(p: []const u8, refpath: ?[]const u8) !*upaya.Texture {
    if (path2tex.contains(p)) {
        return path2tex.get(p).?;
    }
    var absp: []const u8 = undefined;
    if (refpath) |rp| {
        var pwd_b: [1024]u8 = undefined;
        const pwd = std.fs.path.dirname(rp);
        if (pwd == null) {
            absp = p;
        } else {
            // std.log.debug("pwd of: {s} is {any}", .{ rp, pwd });
            var buf: [1024]u8 = undefined;
            absp = try std.fmt.bufPrint(&buf, "{s}{c}{s}", .{ pwd, std.fs.path.sep, p });
        }
    } else {
        absp = p;
    }
    // std.log.debug("trying to load: {s} with refpath: {s} -> {s}", .{ p, refpath, absp });
    var tex = try texFromFile(absp, .nearest);
    try path2tex.put(p, tex);
    return tex;
}

pub fn texFromFile(file: []const u8, filter: Texture.Filter) !*Texture {
    const image_contents = try upaya.fs.read(allocator, file);

    var w: c_int = undefined;
    var h: c_int = undefined;
    var channels: c_int = undefined;
    const load_res = upaya.stb.stbi_load_from_memory(image_contents.ptr, @intCast(c_int, image_contents.len), &w, &h, &channels, 4);
    if (load_res == null) return error.ImageLoadFailed;
    defer upaya.stb.stbi_image_free(load_res);

    var tex: ?Texture = Texture.initWithData(load_res[0..@intCast(usize, w * h * channels)], w, h, filter);
    var ret: *Texture = try allocator.create(Texture);
    ret.* = tex.?;
    return ret;
}
