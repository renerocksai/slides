const std = @import("std");
const embeds = @import("pptx_embeds.zig");
const minizip = @import("myminizip");

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
    const toCopy = embeds.initToCopy(std.heap.page_allocator) catch return;

    for (toCopy.items) |fdesc| {
        const dp = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ destpath, fdesc.filename });
        const file = try std.fs.cwd().createFile(dp, .{});
        errdefer file.close();
        try file.writeAll(fdesc.content);
        file.close();
    }
}

pub fn exportPptx(destpath: []const u8, slideshow_filp: []const u8, num_slides: usize, allocator: std.mem.Allocator) !void {
    {
        const embed = embeds.mod_cpy_app_xml;
        const dp = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ destpath, embed.filename });
        const numStr = try std.fmt.allocPrint(allocator, "{d}", .{num_slides});
        const content = try std.mem.replaceOwned(u8, allocator, embed.content, "$NUM_SLIDES", numStr);

        const file = try std.fs.cwd().createFile(dp, .{});
        errdefer file.close();
        try file.writeAll(content);
        file.close();
    }

    {
        const embed = embeds.mod_cpy_presentation_xml_rels;
        const dp = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ destpath, embed.filename });
        var i: usize = 1;
        var replacement: []const u8 = "";

        while (i < num_slides) : (i += 1) {
            const rid = try std.fmt.allocPrint(allocator, "{d}", .{i + 11});
            const current = try std.fmt.allocPrint(allocator, "<Relationship Id=\"rId{s}\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide{d}.xml\"/>", .{ rid, i + 1 });
            replacement = try std.fmt.allocPrint(allocator, "{s}{s}", .{ replacement, current });
        }

        const content = try std.mem.replaceOwned(u8, allocator, embed.content, "$RELATIONSHIPS", replacement);

        const file = try std.fs.cwd().createFile(dp, .{});
        errdefer file.close();
        try file.writeAll(content);
        file.close();
    }

    {
        const embed = embeds.mod_cpy_slide1_xml;
        var i: usize = 0;
        while (i < num_slides) : (i += 1) {
            const filename_start = try std.mem.replaceOwned(u8, allocator, embed.filename, "1.xml", "");
            const dp = try std.fmt.allocPrint(allocator, "{s}/{s}{d}.xml", .{ destpath, filename_start, i + 1 });

            const graphic_id = try std.fmt.allocPrint(allocator, "{d}", .{i + 3});
            const guid = try std.fmt.allocPrint(allocator, "6A92AC38-201A-B559-9037-63C6F3D779{X:0>2}", .{i & 255});
            const id = try std.fmt.allocPrint(allocator, "{d}", .{i + 1577499883});
            const descr = try std.fmt.allocPrint(allocator, "slides-generated image {d}", .{i});

            var content = try std.mem.replaceOwned(u8, allocator, embed.content, "$GRAPHIC_ID", graphic_id);
            content = try std.mem.replaceOwned(u8, allocator, content, "$GUID", guid);
            content = try std.mem.replaceOwned(u8, allocator, content, "$ID", id);
            content = try std.mem.replaceOwned(u8, allocator, content, "$GRAPHIC_DESC", descr);

            const file = try std.fs.cwd().createFile(dp, .{});
            errdefer file.close();
            try file.writeAll(content);
            file.close();
        }
    }
    {
        const embed = embeds.mod_cpy_slide1_xml_rels;
        var i: usize = 0;
        while (i < num_slides) : (i += 1) {
            const filename_start = try std.mem.replaceOwned(u8, allocator, embed.filename, "1.xml.rels", "");
            const dp = try std.fmt.allocPrint(allocator, "{s}/{s}{d}.xml.rels", .{ destpath, filename_start, i + 1 });

            const pngname = try std.fmt.allocPrint(allocator, "{s}_{d:0>4}.png", .{ std.fs.path.basename(slideshow_filp), i });

            var content = try std.mem.replaceOwned(u8, allocator, embed.content, "$IMG_NAME", pngname);

            const file = try std.fs.cwd().createFile(dp, .{});
            errdefer file.close();
            try file.writeAll(content);
            file.close();
        }
    }

    {
        const embed = embeds.mod_cpy_presentation_xml;
        const dp = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ destpath, embed.filename });
        var i: usize = 1;
        var replacement: []const u8 = "";

        while (i < num_slides) : (i += 1) {
            const current = try std.fmt.allocPrint(allocator, "<p:sldId id=\"{d}\" r:id=\"rId{}\"/>", .{ 256 + i, 11 + i });
            replacement = try std.fmt.allocPrint(allocator, "{s}{s}", .{ replacement, current });
        }

        const content = try std.mem.replaceOwned(u8, allocator, embed.content, "$SLIDE_IDS", replacement);

        const file = try std.fs.cwd().createFile(dp, .{});
        errdefer file.close();
        try file.writeAll(content);
        file.close();
    }

    {
        const embed = embeds.mod_cpy_Content_Types_xml;
        const dp = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ destpath, embed.filename });
        var i: usize = 1;
        var replacement: []const u8 = "";

        while (i < num_slides) : (i += 1) {
            const current = try std.fmt.allocPrint(allocator, "<Override PartName=\"/ppt/slides/slide{d}.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>", .{1 + i});
            replacement = try std.fmt.allocPrint(allocator, "{s}{s}", .{ replacement, current });
        }

        const content = try std.mem.replaceOwned(u8, allocator, embed.content, "$SLIDES", replacement);

        const file = try std.fs.cwd().createFile(dp, .{});
        errdefer file.close();
        try file.writeAll(content);
        file.close();
    }

    // Now, copy the images : TODO: make this a bit more sane
    var sourceFolder: std.fs.Dir = try std.fs.cwd().openDir("slide_shots", .{ .iterate = true });
    const destFolder = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ destpath, "ppt/media" });
    defer sourceFolder.close();
    var iterator: std.fs.Dir.Iterator = sourceFolder.iterate();
    while (iterator.next() catch return error.FolderError) |target| {
        if (target.kind == .File) {
            try copy("slide_shots", destFolder, target.name);
        }
    }
}
fn copy(from: []const u8, to: []const u8, filename: []const u8) !void {
    std.fs.cwd().makePath(to) catch return error.FolderError;
    var source = std.fs.cwd().openDir(from, .{}) catch return error.FileError;
    var dest = std.fs.cwd().openDir(to, .{}) catch return error.FileError;

    var sfile = source.openFile(filename, .{}) catch return error.FileError;
    defer sfile.close();
    var dfile = dest.openFile(filename, .{}) catch {
        source.copyFile(filename, dest, filename, .{}) catch return error.PermissionError;
        std.debug.print("COPY IMAGE: {s}/{s} to {s}/{s}\n", .{ from, filename, to, filename });
        return;
    };

    var sstat = sfile.stat() catch return error.FileError;
    var dstat = dfile.stat() catch return error.FileError;

    if (sstat.mtime > dstat.mtime) {
        dfile.close();
        dest.deleteFile(filename) catch return error.PermissionError;
        source.copyFile(filename, dest, filename, .{}) catch return error.PermissionError;
        std.debug.print("OVERWRITE: {s}\\{s} to {s}\\{s}\n", .{ from, filename, to, filename });
    } else {
        defer dfile.close();
        std.debug.print("SKIP: {s}\\{s}\n", .{ from, filename });
    }
}

