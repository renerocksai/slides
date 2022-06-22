const std = @import("std");
const fs = std.fs;
const ztBuild = @import("./ZT/build.zig");
const Builder = std.build.Builder;

pub const filedlgPkg = std.build.Pkg{ .name = "filedialog", .path = std.build.FileSource{ .path = getRelativePath() ++ "src/pkg/filedialog.zig" }, .dependencies = &[_]std.build.Pkg{ztBuild.imguiPkg} };

pub const myMiniZipPkg = std.build.Pkg{ .name = "myminizip", .path = std.build.FileSource{ .path = getRelativePath() ++ "src/pkg/myminizip.zig" }, .dependencies = &[_]std.build.Pkg{} };

fn getRelativePath() []const u8 {
    comptime var src: std.builtin.SourceLocation = @src();
    return std.fs.path.dirname(src.file).? ++ std.fs.path.sep_str;
}

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});

    b.cache_root = "zig-cache";

    // declare optional other zig executables here
    // format is: executable_name, path_to_zig_file
    const examples = [_][2][]const u8{
        [_][]const u8{ "slides", "src/main.zig" },
    };

    for (examples) |example, i| {
        createExe(b, target, example[0], example[1]) catch unreachable;

        // first element in the list is added as "run" so "zig build run" works
        if (i == 0) createExe(b, target, "run", example[1]) catch unreachable;
    }
}

/// creates an exe with all the required dependencies
fn createExe(b: *Builder, target: std.zig.CrossTarget, name: []const u8, source: []const u8) !void {
    var exe = b.addExecutable(name, source);
    comptime var path = getRelativePath();

    exe.setBuildMode(b.standardReleaseOptions());
    exe.setOutputDir(std.fs.path.join(b.allocator, &[_][]const u8{ b.cache_root, "bin" }) catch unreachable);
    exe.setTarget(target);

    exe.linkLibrary(filedialogLibrary(exe));

    exe.linkLibrary(addZlib(exe));

    // to be able to include the libPng headers:
    exe.addIncludeDir(path ++ "./src/dep/libpng-1.6.37");
    const libPng = try addLibPng(exe);
    exe.linkLibrary(libPng);

    const libMyMiniZip = try addLibMyMiniZip(exe);
    exe.linkLibrary(libMyMiniZip);

    exe.addPackage(filedlgPkg);
    exe.addPackage(myMiniZipPkg);
    ztBuild.link(exe);

    const run_cmd = exe.run();
    const exe_step = b.step(name, b.fmt("run {s}.zig", .{name}));
    exe_step.dependOn(&run_cmd.step);
    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
    addBinaryContent("assets") catch unreachable;
}

// Filedialog
pub fn filedialogLibrary(exe: *std.build.LibExeObjStep) *std.build.LibExeObjStep {
    comptime var path = getRelativePath();
    var b = exe.builder;
    var target = exe.target;
    var filedialog = b.addStaticLibrary("filedialog", null);
    filedialog.linkLibC();
    filedialog.linkSystemLibrary("c++");

    // Generate flags.
    var flagContainer = std.ArrayList([]const u8).init(std.heap.page_allocator);
    if (b.is_release) flagContainer.append("-Os") catch unreachable;
    flagContainer.append("-Wno-return-type-c-linkage") catch unreachable;
    flagContainer.append("-fno-sanitize=undefined") catch unreachable;

    // Link libraries.
    if (target.isWindows()) {
        filedialog.linkSystemLibrary("winmm");
        filedialog.linkSystemLibrary("user32");
        filedialog.linkSystemLibrary("imm32");
        filedialog.linkSystemLibrary("gdi32");
    }

    if (target.isDarwin()) {
        // !! Mac TODO
        // Here we need to add the include the system libs needed for mac filedialog
    }

    // Include dirs.
    filedialog.addIncludeDir(path ++ "src/dep/filedialog");
    if (target.isWindows()) {
        filedialog.addIncludeDir(path ++ "src/dep/filedialog/dirent");
    }
    filedialog.addIncludeDir(path ++ "src/dep/filedialog/stb");
    filedialog.addIncludeDir(path ++ "ZT/src/dep/cimgui/imgui");

    // Add C
    filedialog.addCSourceFiles(&.{
        path ++ "src/dep/filedialog/ImGuiFileDialog.cpp",
    }, flagContainer.items);

    return filedialog;
}

