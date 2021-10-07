const std = @import("std");

pub fn flameShotLinux(alloc: *std.mem.Allocator) !bool {
    const args = [_][]const u8{
        "/usr/bin/flameshot",
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
