const std = @import("std");
const slideszig = @import("slides.zig");
// for ImVec4 and stuff
const upaya = @import("upaya");

usingnamespace upaya.imgui;
usingnamespace slideszig;

pub const ParserError = error{Internal};

const ParserContext = struct {
    allocator: *std.mem.Allocator,
    first_slide: bool = true,

    slideshow: *SlideShow,
    push_contexts: std.StringHashMap(ItemContext),
    push_slides: std.StringHashMap(*Slide),

    current_context: ItemContext = ItemContext{},
    current_slide: *Slide,

    fn commitSlide(self: *ParserContext, slide: *Slide) !void {
        try self.slideshow.slides.append(slide);
    }
};

pub fn constructSlidesFromBuf(input: []const u8, slideshow: *SlideShow, allocator: *std.mem.Allocator) !void {
    var start: usize = if (std.mem.startsWith(u8, input, "\xEF\xBB\xBF")) 3 else 0;
    var it = std.mem.tokenize(input[start..], "\n\r");
    var i: usize = 0;

    var context = ParserContext{
        .allocator = allocator,
        .slideshow = slideshow,
        .push_contexts = std.StringHashMap(ItemContext).init(allocator),
        .push_slides = std.StringHashMap(*Slide).init(allocator),
        .current_slide = try Slide.new(allocator),
    };

    while (it.next()) |line_untrimmed| {
        const line = std.mem.trimRight(u8, line_untrimmed, " \t");
        i += 1;
        // std.log.debug("P {d}: {s}", .{ i, line });
        if (std.mem.startsWith(u8, line, "#")) {
            continue;
        }

        if (std.mem.startsWith(u8, line, "@font")) {
            parseFontGlobals(line, slideshow, allocator) catch continue;
            continue;
        }

        if (std.mem.startsWith(u8, line, "@underline_width=")) {
            parseUnderlineWidth(line, slideshow, allocator) catch continue;
            continue;
        }

        if (std.mem.startsWith(u8, line, "@color=")) {
            parseDefaultColor(line, slideshow, allocator) catch continue;
            continue;
        }

        if (std.mem.startsWith(u8, line, "@slide")) {
            parseSlideDirective(line, &context) catch continue;
            continue;
        }
    }
    // TODO: commit last slide
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
                ret = try parseColorLiteral(colorstr);
            }
        }
    }
    return ret;
}
fn parseColorLiteral(colorstr: []const u8) !ImVec4 {
    var ret = ImVec4{};
    if (colorstr.len != 9 or colorstr[0] != '#') {
        std.log.debug("color string '{s}' not 9 chars long or missing #", .{colorstr});
        return ParserError.Internal;
    }
    var temp: ImVec4 = undefined;
    var coloru32 = try std.fmt.parseInt(c_uint, colorstr[1..], 16);
    igColorConvertU32ToFloat4(&temp, coloru32);
    ret.x = temp.w;
    ret.y = temp.z;
    ret.z = temp.y;
    ret.w = temp.x;
    return ret;
}

fn parseSlideDirective(line: []const u8, context: *ParserContext) !void {
    std.log.debug("Parsing @slide line", .{});
    // if this is not the first slide, then commit it
    if (!context.first_slide) {
        std.log.debug("committing slide", .{});
        try context.commitSlide(context.current_slide);
    } else {
        // don't leak
        context.current_slide.deinit();
    }
    context.first_slide = false;
    context.current_slide = try Slide.new(context.allocator);
    context.current_context = ItemContext{};

    // now parse the rest
    // first, we expect the line to start with a @page keyword
    var word_it = std.mem.tokenize(line, " \t");
    if (word_it.next()) |expect_slide| {
        if (!std.mem.eql(u8, expect_slide, "@slide")) {
            return ParserError.Internal;
        }
    } else {
        return ParserError.Internal;
    }

    // now we parse the optional slide attributes
    while (word_it.next()) |word| {
        var attr_it = std.mem.tokenize(word, "=");
        if (attr_it.next()) |attrname| {
            if (std.mem.eql(u8, attrname, "fontsize")) {
                if (attr_it.next()) |sizestr| {
                    var size = std.fmt.parseInt(i32, sizestr, 10) catch continue;
                    context.current_slide.fontsize = size;
                    context.current_context.fontSize = size;
                    std.log.debug("current slide fontsize: {}", .{context.current_slide.fontsize});
                }
            }
            if (std.mem.eql(u8, attrname, "color")) {
                if (attr_it.next()) |colorstr| {
                    var color = parseColorLiteral(colorstr) catch continue;
                    context.current_slide.text_color = color;
                    context.current_context.color = color;
                    std.log.debug("current slide color: {any}", .{context.current_slide.text_color});
                }
            }
            if (std.mem.eql(u8, attrname, "bullet_color")) {
                if (attr_it.next()) |colorstr| {
                    var color = parseColorLiteral(colorstr) catch continue;
                    context.current_slide.text_color = color;
                    context.current_context.color = color;
                    std.log.debug("current slide bullet_color: {any}", .{context.current_slide.bullet_color});
                }
            }
        }
    }
}
