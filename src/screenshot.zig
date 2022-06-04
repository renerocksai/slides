const std = @import("std");
const gl = @import("gl");
const ig = @import("imgui");
pub fn screenShot() !void {
    //
    const width = @floatToInt(usize, ig.igGetIO().*.DisplaySize.x);
    const height = @floatToInt(usize, ig.igGetIO().*.DisplaySize.y);
    const size = width * height * 3;
    var buffer = std.heap.page_allocator.alloc(u8, size) catch |err| {
        std.log.debug("failed allocating {} bytes: {any}", .{ size, err });
        return;
    };
    std.log.debug("allocated buffer for screenshot :{}x{}x3 = {} -> {}", .{ width, height, size, buffer.len });
    var file = std.fs.cwd().createFile("screenshot.bmp", .{ .truncate = true }) catch |err| {
        std.log.debug("could not create file: {any}", .{err});
        return;
        // return err;
    };
    gl.glReadBuffer(gl.GL_FRONT);
    gl.glReadPixels(0, 0, @intCast(c_int, width), @intCast(c_int, height), gl.GL_RGB, gl.GL_UNSIGNED_BYTE, buffer.ptr);

    std.log.debug("created file: {}", .{file});
    defer file.close();

    const howmany = file.writeAll(buffer[0..buffer.len]) catch |err| {
        std.log.debug("could not write to file: {any}", .{err});
    };
    std.log.debug("write to file file: {} bytes", .{howmany});
}

pub fn flameShotLinux(alloc: std.mem.Allocator) !bool {
    const args = [_][]const u8{
        "/run/current-system/sw/bin/flameshot",
        "full",
        "-p",
        "/tmp/slide_shots",
    };

    if (std.ChildProcess.init(args[0..], alloc)) |child| {
        defer child.deinit();

        // TODO: this only works in debug builds
        // release builds return unexpected (literally) errors
        // one release mode, release-fast I think, returns some panic in thread
        if (child.spawnAndWait()) |_| {
            return true;
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
    return false;
}