pub fn addZlib(exe: *std.build.LibExeObjStep) *std.build.LibExeObjStep {
    comptime var path = getRelativePath();
    var b = exe.builder;
    var target = exe.target;
    var libz = b.addStaticLibrary("z", null);
    libz.linkLibC();

    // Generate flags.
    var flagContainer = std.ArrayList([]const u8).init(std.heap.page_allocator);
    if (b.is_release) flagContainer.append("-Os") catch unreachable;
    flagContainer.append("-Wno-return-type-c-linkage") catch unreachable;
    flagContainer.append("-fno-sanitize=undefined") catch unreachable;

    // Link libraries.
    if (target.isWindows()) {
        // TODO
    }

    if (target.isDarwin()) {
        // !! Mac TODO
        // Here we need to add the include the system libs needed for mac libz
    }

    // Include dirs.
    libz.addIncludeDir(path ++ "src/dep/zlib-1.2.12");

    // Add C
    libz.addCSourceFiles(&.{
        path ++ "src/dep/zlib-1.2.12/adler32.c",
        path ++ "src/dep/zlib-1.2.12/crc32.c",
        path ++ "src/dep/zlib-1.2.12/deflate.c",
        path ++ "src/dep/zlib-1.2.12/infback.c",
        path ++ "src/dep/zlib-1.2.12/inffast.c",
        path ++ "src/dep/zlib-1.2.12/inflate.c",
        path ++ "src/dep/zlib-1.2.12/inftrees.c",
        path ++ "src/dep/zlib-1.2.12/trees.c",
        path ++ "src/dep/zlib-1.2.12/zutil.c",
    }, flagContainer.items);

    return libz;
}

pub fn addLibPng(exe: *std.build.LibExeObjStep) !*std.build.LibExeObjStep {
    comptime var path = getRelativePath();
    var b = exe.builder;
    var target = exe.target;
    var libPng = b.addStaticLibrary("png", null);
    libPng.linkLibC();

    // Generate flags.
    var flagContainer = std.ArrayList([]const u8).init(std.heap.page_allocator);
    if (b.is_release) flagContainer.append("-Os") catch unreachable;
    flagContainer.append("-Wno-return-type-c-linkage") catch unreachable;
    flagContainer.append("-fno-sanitize=undefined") catch unreachable;

    // Link libraries.
    if (target.isWindows()) {
        // TODO
    }

    if (target.isDarwin()) {
        // !! Mac TODO
        // Here we need to add the include the system libs needed for mac libPng
    }

    // Include dirs.
    libPng.addIncludeDir(path ++ "src/dep/libpng-1.6.37");
    libPng.addIncludeDir(path ++ "src/dep/zlib-1.2.12");

    // generate pnglibconf.h from pnglibconf.h.prebuilt
    try ensureCopied("src/dep/libpng-1.6.37/scripts", "src/dep/libpng-1.6.37", "pnglibconf.h.prebuilt", "pnglibconf.h");

    // Add C
    libPng.addCSourceFiles(&.{
        path ++ "./src/dep/libpng-1.6.37/png.c",
        path ++ "./src/dep/libpng-1.6.37/pngerror.c",
        path ++ "./src/dep/libpng-1.6.37/pngget.c",
        path ++ "./src/dep/libpng-1.6.37/pngmem.c",
        path ++ "./src/dep/libpng-1.6.37/pngpread.c",
        path ++ "./src/dep/libpng-1.6.37/pngread.c",
        path ++ "./src/dep/libpng-1.6.37/pngrio.c",
        path ++ "./src/dep/libpng-1.6.37/pngrtran.c",
        path ++ "./src/dep/libpng-1.6.37/pngrutil.c",
        path ++ "./src/dep/libpng-1.6.37/pngset.c",
        path ++ "./src/dep/libpng-1.6.37/pngtrans.c",
        path ++ "./src/dep/libpng-1.6.37/pngwio.c",
        path ++ "./src/dep/libpng-1.6.37/pngwrite.c",
        path ++ "./src/dep/libpng-1.6.37/pngwtran.c",
        path ++ "./src/dep/libpng-1.6.37/pngwutil.c",
    }, flagContainer.items);

    return libPng;
}
pub fn addLibMyMiniZip(exe: *std.build.LibExeObjStep) !*std.build.LibExeObjStep {
    comptime var path = getRelativePath();
    var b = exe.builder;
    var target = exe.target;
    var libMyMiniZip = b.addStaticLibrary("myminizip", null);
    libMyMiniZip.linkLibC();

    // Generate flags.
    var flagContainer = std.ArrayList([]const u8).init(std.heap.page_allocator);
    if (b.is_release) flagContainer.append("-Os") catch unreachable;
    flagContainer.append("-Wno-return-type-c-linkage") catch unreachable;
    flagContainer.append("-fno-sanitize=undefined") catch unreachable;

    // Link libraries.
    if (target.isWindows()) {
        // TODO
    }

    if (target.isDarwin()) {
        // !! Mac TODO
        // Here we need to add the include the system libs needed for mac libMyMiniZip
    }

    // Include dirs.
    libMyMiniZip.addIncludeDir(path ++ "src/dep/zlib-1.2.12");
    libMyMiniZip.addIncludeDir(path ++ "src/dep/zlib-1.2.12/contrib/minizip");

    // Add C
    libMyMiniZip.addCSourceFiles(&.{
        path ++ "./src/dep/zlib-1.2.12/contrib/minizip/zip.c",
        path ++ "./src/dep/zlib-1.2.12/contrib/minizip/ioapi.c",
        path ++ "./src/pkg/myminizip/myminizip.c",
    }, flagContainer.items);

    return libMyMiniZip;
}

