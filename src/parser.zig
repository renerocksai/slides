const std = @import("std");
const slideszig = @import("slides.zig");
// for ImVec4 and stuff
const upaya = @import("upaya");

usingnamespace upaya.imgui;
usingnamespace slideszig;

pub const ParserError = error{Internal};

// TODO:
// - @push
// - @pushslide
// - @pop
// - @popslide
// - @box
// - @bg
//
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

    var parsing_item_context = ItemContext{};

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

        if (std.mem.startsWith(u8, line, "@bullet_color=")) {
            parseDefaultBulletColor(line, slideshow, allocator) catch continue;
            continue;
        }

        if (std.mem.startsWith(u8, line, "@")) {
            // commit current parsing_item_context
            commitParsingContext(&parsing_item_context, &context) catch |err| {};

            // then parse current item context
            parsing_item_context = parseItemAttributes(line, &context) catch continue;
        } else {
            // add text lines to current parsing context
            var text: []const u8 = undefined;
            var the_line = line;
            // make _ line an empty line
            if (line.len == 1 and line[0] == '_') {
                the_line = " ";
            }
            if (parsing_item_context.text) |txt| {
                text = std.fmt.allocPrint(context.allocator, "{s}\n{s}", .{ txt, the_line }) catch continue;
            } else {
                text = the_line;
            }
            parsing_item_context.text = text;
        }
    }
    // commit last slide
    commitParsingContext(&parsing_item_context, &context) catch |err| {};
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

fn parseDefaultBulletColor(line: []const u8, slideshow: *SlideShow, allocator: *std.mem.Allocator) !void {
    var it = std.mem.tokenize(line, "=");
    if (it.next()) |word| {
        if (std.mem.eql(u8, word, "@bullet_color")) {
            slideshow.default_bullet_color = try parseColor(line[8..], allocator);
            std.log.debug("global default_bullet_color: {any}", .{slideshow.default_bullet_color});
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

fn parseItemAttributes(line: []const u8, context: *ParserContext) !ItemContext {
    var item_context = ItemContext{};
    var word_it = std.mem.tokenize(line, " \t");
    if (word_it.next()) |directive| {
        item_context.directive = directive;
    } else {
        return ParserError.Internal;
    }

    // check if directive needs to be followed by a name
    if (std.mem.eql(u8, item_context.directive, "@push") or std.mem.eql(u8, item_context.directive, "@pop") or std.mem.eql(u8, item_context.directive, "@pushslide") or std.mem.eql(u8, item_context.directive, "@popslide")) {
        if (word_it.next()) |name| {
            item_context.context_name = name;
        } else {
            return ParserError.Internal;
        }
    }

    std.log.debug("Parsing {s}", .{item_context.directive});

    var text_words = std.ArrayList([]const u8).init(context.allocator);
    defer text_words.deinit();
    var after_text_directive = false;

    while (word_it.next()) |word| {
        if (!after_text_directive) {
            var attr_it = std.mem.tokenize(word, "=");
            if (attr_it.next()) |attrname| {
                if (std.mem.eql(u8, attrname, "x")) {
                    if (attr_it.next()) |sizestr| {
                        var size = std.fmt.parseInt(i32, sizestr, 10) catch continue;
                        var pos: ImVec2 = .{};
                        if (item_context.position) |position| {
                            pos = position;
                        }
                        pos.x = @intToFloat(f32, size);
                        item_context.position = pos;
                    }
                }
                if (std.mem.eql(u8, attrname, "y")) {
                    if (attr_it.next()) |sizestr| {
                        var size = std.fmt.parseInt(i32, sizestr, 10) catch continue;
                        var pos: ImVec2 = .{};
                        if (item_context.position) |position| {
                            pos = position;
                        }
                        pos.y = @intToFloat(f32, size);
                        item_context.position = pos;
                    }
                }
                if (std.mem.eql(u8, attrname, "w")) {
                    if (attr_it.next()) |sizestr| {
                        var width = std.fmt.parseInt(i32, sizestr, 10) catch continue;
                        var size: ImVec2 = .{};
                        if (item_context.size) |csize| {
                            size = csize;
                        }
                        size.x = @intToFloat(f32, width);
                        item_context.size = size;
                    }
                }
                if (std.mem.eql(u8, attrname, "h")) {
                    if (attr_it.next()) |sizestr| {
                        var height = std.fmt.parseInt(i32, sizestr, 10) catch continue;
                        var size: ImVec2 = .{};
                        if (item_context.size) |csize| {
                            size = csize;
                        }
                        size.y = @intToFloat(f32, height);
                        item_context.size = size;
                    }
                }
                if (std.mem.eql(u8, attrname, "fontsize")) {
                    if (attr_it.next()) |sizestr| {
                        var size = std.fmt.parseInt(i32, sizestr, 10) catch continue;
                        item_context.fontSize = size;
                    }
                }
                if (std.mem.eql(u8, attrname, "color")) {
                    if (attr_it.next()) |colorstr| {
                        var color = parseColorLiteral(colorstr) catch continue;
                        item_context.color = color;
                    }
                }
                if (std.mem.eql(u8, attrname, "bullet_color")) {
                    if (attr_it.next()) |colorstr| {
                        var color = parseColorLiteral(colorstr) catch continue;
                        item_context.bullet_color = color;
                    }
                }
                if (std.mem.eql(u8, attrname, "underline_width")) {
                    if (attr_it.next()) |sizestr| {
                        var width = std.fmt.parseInt(i32, sizestr, 10) catch continue;
                        item_context.underline_width = width;
                    }
                }
                if (std.mem.eql(u8, attrname, "text")) {
                    after_text_directive = true;
                    if (attr_it.next()) |textafterequal| {
                        try text_words.append(textafterequal);
                    }
                }
            }
        } else {
            try text_words.append(word);
        }
    }
    if (text_words.items.len > 0) {
        item_context.text = try std.mem.join(context.allocator, " ", text_words.items);
    }
    return item_context;
}

fn commitParsingContext(itemctx: *ItemContext, context: *ParserContext) !void {
    // .
    std.log.debug("{s} : {s}", .{ itemctx.directive, itemctx.text });
    itemctx.* = ItemContext{};
}
