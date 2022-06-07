const std = @import("std");
const embeds = @import("pptx_embeds.zig");

fn ensureDestPaths(destpath: []const u8, allocator: std.mem.Allocator) !void {
    var cwd = std.fs.cwd();
    if (cwd.deleteTree(destpath)) {} else |err| {
        std.log.err("Warning: Unable to delete directory {s} : {s}", .{ destpath, err });
    }
    try cwd.makeDir(destpath);
    try cwd.makePath(try std.fmt.allocPrint(allocator, "{s}/customXml/_rels", .{destpath}));
    try cwd.makePath(try std.fmt.allocPrint(allocator, "{s}/docProps", .{destpath}));
    try cwd.makePath(try std.fmt.allocPrint(allocator, "{s}/ppt/media", .{destpath}));
    try cwd.makePath(try std.fmt.allocPrint(allocator, "{s}/ppt/_rels", .{destpath}));
    try cwd.makePath(try std.fmt.allocPrint(allocator, "{s}/ppt/slideLayouts/_rels", .{destpath}));
    try cwd.makePath(try std.fmt.allocPrint(allocator, "{s}/ppt/slideMasters/_rels", .{destpath}));
    try cwd.makePath(try std.fmt.allocPrint(allocator, "{s}/ppt/slides/_rels", .{destpath}));
    try cwd.makePath(try std.fmt.allocPrint(allocator, "{s}/ppt/theme", .{destpath}));
    try cwd.makePath(try std.fmt.allocPrint(allocator, "{s}/slides/_rels", .{destpath}));
    try cwd.makePath(try std.fmt.allocPrint(allocator, "{s}/_rels", .{destpath}));
}

pub fn copyFixedAssetsTo(destpath: []const u8, allocator: std.mem.Allocator) !void {
    try ensureDestPaths(destpath, allocator);
    std.log.debug("created dirs", .{});
    const toCopy = embeds.initToCopy(std.heap.page_allocator) catch return;

    for (toCopy.items) |fdesc| {
        const dp = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ destpath, fdesc.filename });
        std.log.debug("trying {s}", .{dp});
        const file = try std.fs.cwd().createFile(dp, .{});
        std.log.debug("{s} created", .{dp});
        errdefer file.close();
        try file.writeAll(fdesc.content);
        std.log.debug("{s} written", .{dp});
        file.close();
    }
}
