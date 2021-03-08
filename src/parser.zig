const std = @import("std");
const slideszig = @import("slides.zig");
// for ImVec4 and stuff
const upaya = @import("upaya");

// NOTE:
// why we have context.current_context:
// @pop some_shit
// # now current_context is loaded with the pushed values, like the color etc
//
// @box x= y=
// # parsing context is loaded with x and y
// text text
// # text is added to the parsing context
//
// @pop other_shit
// # at this moment, the parsing context is complete, it can be commited
// # hence, the above @box with all text will be committed
// # before that: the parsing context is merged with the current context, so the text color is set etc
//
// # then other_shit is popped and put into the current_context
// # while parsing the other_shit line, parsing_context will be used
//
// @box
// more text
usingnamespace upaya.imgui;
usingnamespace slideszig;

pub const ParserError = error{ Internal, Syntax };

pub const ParserErrorContext = struct {
    parser_error: anyerror,
    line_number: usize = 0,
    line_offset: usize = 0,
    message: ?[]const u8,
};

const ParserContext = struct {
    allocator: *std.mem.Allocator,

    parsed_line_number: usize = 0,
    parsed_line_offset: usize = 0,

    parser_errors: std.ArrayList(ParserErrorContext) = undefined,

    first_slide_emitted: bool = false,

    slideshow: *SlideShow,
    push_contexts: std.StringHashMap(ItemContext),
    push_slides: std.StringHashMap(*Slide),

    current_context: ItemContext = ItemContext{},
    current_slide: *Slide,

    fn deinit(self: *ParserContext) void {
        self.parser_errors.deinit();
        self.push_contexts.deinit();
        self.push_slides.deinit();
    }

    fn logAllErrors(self: *ParserContext) void {
        for (self.parser_errors.items) |err| {
            if (err.message) |msg| {
                std.log.err("line {d}: {s} ({s})", .{ err.line_number, err.parser_error, msg });
            } else {
                std.log.err("line {d}: {s}", .{ err.line_number, err.parser_error });
            }
        }
    }
};

fn reportErrorInContext(err: anyerror, ctx: *ParserContext, msg: ?[]const u8) void {
    const pec = ParserErrorContext{
        .parser_error = err,
        .line_number = ctx.parsed_line_number,
        .line_offset = ctx.parsed_line_offset,
        .message = msg,
    };
    ctx.parser_errors.append(pec) catch |internal_err| {
        std.log.crit("Could not add error to error list!", .{});
        std.log.crit("    The error to be reported: {any}", .{err});
        std.log.crit("    The error that prevented it: {any}", .{internal_err});
    };
}

