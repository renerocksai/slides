const std = @import("std");
const slideszig = @import("slides.zig");
// for ImVec4 and stuff
const upaya = @import("upaya");

usingnamespace upaya.imgui;
usingnamespace slideszig;

pub const ParseError = error{Generic};

pub fn constructSlidesFromBuf(input: []const u8, slideshow: *SlideShow, allocator: *std.mem.Allocator) !void {
    var start: usize = if (std.mem.startsWith(u8, input, "\xEF\xBB\xBF")) 3 else 0;
    var it = std.mem.tokenize(input[start..], "\n\r");
    var i: usize = 0;
    while (it.next()) |line| {
        i += 1;
        // std.log.debug("P {d}: {s}", .{ i, line });
        if (std.mem.startsWith(u8, line, "#")) {
            continue;
        }

        if (std.mem.startsWith(u8, line, "@font")) {
            parseFontGlobals(line, slideshow, allocator) catch continue;
        }

        if (std.mem.startsWith(u8, line, "@underline_width=")) {
            parseUnderlineWidth(line, slideshow, allocator) catch continue;
        }
        if (std.mem.startsWith(u8, line, "@color=")) {
            parseDefaultColor(line, slideshow, allocator) catch continue;
        }
    }
    return;
}

fn parseFontGlobals(line: []const u8, slideshow: *SlideShow, allocator: *std.mem.Allocator) !void {
    var it = std.mem.tokenize(line, "=");
    if (it.next()) |word| {
        if (std.mem.eql(u8, word, "@fontsize")) {
            if (it.next()) |sizestr| {
                slideshow.default_fontsize = try std.fmt.parseInt(i32, sizestr, 10);
                std.log.debug("global fontsize: {d}", .{slideshow.default_fontsize});
            }
        }
        if (std.mem.eql(u8, word, "@font")) {
            if (it.next()) |font| {
                slideshow.default_font = try allocator.dupe(u8, font);
                std.log.debug("global font: {s}", .{slideshow.default_font});
            }
        }
        if (std.mem.eql(u8, word, "@font_bold")) {
            if (it.next()) |font_bold| {
                slideshow.default_font_bold = try allocator.dupe(u8, font_bold);
                std.log.debug("global font_bold: {s}", .{slideshow.default_font_bold});
            }
        }
        if (std.mem.eql(u8, word, "@font_italic")) {
            if (it.next()) |font_italic| {
                slideshow.default_font_italic = try allocator.dupe(u8, font_italic);
                std.log.debug("global font_italic: {s}", .{slideshow.default_font_italic});
            }
        }
        if (std.mem.eql(u8, word, "@font_bold_italic")) {
            if (it.next()) |font_bold_italic| {
                slideshow.default_font_bold_italic = try allocator.dupe(u8, font_bold_italic);
                std.log.debug("global font_bold_italic: {s}", .{slideshow.default_font_bold_italic});
            }
        }
    }
}

fn parseUnderlineWidth(line: []const u8, slideshow: *SlideShow, allocator: *std.mem.Allocator) !void {
    var it = std.mem.tokenize(line, "=");
    if (it.next()) |word| {
        if (std.mem.eql(u8, word, "@underline_width")) {
            if (it.next()) |sizestr| {
                slideshow.default_underline_width = try std.fmt.parseInt(i32, sizestr, 10);
                std.log.debug("global underline_width: {d}", .{slideshow.default_underline_width});
            }
        }
    }
}

fn parseDefaultColor(line: []const u8, slideshow: *SlideShow, allocator: *std.mem.Allocator) !void {
    var it = std.mem.tokenize(line, "=");
    if (it.next()) |word| {
        if (std.mem.eql(u8, word, "@color")) {
            slideshow.default_color = try parseColor(line[1..], allocator);
            std.log.debug("global default_color: {any}", .{slideshow.default_color});
        }
    }
}

fn parseColor(s: []const u8, allocator: *std.mem.Allocator) !ImVec4 {
    var it = std.mem.tokenize(s, "=");
    var ret = ImVec4{};
    if (it.next()) |word| {
        if (std.mem.eql(u8, word, "color")) {
            if (it.next()) |colorstr| {
                if (colorstr.len != 9 or colorstr[0] != '#') {
                    std.log.debug("color string '{s}' not 9 chars long or missing #", .{colorstr});
                    return ParseError.Generic;
                }
                var temp: ImVec4 = undefined;
                var coloru32 = try std.fmt.parseInt(c_uint, colorstr[1..], 16);
                igColorConvertU32ToFloat4(&temp, coloru32);
                ret.x = temp.w;
                ret.y = temp.z;
                ret.z = temp.y;
                ret.w = temp.x;
            }
        }
    }
    return ret;
}