pub fn zipIt(destpath: []const u8, zipPath: []const u8, allocator: std.mem.Allocator) !void {
    // open and walk dir, add file name pair as we go along
    _ = zipPath;
    const dir = try std.fs.cwd().openDir(destpath, .{ .iterate = true });
    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var fnPairs = std.ArrayList(minizip.ZipFnPair).init(allocator);
    while (try walker.next()) |entry| {
        if (entry.kind == .File) {
            std.log.debug("zip: {s}", .{entry.path});
            try fnPairs.append(.{
                .fnOnDisk = try std.fmt.allocPrintZ(allocator, "{s}/{s}", .{ destpath, entry.path }),
                .fnInZip = try std.fmt.allocPrintZ(allocator, "{s}", .{entry.path}),
            });
        }
    }
    const ret = minizip.zipIt(zipPath.ptr, fnPairs.items[0..].ptr, @intCast(i16, fnPairs.items.len));
    std.log.debug("minizip returned {}", .{ret});
}

pub fn zipItOldStyle(destpath: []const u8, zipPath: []const u8, allocator: std.mem.Allocator) !void {
    const args = [_][]const u8{
        "zip",
        // "-b",
        // destpath,
        "-9",
        "-r",
        "-v",
        "-q",
        zipPath,
        ".",
    };

    if (std.ChildProcess.init(args[0..], allocator)) |child| {
        defer child.deinit();
        child.cwd = destpath;

        if (child.spawnAndWait()) |_| {
            return;
        } else |err| {
            std.log.err("Unable to spawn and wait:  {any}", .{err});
            switch (err) {
                error.AccessDenied => {
                    std.log.err("AccessDenied", .{});
                },
                error.BadPathName => {
                    std.log.err("BadPathName", .{});
                },
                error.CurrentWorkingDirectoryUnlinked => {
                    std.log.err("CurrentWorkingDirectoryUnlinked", .{});
                },
                error.FileBusy => {
                    std.log.err("FileBusy", .{});
                },
                error.FileNotFound => {
                    std.log.err("FileNotFound", .{});
                },
                error.FileSystem => {
                    std.log.err("FileSystem", .{});
                },
                error.InvalidExe => {
                    std.log.err("InvalidExe", .{});
                },
                error.InvalidName => {
                    std.log.err("InvalidName", .{});
                },
                error.InvalidUserId => {
                    std.log.err("InvalidUserId", .{});
                },
                error.InvalidUtf8 => {
                    std.log.err("InvalidUtf8", .{});
                },
                error.IsDir => {
                    std.log.err("IsDir", .{});
                },
                error.NameTooLong => {
                    std.log.err("NameTooLong", .{});
                },
                error.NoDevice => {
                    std.log.err("NoDevice", .{});
                },
                error.NotDir => {
                    std.log.err("NotDir", .{});
                },
                error.OutOfMemory => {
                    std.log.err("OutOfMemory", .{});
                },
                error.PermissionDenied => {
                    std.log.err("PermissionDenied", .{});
                },
                error.ProcessFdQuotaExceeded => {
                    std.log.err("ProcessFdQuotaExceeded", .{});
                },
                error.ResourceLimitReached => {
                    std.log.err("ResourceLimitReached", .{});
                },
                error.SymLinkLoop => {
                    std.log.err("SymLinkLoop", .{});
                },
                error.SystemFdQuotaExceeded => {
                    std.log.err("SystemFdQuotaExceeded", .{});
                },
                error.SystemResources => {
                    std.log.err("SystemResources", .{});
                },
                error.Unexpected => {
                    std.log.err("Unexpected", .{});
                },
                error.WaitAbandoned => {
                    std.log.err("WaitAbandoned", .{});
                },
                error.WaitTimeOut => {
                    std.log.err("WaitTimeOut", .{});
                },
            }
        }
    } else |err| {
        std.log.err("Unable to init child process: {any}", .{err});
    }
}
