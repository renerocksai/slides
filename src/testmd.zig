const std = @import("std");
const mdp = @import("markdownlineparser.zig");

usingnamespace mdp;

const test_text = "This _m_ is recognized";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = &arena.allocator;
    defer arena.deinit();

    var md: MdLineParser = .{};
    md.init(allocator);
    try md.parseLine(test_text);
    md.logSpans();
}
