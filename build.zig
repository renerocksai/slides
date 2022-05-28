const std = @import("std");
const ztBuild = @import("./ZT/build.zig");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});

    // use a different cache folder for macos arm builds
    // b.cache_root = if (std.builtin.os.tag == .macos and std.builtin.arch == std.builtin.Arch.aarch64) "zig-arm-cache" else "zig-cache";
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
    exe.setBuildMode(b.standardReleaseOptions());
    exe.setOutputDir(std.fs.path.join(b.allocator, &[_][]const u8{ b.cache_root, "bin" }) catch unreachable);
    exe.setTarget(target);

    ztBuild.link(exe);

    const run_cmd = exe.run();
    const exe_step = b.step(name, b.fmt("run {s}.zig", .{name}));
    exe_step.dependOn(&run_cmd.step);
    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
    ztBuild.addBinaryContent("ZT/example/assets") catch unreachable;
}
