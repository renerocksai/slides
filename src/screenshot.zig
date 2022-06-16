const std = @import("std");
const gl = @import("gl");
const ig = @import("imgui");

const cpng = @cImport({
    @cInclude("png.h");
    @cInclude("stdio.h");
});

const PngWriteError = error{
    CreateWriteStructError,
    CreateInfoStructError,
};

pub fn pngVersionString() [:0]const u8 {
    return cpng.PNG_LIBPNG_VER_STRING;
}

pub fn screenShotPng(abspath: []const u8) !void {
    const width = @floatToInt(usize, ig.igGetIO().*.DisplaySize.x);
    const height = @floatToInt(usize, ig.igGetIO().*.DisplaySize.y);
    const size = width * height * 4;
    var buffer = std.heap.page_allocator.alloc(u8, size) catch |err| {
        std.log.debug("failed allocating {} bytes: {any}", .{ size, err });
        return err;
    };

    var fp = cpng.fopen(abspath.ptr, "wb");
    if (fp == null) {
        std.log.debug("could not create file", .{});
        return;
    }

    gl.glReadBuffer(gl.GL_FRONT);
    gl.glReadPixels(0, 0, @intCast(c_int, width), @intCast(c_int, height), gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, buffer.ptr);
    var png = cpng.png_create_write_struct(cpng.PNG_LIBPNG_VER_STRING, null, null, null);
    if (png == null) {
        return PngWriteError.CreateWriteStructError;
    }

    var info = cpng.png_create_info_struct(png);
    if (info == null) {
        return PngWriteError.CreateInfoStructError;
    }

    cpng.png_init_io(png, fp);

    // Output is 8bit depth, RGBA format.
    cpng.png_set_IHDR(
        png,
        info,
        @intCast(c_uint, width),
        @intCast(c_uint, height),
        8,
        cpng.PNG_COLOR_TYPE_RGBA,
        cpng.PNG_INTERLACE_NONE,
        cpng.PNG_COMPRESSION_TYPE_DEFAULT,
        cpng.PNG_FILTER_TYPE_DEFAULT,
    );
    var row_pointers = std.heap.page_allocator.alloc(cpng.png_bytep, height) catch unreachable;
    defer std.heap.page_allocator.free(row_pointers);

    var i: usize = 0;
    const pitch = 4 * width; // for 4 channels RGBA
    while (i < height) : (i += 1) {
        row_pointers[height - 1 - i] = @intToPtr([*c]u8, @ptrToInt(buffer.ptr) + i * pitch);
    }
    cpng.png_set_rows(png, info, row_pointers.ptr);
    cpng.png_write_info(png, info);
    cpng.png_write_image(png, row_pointers.ptr);
    // if a transform is to be done: png_write_png(png_ptr, info_ptr, transform, NULL);
    cpng.png_write_end(png, null);
    // cpng.flush(fp);
    _ = cpng.fclose(fp);
}

pub fn screenShotPngNoAlpha(abspath: []const u8) !void {
    const width = @floatToInt(usize, ig.igGetIO().*.DisplaySize.x);
    const height = @floatToInt(usize, ig.igGetIO().*.DisplaySize.y);
    const size = width * height * 3;
    var buffer = std.heap.page_allocator.alloc(u8, size) catch |err| {
        std.log.debug("failed allocating {} bytes: {any}", .{ size, err });
        return err;
    };

    var fp = cpng.fopen(abspath.ptr, "wb");
    if (fp == null) {
        std.log.debug("could not create file", .{});
        return;
    }

    gl.glReadBuffer(gl.GL_FRONT);
    gl.glReadPixels(0, 0, @intCast(c_int, width), @intCast(c_int, height), gl.GL_RGB, gl.GL_UNSIGNED_BYTE, buffer.ptr);
    var png = cpng.png_create_write_struct(cpng.PNG_LIBPNG_VER_STRING, null, null, null);
    if (png == null) {
        return PngWriteError.CreateWriteStructError;
    }

    var info = cpng.png_create_info_struct(png);
    if (info == null) {
        return PngWriteError.CreateInfoStructError;
    }

    cpng.png_init_io(png, fp);

    // Output is 8bit depth, RGBA format.
    cpng.png_set_IHDR(
        png,
        info,
        @intCast(c_uint, width),
        @intCast(c_uint, height),
        8,
        cpng.PNG_COLOR_TYPE_RGB,
        cpng.PNG_INTERLACE_NONE,
        cpng.PNG_COMPRESSION_TYPE_DEFAULT,
        cpng.PNG_FILTER_TYPE_DEFAULT,
    );
    var row_pointers = std.heap.page_allocator.alloc(cpng.png_bytep, height) catch unreachable;
    defer std.heap.page_allocator.free(row_pointers);

    var i: usize = 0;
    const pitch = 3 * width; // for 3 channels RGBA
    while (i < height) : (i += 1) {
        row_pointers[height - 1 - i] = @intToPtr([*c]u8, @ptrToInt(buffer.ptr) + i * pitch);
    }
    cpng.png_set_rows(png, info, row_pointers.ptr);
    cpng.png_write_info(png, info);
    cpng.png_write_image(png, row_pointers.ptr);
    // if a transform is to be done: png_write_png(png_ptr, info_ptr, transform, NULL);
    cpng.png_write_end(png, null);
    // cpng.flush(fp);
    _ = cpng.fclose(fp);
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