// adaption from the ztBuild version: keep dirname of asset folder
pub fn addBinaryContent(comptime baseContentPath: []const u8) ztBuild.AddContentErrors!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const zigBin: []const u8 = std.fs.path.join(gpa.allocator(), &[_][]const u8{ "zig-out", "bin" }) catch return error.FolderError;
    defer gpa.allocator().free(zigBin);
    fs.cwd().makePath(zigBin) catch return error.FolderError;

    var sourceFolder: fs.Dir = fs.cwd().openDir(baseContentPath, .{ .iterate = true }) catch return error.FolderError;
    defer sourceFolder.close();
    var iterator: fs.Dir.Iterator = sourceFolder.iterate();
    while (iterator.next() catch return error.FolderError) |target| {
        var x: fs.Dir.Entry = target;
        if (x.kind == .Directory) {
            const source: []const u8 = std.fs.path.join(gpa.allocator(), &[_][]const u8{ baseContentPath, x.name }) catch return error.RecursionError;
            const targetFolder: []const u8 = std.fs.path.join(gpa.allocator(), &[_][]const u8{ zigBin, baseContentPath, x.name }) catch return error.RecursionError;
            defer gpa.allocator().free(source);
            defer gpa.allocator().free(targetFolder);
            try innerAddContent(gpa.allocator(), source, targetFolder);
        }
        if (x.kind == .File) {
            const targetFolder: []const u8 = std.fs.path.join(gpa.allocator(), &[_][]const u8{ zigBin, baseContentPath }) catch return error.RecursionError;
            try copy(baseContentPath, targetFolder, x.name);
        }
    }
}
fn innerAddContent(allocator: std.mem.Allocator, folder: []const u8, dest: []const u8) ztBuild.AddContentErrors!void {
    var sourceFolder: fs.Dir = fs.cwd().openDir(folder, .{ .iterate = true }) catch return error.FolderError;
    defer sourceFolder.close();

    var iterator: fs.Dir.Iterator = sourceFolder.iterate();
    while (iterator.next() catch return error.FolderError) |target| {
        var x: fs.Dir.Entry = target;
        if (x.kind == .Directory) {
            const source: []const u8 = std.fs.path.join(allocator, &[_][]const u8{ folder, x.name }) catch return error.RecursionError;
            const targetFolder: []const u8 = std.fs.path.join(allocator, &[_][]const u8{ dest, x.name }) catch return error.RecursionError;
            defer allocator.free(source);
            defer allocator.free(targetFolder);
            try innerAddContent(allocator, source, targetFolder);
        }
        if (x.kind == .File) {
            try copy(folder, dest, x.name);
        }
    }
}
fn copy(from: []const u8, to: []const u8, filename: []const u8) ztBuild.AddContentErrors!void {
    fs.cwd().makePath(to) catch return error.FolderError;
    var source = fs.cwd().openDir(from, .{}) catch return error.FileError;
    var dest = fs.cwd().openDir(to, .{}) catch return error.FileError;

    var sfile = source.openFile(filename, .{}) catch return error.FileError;
    defer sfile.close();
    var dfile = dest.openFile(filename, .{}) catch {
        source.copyFile(filename, dest, filename, .{}) catch return error.PermissionError;
        std.debug.print("COPY: {s}/{s} to {s}/{s}\n", .{ from, filename, to, filename });
        return;
    };

    var sstat = sfile.stat() catch return error.FileError;
    var dstat = dfile.stat() catch return error.FileError;

    if (sstat.mtime > dstat.mtime) {
        dfile.close();
        dest.deleteFile(filename) catch return error.PermissionError;
        source.copyFile(filename, dest, filename, .{}) catch return error.PermissionError;
        std.debug.print("OVERWRITE: {s}/{s} to {s}/{s}\n", .{ from, filename, to, filename });
    } else {
        defer dfile.close();
        std.debug.print("SKIP: {s}/{s}\n", .{ from, filename });
    }
}

// this is just for a header file of libpng.
fn ensureCopied(from: []const u8, to: []const u8, filename: []const u8, destfilename: []const u8) !void {
    fs.cwd().makePath(to) catch return error.FolderError;
    var source = fs.cwd().openDir(from, .{}) catch return error.FileError;
    var dest = fs.cwd().openDir(to, .{}) catch return error.FileError;

    var sfile = source.openFile(filename, .{}) catch return error.FileError;
    defer sfile.close();
    // var dfile = dest.openFile(destfilename, .{}) catch {
    _ = dest.openFile(destfilename, .{}) catch {
        std.debug.print("TRYING: {s}/{s} to {s}/{s}\n", .{ from, filename, to, filename });
        source.copyFile(filename, dest, destfilename, .{}) catch return error.PermissionError;
        std.debug.print("COPY: {s}/{s} to {s}/{s}\n", .{ from, filename, to, filename });
        return;
    };
}
