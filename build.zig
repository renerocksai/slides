const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;

// tell where you checked out zig-upaya
//    It needs to be within your "package" directory for zig to accept it.
//    I checked it out in the parent directory and placed a link here with
//    `ln -s ../zig-upaya`.
//    On Windows, you probably have to copy zig-upaya instead of linking to it.
//    For that case I've already put `zig-upaya/` into the .gitignore file.
const upaya_dir = "./zig-upaya/";

const upaya_build = @import(upaya_dir ++ "src/build.zig");

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});

    // use a different cache folder for macos arm builds
    b.cache_root = if (std.builtin.os.tag == .macos and std.builtin.arch == std.builtin.Arch.aarch64) "zig-arm-cache" else "zig-cache";

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

    upaya_build.addTests(b, target);
}

/// creates an exe with all the required dependencies
fn createExe(b: *Builder, target: std.build.Target, name: []const u8, source: []const u8) !void {
    // support for cli apps
    const is_cli = std.mem.endsWith(u8, name, "cli");

    var exe = b.addExecutable(name, source);
    exe.setBuildMode(b.standardReleaseOptions());
    exe.setOutputDir(std.fs.path.join(b.allocator, &[_][]const u8{ b.cache_root, "bin" }) catch unreachable);
    exe.setTarget(target);

    if (is_cli) {
        upaya_build.linkCommandLineArtifact(b, exe, target, "");
    } else {
        addUpayaToArtifact(b, exe, target, upaya_dir);
    }

    const run_cmd = exe.run();
    const exe_step = b.step(name, b.fmt("run {s}.zig", .{name}));
    exe_step.dependOn(&run_cmd.step);
    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}

pub fn addUpayaToArtifact(b: *Builder, exe: *std.build.LibExeObjStep, target: std.build.Target, comptime prefix_path: []const u8) void {
    if (prefix_path.len > 0 and !std.mem.endsWith(u8, prefix_path, "/")) @panic("prefix-path must end with '/' if it is not empty");
    upaya_build.linkArtifact(b, exe, target, prefix_path);
}
