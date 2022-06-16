const std = @import("std");
const fs = std.fs;
const ztBuild = @import("./ZT/build.zig");
const Builder = std.build.Builder;

pub const filedlgPkg = std.build.Pkg{ .name = "filedialog", .path = std.build.FileSource{ .path = getRelativePath() ++ "src/pkg/filedialog.zig" }, .dependencies = &[_]std.build.Pkg{ztBuild.imguiPkg} };

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

    exe.addIncludeDir(path ++ "./src/dep/libpng-1.6.37");
    const libPng = try addLibPng(exe);
    exe.linkLibrary(libPng);

    exe.addPackage(filedlgPkg);
    ztBuild.link(exe);

    const run_cmd = exe.run();
    const exe_step = b.step(name, b.fmt("run {s}.zig", .{name}));
    exe_step.dependOn(&run_cmd.step);
    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
    ztBuild.addBinaryContent("ZT/example/assets") catch unreachable;
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
    try copy("src/dep/libpng-1.6.37/scripts", "src/dep/libpng-1.6.37", "pnglibconf.h.prebuilt", "pnglibconf.h");

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

fn copy(from: []const u8, to: []const u8, filename: []const u8, destfilename: []const u8) !void {
    fs.cwd().makePath(to) catch return error.FolderError;
    var source = fs.cwd().openDir(from, .{}) catch return error.FileError;
    var dest = fs.cwd().openDir(to, .{}) catch return error.FileError;

    var sfile = source.openFile(filename, .{}) catch return error.FileError;
    defer sfile.close();
    var dfile = dest.openFile(destfilename, .{}) catch {
        std.debug.print("TRYING: {s}/{s} to {s}/{s}\n", .{ from, filename, to, filename });
        source.copyFile(filename, dest, destfilename, .{}) catch return error.PermissionError;
        std.debug.print("COPY: {s}/{s} to {s}/{s}\n", .{ from, filename, to, filename });
        return;
    };

    var sstat = sfile.stat() catch return error.FileError;
    var dstat = dfile.stat() catch return error.FileError;

    if (sstat.mtime > dstat.mtime) {
        dfile.close();
        dest.deleteFile(filename) catch return error.PermissionError;
        source.copyFile(filename, dest, destfilename, .{}) catch return error.PermissionError;
        std.debug.print("OVERWRITE: {s}\\{s} to {s}\\{s}\n", .{ from, filename, to, filename });
    } else {
        defer dfile.close();
        std.debug.print("SKIP: {s}\\{s}\n", .{ from, filename });
    }
}
