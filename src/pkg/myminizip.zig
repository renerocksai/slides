const std = @import("std");
pub const ZipFnPair = extern struct {
    fnOnDisk: [*c]const u8,
    fnInZip: [*c]const u8,
};

pub extern fn hello() c_int;
pub extern fn zipIt(zipFileName: [*c]const u8, fnPairs: [*c]const ZipFnPair, count: c_int) c_int;

// run this in zig-out/bin, so path ../../README.md will be valid
pub fn demo() void {
    const pairs: [1]ZipFnPair = .{.{
        .fnOnDisk = "../../README.md",
        .fnInZip = "txt/README.md",
    }};
    const ret = zipIt("test.zip", pairs[0..], 1);
    std.log.debug("zipIt says {}", .{ret});
}
