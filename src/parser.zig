const std = @import("std");
const mem = std.mem;

// TODO: @push and @pop:
//       @bg "background.png"
//       @fontSize 16
//       @push "default slide"
//       ...
//       @pop "default slide"
//       @text .....

const slideszig = @import("slides.zig");
usingnamespace slideszig;

pub fn constructSlidesFromBuf(input: []const u8, slideshow: *SlideShow, allocator: *mem.Allocator) !void {
    var start: usize = if (mem.startsWith(u8, input, "\xEF\xBB\xBF")) 3 else 0;
    var it = mem.tokenize(input[start..], "\n\r");
    var i: usize = 0;
    while (it.next()) |line| {
        i += 1;
        //        std.log.info("{d}: {s}", .{ i + 1, line });
        if (mem.startsWith(u8, line, "#")) {
            std.log.debug("{d}: ignored comment {s}", .{ i, line });
            continue;
        }
    }
    return;
}