pub fn constructSlidesFromBuf(input: []const u8, slideshow: *SlideShow, allocator: *std.mem.Allocator) !void {
    var start: usize = if (std.mem.startsWith(u8, input, "\xEF\xBB\xBF")) 3 else 0;
    // var it = std.mem.tokenize(input[start..], "\n\r");
    var it = std.mem.split(input[start..], "\n");

    var context = ParserContext{
        .allocator = allocator,
        .slideshow = slideshow,
        .push_contexts = std.StringHashMap(ItemContext).init(allocator),
        .push_slides = std.StringHashMap(*Slide).init(allocator),
        .current_slide = try Slide.new(allocator),
        .parser_errors = std.ArrayList(ParserErrorContext).init(allocator),
    };

    var parsing_item_context = ItemContext{};

    while (it.next()) |line_untrimmed| {
        {
            const line = std.mem.trimRight(u8, line_untrimmed, " \t");
            context.parsed_line_number += 1;
            defer context.parsed_line_offset += line_untrimmed.len + 1;

            if (line.len == 0) {
                continue;
            }

            if (input[context.parsed_line_offset] != line[0]) {
                std.log.alert("line {d} assumed to start at offset {} but saw {c}({}) instead of {c}({})", .{ context.parsed_line_number, context.parsed_line_offset, line[0], line[0], input[context.parsed_line_offset], input[context.parsed_line_offset] });
                return error.Overflow;
            }

            if (std.mem.startsWith(u8, line, "#")) {
                continue;
            }

            if (std.mem.startsWith(u8, line, "@font")) {
                parseFontGlobals(line, slideshow, &context) catch |err| {
                    reportErrorInContext(err, &context, null);
                    continue;
                };
                continue;
            }

            if (std.mem.startsWith(u8, line, "@underline_width=")) {
                parseUnderlineWidth(line, slideshow, &context) catch |err| {
                    reportErrorInContext(err, &context, null);
                    continue;
                };
                continue;
            }

            if (std.mem.startsWith(u8, line, "@color=")) {
                parseDefaultColor(line, slideshow, &context) catch |err| {
                    reportErrorInContext(err, &context, null);
                    continue;
                };
                continue;
            }

            if (std.mem.startsWith(u8, line, "@bullet_color=")) {
                parseDefaultBulletColor(line, slideshow, &context) catch |err| {
                    reportErrorInContext(err, &context, null);
                    continue;
                };
                continue;
            }

            if (std.mem.startsWith(u8, line, "@")) {
                // commit current parsing_item_context
                commitParsingContext(&parsing_item_context, &context) catch |err| {
                    reportErrorInContext(err, &context, null);
                };
                // then parse current item context
                parsing_item_context = parseItemAttributes(line, &context) catch |err| {
                    reportErrorInContext(err, &context, null);
                    continue;
                };
            } else {
                // add text lines to current parsing context
                var text: []const u8 = undefined;
                var the_line = line;
                // make _ line an empty line
                if (line.len == 1 and line[0] == '_') {
                    the_line = " ";
                }
                if (parsing_item_context.text) |txt| {
                    text = std.fmt.allocPrint(context.allocator, "{s}\n{s}", .{ txt, the_line }) catch |err| {
                        reportErrorInContext(err, &context, null);
                        continue;
                    };
                } else {
                    text = the_line;
                }
                parsing_item_context.text = text;
            }
        }
    }
    // commit last slide
    commitParsingContext(&parsing_item_context, &context) catch |err| {
        reportErrorInContext(err, &context, null);
    };
    context.slideshow.slides.append(context.current_slide) catch |err| {
        reportErrorInContext(err, &context, null);
    };

    if (context.parser_errors.items.len == 0) {
        std.log.info("OK. There were no errors.", .{});
    } else {
        std.log.info("There were no errors!", .{});
        context.logAllErrors();
    }
    return;
}

fn parseFontGlobals(line: []const u8, slideshow: *SlideShow, context: *ParserContext) !void {
    var it = std.mem.tokenize(line, "=");
    if (it.next()) |word| {
        if (std.mem.eql(u8, word, "@fontsize")) {
            if (it.next()) |sizestr| {
                slideshow.default_fontsize = std.fmt.parseInt(i32, sizestr, 10) catch |err| {
                    reportErrorInContext(err, context, "@fonsize value not int-parseable");
                    return;
                };
                std.log.debug("global fontsize: {d}", .{slideshow.default_fontsize});
            }
        }
        if (std.mem.eql(u8, word, "@font")) {
            if (it.next()) |font| {
                slideshow.default_font = try context.allocator.dupe(u8, font);
                std.log.debug("global font: {s}", .{slideshow.default_font});
            }
        }
        if (std.mem.eql(u8, word, "@font_bold")) {
            if (it.next()) |font_bold| {
                slideshow.default_font_bold = try context.allocator.dupe(u8, font_bold);
                std.log.debug("global font_bold: {s}", .{slideshow.default_font_bold});
            }
        }
        if (std.mem.eql(u8, word, "@font_italic")) {
            if (it.next()) |font_italic| {
                slideshow.default_font_italic = try context.allocator.dupe(u8, font_italic);
                std.log.debug("global font_italic: {s}", .{slideshow.default_font_italic});
            }
        }
        if (std.mem.eql(u8, word, "@font_bold_italic")) {
            if (it.next()) |font_bold_italic| {
                slideshow.default_font_bold_italic = try context.allocator.dupe(u8, font_bold_italic);
                std.log.debug("global font_bold_italic: {s}", .{slideshow.default_font_bold_italic});
            }
        }
    }
}

