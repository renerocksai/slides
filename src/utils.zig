const std = @import("std");

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
