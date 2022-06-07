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
//const mod_cpy_app_xml
//const mod_cpy_Content_Types_xml
//const mod_cpy_presentation_xml_rels
//const mod_cpy_slide1_xml_rels
//const mod_cpy_slide1_xml
//const mod_cpy_presentation_xml

pub fn exportPptx(destpath: []const u8, slideshow_filp: []const u8, num_slides: usize, allocator: std.mem.Allocator) !void {
    // const pngname = std.fmt.allocPrintZ(G.allocator, "./slide_shots/{s}_{d:0>4}.png", .{ std.fs.path.basename(slideshow_filp), @intCast(u32, G.current_slide) }) catch null;
    _ = slideshow_filp;

    // app.xml
    {
        const embed = embeds.mod_cpy_app_xml;
        const dp = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ destpath, embed.filename });
        const numStr = try std.fmt.allocPrint(allocator, "{d}", .{num_slides});
        const content = try std.mem.replaceOwned(u8, allocator, embed.content, "$NUM_SLIDES", numStr);
        std.log.debug("trying {s}", .{dp});
        const file = try std.fs.cwd().createFile(dp, .{});
        std.log.debug("{s} created", .{dp});
        errdefer file.close();
        try file.writeAll(content);
        std.log.debug("{s} written", .{dp});
        file.close();
    }

    // ## ppt/_rels/presentation.xml.rels
    //
    // - Add a new <Relationship> like for slide1 with a new Id `"rId{ 11 + n }"`
    // - ==replace `$RELATIONSHIPS`==
    //
    // ```xml
    // <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
    // ```
    {
        const embed = embeds.mod_cpy_presentation_xml_rels;
        const dp = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ destpath, embed.filename });
        var i: usize = 1;
        var replacement: []const u8 = "";
        std.log.debug("trying {s}", .{dp});
        while (i < num_slides) : (i += 1) {
            const rid = try std.fmt.allocPrint(allocator, "{d}", .{i + 11});
            const current = try std.fmt.allocPrint(allocator, "<Relationship Id=\"rId{s}\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide{d}.xml\"/>", .{ rid, i + 1 });
            replacement = try std.fmt.allocPrint(allocator, "{s}{s}", .{ replacement, current });
        }
        const content = try std.mem.replaceOwned(u8, allocator, embed.content, "$RELATIONSHIPS", replacement);
        const file = try std.fs.cwd().createFile(dp, .{});
        std.log.debug("{s} created", .{dp});
        errdefer file.close();
        try file.writeAll(content);
        std.log.debug("{s} written", .{dp});
        file.close();
    }
    // ## ppt/slides/slide[1].xml -> slide[n].xml
    //
    // - Change `id="4" name="Grafik 4"`
    //   - to `id="{n}" name="Grafik {3 + n}descr="slides generated image {n}"`
    //   - replace ==$GRAPHIC_ID==
    //   - replace ==$GRAPHIC_DESC==
    // - Change `<a16 ... id={}` to a new guid
    //   - replace ==$GUID==
    //   - 6A92AC38-201A-B559-9037-63C6F3D7798E
    // - Change `<p14 ... val=""` to a new decimal id
    //   - replace ==$ID==
    //   - 1577499883
    {
        const embed = embeds.mod_cpy_slide1_xml;
        var i: usize = 0;
        while (i < num_slides) : (i += 1) {
            const filename_start = try std.mem.replaceOwned(u8, allocator, embed.filename, "1.xml", "");
            const dp = try std.fmt.allocPrint(allocator, "{s}/{s}{d}.xml", .{ destpath, filename_start, i + 1 });
            std.log.debug("trying {s}", .{dp});
            const graphic_id = try std.fmt.allocPrint(allocator, "{d}", .{i + 3});
            const guid = try std.fmt.allocPrint(allocator, "6A92AC38-201A-B559-9037-63C6F3D779{X:0>2}", .{i & 255});
            const id = try std.fmt.allocPrint(allocator, "{d}", .{i + 1577499883});
            const descr = try std.fmt.allocPrint(allocator, "slides-generated image {d}", .{i});

            var content = try std.mem.replaceOwned(u8, allocator, embed.content, "$GRAPHIC_ID", graphic_id);
            content = try std.mem.replaceOwned(u8, allocator, content, "$GUID", guid);
            content = try std.mem.replaceOwned(u8, allocator, content, "$ID", id);
            content = try std.mem.replaceOwned(u8, allocator, content, "$GRAPHIC_DESC", descr);
            const file = try std.fs.cwd().createFile(dp, .{});
            std.log.debug("{s} created", .{dp});
            errdefer file.close();
            try file.writeAll(content);
            std.log.debug("{s} written", .{dp});
            file.close();
        }
    }
    // ## ppt/slides/_rels/slide[n].xml.rels
    //
    // - Just copy and adjust the target path to the image -> rename to `image{n}.png`
    //   - replace ==$IMG_NAME==
    //const pngname = std.fmt.allocPrintZ(G.allocator, "./slide_shots/{s}_{d:0>4}.png", .{ std.fs.path.basename(slideshow_filp), @intCast(u32, G.current_slide) }) catch null;
    {
        const embed = embeds.mod_cpy_slide1_xml_rels;
        var i: usize = 0;
        while (i < num_slides) : (i += 1) {
            const filename_start = try std.mem.replaceOwned(u8, allocator, embed.filename, "1.xml.rels", "");
            const dp = try std.fmt.allocPrint(allocator, "{s}/{s}{d}.xml.rels", .{ destpath, filename_start, i + 1 });
            std.log.debug("trying {s}", .{dp});
            const pngname = try std.fmt.allocPrint(allocator, "{s}_{d:0>4}.png", .{ std.fs.path.basename(slideshow_filp), i });
            var content = try std.mem.replaceOwned(u8, allocator, embed.content, "$IMG_NAME", pngname);
            const file = try std.fs.cwd().createFile(dp, .{});
            std.log.debug("{s} created", .{dp});
            errdefer file.close();
            try file.writeAll(content);
            std.log.debug("{s} written", .{dp});
            file.close();
        }
    }
    //
    // ## ppt/presentation.xml
    //
    // - Add new `<p:sldId id="{ 256 + n }" r:id="rId{ 11 + n }" ...`
    //   - replace ==$SLIDE_IDS==
    {
        const embed = embeds.mod_cpy_presentation_xml;
        const dp = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ destpath, embed.filename });
        var i: usize = 1;
        var replacement: []const u8 = "";
        std.log.debug("trying {s}", .{dp});
        while (i < num_slides) : (i += 1) {
            const current = try std.fmt.allocPrint(allocator, "<p:sldId id=\"{d}\" r:id=\"rId{}\"/>", .{ 256 + i, 11 + i });
            replacement = try std.fmt.allocPrint(allocator, "{s}{s}", .{ replacement, current });
        }
        const content = try std.mem.replaceOwned(u8, allocator, embed.content, "$SLIDE_IDS", replacement);
        const file = try std.fs.cwd().createFile(dp, .{});
        std.log.debug("{s} created", .{dp});
        errdefer file.close();
        try file.writeAll(content);
        std.log.debug("{s} written", .{dp});
        file.close();
    }
    //
    // ## [Content_Types].xml
    //
    // - Add new tag for the new slides
    //   - replace ==$SLIDES==
    //
    // ```xml
    // <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
    // ```
    {
        const embed = embeds.mod_cpy_Content_Types_xml;
        const dp = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ destpath, embed.filename });
        var i: usize = 1;
        var replacement: []const u8 = "";
        std.log.debug("trying {s}", .{dp});
        while (i < num_slides) : (i += 1) {
            const current = try std.fmt.allocPrint(allocator, "<Override PartName=\"/ppt/slides/slide{d}.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>", .{1 + i});
            replacement = try std.fmt.allocPrint(allocator, "{s}{s}", .{ replacement, current });
        }
        const content = try std.mem.replaceOwned(u8, allocator, embed.content, "$SLIDES", replacement);
        const file = try std.fs.cwd().createFile(dp, .{});
        std.log.debug("{s} created", .{dp});
        errdefer file.close();
        try file.writeAll(content);
        std.log.debug("{s} written", .{dp});
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