fn parseUnderlineWidth(line: []const u8, slideshow: *SlideShow, context: *ParserContext) !void {
    var it = std.mem.tokenize(line, "=");
    if (it.next()) |word| {
        if (std.mem.eql(u8, word, "@underline_width")) {
            if (it.next()) |sizestr| {
                slideshow.default_underline_width = std.fmt.parseInt(i32, sizestr, 10) catch |err| {
                    reportErrorInContext(err, context, "@underline_width value not int-parseable");
                    return;
                };

                std.log.debug("global underline_width: {d}", .{slideshow.default_underline_width});
            }
        }
    }
}

fn parseDefaultColor(line: []const u8, slideshow: *SlideShow, context: *ParserContext) !void {
    var it = std.mem.tokenize(line, "=");
    if (it.next()) |word| {
        if (std.mem.eql(u8, word, "@color")) {
            slideshow.default_color = try parseColor(line[1..], context);
            std.log.debug("global default_color: {any}", .{slideshow.default_color});
        }
    }
}

fn parseDefaultBulletColor(line: []const u8, slideshow: *SlideShow, context: *ParserContext) !void {
    var it = std.mem.tokenize(line, "=");
    if (it.next()) |word| {
        if (std.mem.eql(u8, word, "@bullet_color")) {
            slideshow.default_bullet_color = try parseColor(line[8..], context);
            std.log.debug("global default_bullet_color: {any}", .{slideshow.default_bullet_color});
        }
    }
}

fn parseColor(s: []const u8, context: *ParserContext) !ImVec4 {
    var it = std.mem.tokenize(s, "=");
    var ret = ImVec4{};
    if (it.next()) |word| {
        if (std.mem.eql(u8, word, "color")) {
            if (it.next()) |colorstr| {
                ret = try parseColorLiteral(colorstr, context);
            }
        }
    }
    return ret;
}
fn parseColorLiteral(colorstr: []const u8, context: *ParserContext) !ImVec4 {
    var ret = ImVec4{};
    if (colorstr.len != 9 or colorstr[0] != '#') {
        const errmsg = try std.fmt.allocPrint(context.allocator, "color string '{s}' not 9 chars long or missing #", .{colorstr});
        reportErrorInContext(ParserError.Syntax, context, errmsg);
        return ParserError.Syntax;
    }
    var temp: ImVec4 = undefined;
    var coloru32 = std.fmt.parseInt(c_uint, colorstr[1..], 16) catch |err| {
        const errmsg = try std.fmt.allocPrint(context.allocator, "color string '{s}' not hex-parsable", .{colorstr});
        reportErrorInContext(err, context, errmsg);
        return ParserError.Syntax;
    };
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
            std.log.info("context name : {s}", .{item_context.context_name.?});
        } else {
            reportErrorInContext(ParserError.Syntax, context, "context name missing!");
            return ParserError.Syntax;
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
                        var size = std.fmt.parseInt(i32, sizestr, 10) catch |err| {
                            reportErrorInContext(err, context, "cannot parse x=");
                            continue;
                        };
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
                        var size = std.fmt.parseInt(i32, sizestr, 10) catch |err| {
                            reportErrorInContext(err, context, "cannot parse y=");
                            continue;
                        };
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
                        var width = std.fmt.parseInt(i32, sizestr, 10) catch |err| {
                            reportErrorInContext(err, context, "cannot parse w=");
                            continue;
                        };
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
                        var height = std.fmt.parseInt(i32, sizestr, 10) catch |err| {
                            reportErrorInContext(err, context, "cannot parse h=");
                            continue;
                        };
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
                        var size = std.fmt.parseInt(i32, sizestr, 10) catch |err| {
                            reportErrorInContext(err, context, "cannot parse fontsize=");
                            continue;
                        };
                        item_context.fontSize = size;
                    }
                }
                if (std.mem.eql(u8, attrname, "color")) {
                    if (attr_it.next()) |colorstr| {
                        var color = parseColorLiteral(colorstr, context) catch |err| {
                            reportErrorInContext(err, context, "cannot parse color=");
                            continue;
                        };
                        item_context.color = color;
                    }
                }
                if (std.mem.eql(u8, attrname, "bullet_color")) {
                    if (attr_it.next()) |colorstr| {
                        var color = parseColorLiteral(colorstr, context) catch |err| {
                            reportErrorInContext(err, context, "cannot parse bullet_color=");
                            continue;
                        };
                        item_context.bullet_color = color;
                    }
                }
                if (std.mem.eql(u8, attrname, "underline_width")) {
                    if (attr_it.next()) |sizestr| {
                        var width = std.fmt.parseInt(i32, sizestr, 10) catch |err| {
                            reportErrorInContext(err, context, "cannot parse bullet_color=");
                            continue;
                        };
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

// TODO:
// - @push       -- merge: parser context, current item context --> pushed item
// - @pushslide  -- pushed slide just from parser context, clear current item context just as with @page
// - @pop        -- merge: current item context with parser context --> current item context
//                       e.g. "@pop some_shit x=1" -- pop and override
// - @popslide   -- just pop the slide, clear current item context
// - @slide      -- just create and emit slide with parser context (and not item context!), clear current item context
//                       we don't want to merge current item context with @slide: we would inherit the shit from any
//                       previous item!
// - @box        -- merge: parser context, current item context -> emitted box
//                         also, see override rules below for instantiating a box.
// - @bg         -- merge: parser context, current item context -> emitted bg item
//
//
// Instantiating a box:
// override all unset settings by:
// - item context values : use SlideItem.applyContext(ItemContext)
// - slide defaults
// - slideshow defaults
//

fn mergeParserAndItemContext(parsing_item_context: *ItemContext, item_context: *ItemContext) void {
    if (parsing_item_context.text == null) parsing_item_context.text = item_context.text;
    if (parsing_item_context.fontSize == null) parsing_item_context.fontSize = item_context.fontSize;
    if (parsing_item_context.color == null) parsing_item_context.color = item_context.color;
    if (parsing_item_context.position == null) parsing_item_context.position = item_context.position;
    if (parsing_item_context.size == null) parsing_item_context.size = item_context.size;
    if (parsing_item_context.underline_width == null) parsing_item_context.underline_width = item_context.underline_width;
    if (parsing_item_context.bullet_color == null) parsing_item_context.bullet_color = item_context.bullet_color;
}

fn commitParsingContext(parsing_item_context: *ItemContext, context: *ParserContext) !void {
    // .
    std.log.debug("{s} : text={s}", .{ parsing_item_context.directive, parsing_item_context.text });

    // switch over directives
    if (std.mem.eql(u8, parsing_item_context.directive, "@push")) {
        mergeParserAndItemContext(parsing_item_context, &context.current_context);
        if (parsing_item_context.context_name) |context_name| {
            try context.push_contexts.put(context_name, parsing_item_context.*);
        }
        // just to make sure this context remains active
        context.current_context = parsing_item_context.*;
        return;
    }

    if (std.mem.eql(u8, parsing_item_context.directive, "@pushslide")) {
        context.current_slide.applyContext(parsing_item_context);
        if (parsing_item_context.context_name) |context_name| {
            try context.push_slides.put(context_name, context.current_slide);
        }
        context.current_slide = try Slide.new(context.allocator);
    }

    if (std.mem.eql(u8, parsing_item_context.directive, "@pop")) {
        // pop the context if present
        // also set the parsing context to the current context
        if (parsing_item_context.context_name) |context_name| {
            const ctx_opt = context.push_contexts.get(context_name);
            if (ctx_opt) |ctx| {
                context.current_context = ctx;
                parsing_item_context.* = ctx;
            }
            _ = try commitItemToSlide(parsing_item_context, context);
        }
        return;
    }

    if (std.mem.eql(u8, parsing_item_context.directive, "@popslide")) {
        // emit the current slide (if present) into the slideshow
        // then create a new slide (NOT deiniting the current one) with the **parsing** context's overrides
        // and make it the current slide
        // after that, clear the current item context
        if (context.first_slide_emitted) {
            context.current_slide.applyContext(parsing_item_context); //  ignore current item context, it's a @slide
            try context.slideshow.slides.append(context.current_slide);
        }
        context.first_slide_emitted = true;
        // pop the slide and reset the item context
        // (the latter is done by continue)
        if (parsing_item_context.context_name) |context_name| {
            const sld_opt = context.push_slides.get(context_name);
            if (sld_opt) |sld| {
                context.current_slide = sld;
            }
            // new slide, clear the current item context
            context.current_context = .{};
        }
        return;
    }

    if (std.mem.eql(u8, parsing_item_context.directive, "@slide")) {
        // emit the current slide (if present) into the slideshow
        // then create a new slide (NOT deiniting the current one) with the **parsing** context's overrides
        // and make it the current slide
        // after that, clear the current item context
        if (context.first_slide_emitted) {
            context.current_slide.applyContext(parsing_item_context); //  ignore current item context, it's a @slide
            try context.slideshow.slides.append(context.current_slide);
        }
        context.first_slide_emitted = true;

        context.current_slide = try Slide.new(context.allocator);
        context.current_slide.pos_in_editor = context.parsed_line_offset;
        context.current_slide.line_in_editor = context.parsed_line_number;
        context.current_context = .{}; // clear the current item context, to start fresh in each new slide
        return;
    }

    if (std.mem.eql(u8, parsing_item_context.directive, "@box")) {
        // set kind to img if img attribute is present else set it to textbox
        // but first, merge shit
        // - @box        -- merge: parser context, current item context -> emitted box
        //                         also, see override rules below for instantiating a box.
        //
        // Instantiating a box:
        // override all unset settings by:
        // - item context values : use SlideItem.applyContext(ItemContext)
        // - slide defaults
        // - slideshow defaults
        const slide_item = try commitItemToSlide(parsing_item_context, context);
        var text = slide_item.text orelse "";
        std.log.info("added a slide item: {any} - {s}", .{ slide_item.*, text });

        return;
    }

    // @bg is just for convenience. x=0, y=0, w=render_width, h=render_hight
    if (std.mem.eql(u8, parsing_item_context.directive, "@bg")) {
        // well, we can see if fun features emerge when we do all the merges
        _ = try commitItemToSlide(parsing_item_context, context);
        return;
    }
}

fn commitItemToSlide(parsing_item_context: *ItemContext, parser_context: *ParserContext) !*SlideItem {
    mergeParserAndItemContext(parsing_item_context, &parser_context.current_context);
    var slide_item = try SlideItem.new(parser_context.allocator);
    try slide_item.applyContext(parser_context.allocator, parsing_item_context.*);
    slide_item.applySlideDefaultsIfNecessary(parser_context.current_slide);
    slide_item.applySlideShowDefaultsIfNecessary(parser_context.slideshow);
    if (slide_item.img_path) |img_path| {
        slide_item.kind = .img;
    } else {
        slide_item.kind = .textbox;
    }
    std.log.info("\n\n\n ADDING {s} as {any}", .{ parsing_item_context.directive, slide_item.kind });
    try parser_context.current_slide.items.append(slide_item.*);
    return slide_item; // just FYI
}
