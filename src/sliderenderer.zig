const std = @import("std");
const tcache = @import("texturecache.zig");
const slides = @import("slides.zig");
const imgui = @import("imgui");
const my_fonts = @import("fontbakery.zig");
const markdownlineparser = @import("markdownlineparser.zig");
const zt = @import("zt");

usingnamespace slides;
usingnamespace markdownlineparser;

const RenderDistortion = struct { dx: f32 = 0.0, dy: f32 = 0.0 };

const RenderDistortionAnimation = struct { framecount: f32 = 0, scale: f32 = 10.0, running: bool = false };

pub var renderDistortion = RenderDistortion{};
pub var renderDistortionAnimation = RenderDistortionAnimation{};

pub fn updateRenderDistortion() void {
    renderDistortionAnimation.framecount += 1;
    renderDistortion.dx = std.math.cos(renderDistortionAnimation.framecount) * renderDistortionAnimation.scale;
    renderDistortion.dy = std.math.sin(renderDistortionAnimation.framecount) * renderDistortionAnimation.scale;
}

const RenderElementKind = enum {
    background,
    text,
    image,
};

const RenderElement = struct {
    kind: RenderElementKind = .background,
    position: imgui.ImVec2 = imgui.ImVec2{},
    size: imgui.ImVec2 = imgui.ImVec2{},
    color: ?imgui.ImVec4 = imgui.ImVec4{},
    text: ?[*:0]const u8 = null,
    fontSize: ?i32 = null,
    fontStyle: my_fonts.FontStyle = .normal,
    underlined: bool = false,
    underline_width: ?i32 = null,
    bullet_color: ?imgui.ImVec4 = null,
    texture: ?zt.gl.Texture = null,
    bullet_symbol: [*:0]const u8 = "",
};

const RenderedSlide = struct {
    elements: std.ArrayList(RenderElement) = undefined,

    fn new(allocator: std.mem.Allocator) !*RenderedSlide {
        var self: *RenderedSlide = try allocator.create(RenderedSlide);
        self.* = .{};
        self.elements = std.ArrayList(RenderElement).init(allocator);
        return self;
    }
};

pub const SlideshowRenderer = struct {
    renderedSlides: std.ArrayList(*RenderedSlide) = undefined,
    allocator: std.mem.Allocator = undefined,
    md_parser: markdownlineparser.MdLineParser = .{},

    pub fn new(allocator: std.mem.Allocator) !*SlideshowRenderer {
        var self: *SlideshowRenderer = try allocator.create(SlideshowRenderer);
        self.* = .{};
        self.*.allocator = allocator;
        self.renderedSlides = std.ArrayList(*RenderedSlide).init(allocator);
        self.md_parser.init(self.allocator);
        return self;
    }

    pub fn preRender(self: *SlideshowRenderer, slideshow: *const slides.SlideShow, slideshow_filp: []const u8) !void {
        std.log.debug("ENTER preRender", .{});
        if (slideshow.slides.items.len == 0) {
            return;
        }

        self.renderedSlides.shrinkRetainingCapacity(0);

        for (slideshow.slides.items) |slide, i| {
            const slide_number = i + 1;

            if (slide.items.?.items.len == 0) {
                continue;
            }

            // add a renderedSlide
            var renderSlide = try RenderedSlide.new(self.allocator);

            for (slide.items.?.items) |item| {
                switch (item.kind) {
                    .background => try self.createBg(renderSlide, item, slideshow_filp),
                    .textbox => try self.preRenderTextBlock(renderSlide, item, slide_number),
                    .img => try self.createImg(renderSlide, item, slideshow_filp),
                }
            }

            // now add the slide
            try self.renderedSlides.append(renderSlide);
        }
        std.log.debug("LEAVE preRender", .{});
    }

    fn createBg(self: *SlideshowRenderer, renderSlide: *RenderedSlide, item: slides.SlideItem, slideshow_filp: []const u8) !void {
        _ = self;
        std.log.info("pre-rendering bg {}", .{item});
        if (item.img_path) |p| {
            var texptr = try tcache.getImg(p, slideshow_filp);
            if (texptr) |t| {
                try renderSlide.elements.append(RenderElement{ .kind = .background, .texture = t });
            }
        } else {
            if (item.color) |color| {
                std.log.info("bg has color {}", .{color});
                try renderSlide.elements.append(RenderElement{ .kind = .background, .color = color });
            } else {
                std.log.info("bg has NO COLOR", .{});
            }
        }
    }

    fn preRenderTextBlock(self: *SlideshowRenderer, renderSlide: *RenderedSlide, item: slides.SlideItem, slide_number: usize) !void {
        // for line in lines:
        //     if line is bulleted: emit bullet, adjust x pos
        //     render spans
        std.log.debug("ENTER preRenderTextBlock for slide {d} : {s}", .{ slide_number, item });
        const spaces_per_indent: usize = 4;
        var fontSize: i32 = 0;
        var line_height_bullet_width: imgui.ImVec2 = .{};

        // box without text, but with color: render a colored box!
        if (item.text == null and item.color != null) {
            std.log.debug("preRenderTextBlock (color) creating RenderElement", .{});
            try renderSlide.elements.append(RenderElement{
                .kind = .text,
                .position = item.position,
                .size = item.size,
                .fontSize = null,
                .underline_width = null,
                .text = null,
                .color = item.color,
            });
            std.log.debug("LEAVE preRenderTextBlock (color) for slide {d}", .{slide_number});
            return;
        }

        if (item.fontSize) |fs| {
            // TODO: this might be inaccurate if we use different fonts in the text block
            // whose pixel sizes vary significantly for given font sizes
            line_height_bullet_width = self.lineHightAndBulletWidthForFontSize(fs);
            fontSize = fs;
        } else {
            // no fontsize  - error!
            std.log.err("No fontsize for text {s}", .{item.text});
            return;
        }
        var bulletColor: imgui.ImVec4 = .{};
        if (item.bullet_color) |bc| {
            bulletColor = bc;
        } else {
            // no bullet color - error!
            std.log.err("No bullet color for text {s}", .{item.text});
            return;
        }

        // actually, checking for a bullet symbol only makes sense if anywhere in the text a bulleted item exists
        // but we'll leave it like this for now
        // not sure I want to allocate here, though
        var bulletSymbol: [*:0]const u8 = undefined;
        if (item.bullet_symbol) |bs| {
            bulletSymbol = try std.fmt.allocPrintZ(self.allocator, "{s}", .{bs});
        } else {
            // no bullet symbol - error
            std.log.err("No bullet symbol for text {s}", .{item.text});
            return;
        }

        const color = item.color orelse return;
        const underline_width = item.underline_width orelse 0;

        if (item.text) |t| {
            const tl_pos = imgui.ImVec2{ .x = item.position.x, .y = item.position.y };
            var layoutContext = TextLayoutContext{
                .available_size = .{ .x = item.size.x, .y = item.size.y },
                .origin_pos = tl_pos,
                .current_pos = tl_pos,
                .fontSize = fontSize,
                .underline_width = @intCast(usize, underline_width),
                .color = color,
                .text = "", // will be overridden immediately
                .current_line_height = line_height_bullet_width.y, // will be overridden immediately but needed if text starts with empty line(s)
            };

            // slide number
            var slideNumStr: [10]u8 = undefined;
            _ = try std.fmt.bufPrintZ(&slideNumStr, "{d}", .{slide_number});
            const new_t = try std.mem.replaceOwned(u8, self.allocator, t, "$slide_number", &slideNumStr);

            // split into lines
            var it = std.mem.split(u8, new_t, "\n");
            while (it.next()) |line| {
                if (line.len == 0) {
                    // empty line
                    layoutContext.current_pos.y += layoutContext.current_line_height;
                    continue;
                }
                // find out, if line is a list item:
                //    - starts with `-` or `>`
                var bullet_indent_in_spaces: usize = 0;
                const is_bulleted = self.countIndentOfBullet(line, &bullet_indent_in_spaces);
                const indent_level = bullet_indent_in_spaces / spaces_per_indent;
                const indent_in_pixels = line_height_bullet_width.x * @intToFloat(f32, indent_level);
                var available_width = item.size.x - indent_in_pixels;
                layoutContext.available_size.x = available_width;
                layoutContext.origin_pos.x = tl_pos.x + indent_in_pixels;
                layoutContext.current_pos.x = tl_pos.x + indent_in_pixels;
                layoutContext.fontSize = fontSize;
                layoutContext.underline_width = @intCast(usize, underline_width);
                layoutContext.color = color;
                layoutContext.text = line;

                if (is_bulleted) {
                    // 1. add indented bullet symbol at the current pos
                    try renderSlide.elements.append(RenderElement{
                        .kind = .text,
                        .position = .{ .x = tl_pos.x + indent_in_pixels, .y = layoutContext.current_pos.y },
                        .size = .{ .x = available_width, .y = layoutContext.available_size.y },
                        .fontSize = fontSize,
                        .underline_width = underline_width,
                        .text = bulletSymbol,
                        .color = bulletColor,
                    });
                    // 2. increase indent by 1 and add indented text block
                    available_width -= line_height_bullet_width.x;
                    layoutContext.origin_pos.x += line_height_bullet_width.x;
                    layoutContext.current_pos.x = layoutContext.origin_pos.x;
                    layoutContext.available_size.x = available_width;
                    layoutContext.text = std.mem.trimLeft(u8, line, " \t->");
                }

                try self.renderMdBlock(renderSlide, &layoutContext);

                // advance to the next line
                layoutContext.current_pos.x = tl_pos.x;
                layoutContext.current_pos.y += layoutContext.current_line_height;

                // don't render (much) beyond size
                //
                // with this check, we will not render anything that would start outside the size rect.
                // Also, lines using the regular font will not exceed the size rect.
                // however,
                // - if a line uses a bigger font (more pixels) than the regular font, we might still exceed the size rect by the delta
                // - we might still draw underlines beyond the size.y if the last line fits perfectly.
                if (layoutContext.current_pos.y >= tl_pos.y + item.size.y - line_height_bullet_width.y) {
                    break;
                }
            }
        }
        std.log.debug("LEAVE preRenderTextBlock for slide {d}", .{slide_number});
    }

    const TextLayoutContext = struct {
        origin_pos: imgui.ImVec2 = .{},
        current_pos: imgui.ImVec2 = .{},
        available_size: imgui.ImVec2 = .{},
        current_line_height: f32 = 0,
        fontSize: i32 = 0,
        underline_width: usize = 0,
        color: imgui.ImVec4 = .{},
        text: []const u8 = undefined,
    };

    fn renderMdBlock(self: *SlideshowRenderer, renderSlide: *RenderedSlide, layoutContext: *TextLayoutContext) !void {
        //     remember original pos. its X will need to be reset at every line wrap
        //     for span in spans:
        //         calc size.x of span
        //         if width > available_width:
        //             reduce width by chopping of words to the right until it fits
        //             repeat that for the remainding shit
        //             for split in splits:
        //                # treat them as lines.
        //             if lastsplit did not end with newline
        //                 we continue the next span right after the last split
        //
        //  the visible line hight is determined by the highest text span in the visible line!
        std.log.debug("ENTER renderMdBlock ", .{});
        self.md_parser.init(self.allocator);
        try self.md_parser.parseLine(layoutContext.text);
        if (self.md_parser.result_spans) |spans| {
            if (spans.items.len == 0) {
                std.log.debug("LEAVE1 preRenderTextBlock ", .{});
                return;
            }
            std.log.debug("SPANS:", .{});
            self.md_parser.logSpans();
            std.log.debug("ENDSPANS", .{});

            const default_color = layoutContext.color;

            var element = RenderElement{
                .kind = .text,
                .size = layoutContext.available_size,
                .color = default_color,
                .fontSize = layoutContext.fontSize,
                .underline_width = @intCast(i32, layoutContext.underline_width),
            };

            // when we check if a piece of text fits into the available width, we calculate its size, giving it an infinite width
            // so we can check the returned width against the available_width. Theoretically, Infinity_Width could be maxed out at
            // current_surface_size.x - since widths beyond that one would make no sense
            const Infinity_Width: f32 = 1000000;

            for (spans.items) |span| {
                if (span.text.?[0] == 0) {
                    std.log.debug("SKIPPING ZERO LENGTH SPAN", .{});
                    continue;
                }
                std.log.debug("new span, len=: `{d}`", .{span.text.?.len});
                // work out the font
                element.fontStyle = .normal;
                element.underlined = span.styleflags & markdownlineparser.StyleFlags.underline > 0;

                if (span.styleflags & markdownlineparser.StyleFlags.bold > 0) {
                    element.fontStyle = .bold;
                }
                if (span.styleflags & markdownlineparser.StyleFlags.italic > 0) {
                    element.fontStyle = .italic;
                }
                if (span.styleflags & markdownlineparser.StyleFlags.zig > 0) {
                    element.fontStyle = .zig;
                }
                if (span.styleflags & (markdownlineparser.StyleFlags.bold | markdownlineparser.StyleFlags.italic) == (markdownlineparser.StyleFlags.bold | markdownlineparser.StyleFlags.italic)) {
                    element.fontStyle = .bolditalic;
                }

                // work out the color
                element.color = default_color;
                if (span.styleflags & markdownlineparser.StyleFlags.colored > 0) {
                    if (span.color_override) |co| {
                        element.color = co;
                    } else {
                        std.log.debug("  ************************* NO COLOR OVERRIDE (styleflags: {x:02})", .{span.styleflags});
                        element.color = default_color;
                    }
                }

                // check the line hight of this span's fontstyle so we can check whether it wrapped
                const ig_span_fontsize_text: [*c]const u8 = "XXX";
                var ig_span_fontsize: imgui.ImVec2 = .{};
                my_fonts.pushStyledFontScaled(layoutContext.fontSize, element.fontStyle);
                imgui.igCalcTextSize(&ig_span_fontsize, ig_span_fontsize_text, ig_span_fontsize_text + 2, false, 2000);
                my_fonts.popFontScaled();

                // check if whole span fits width. - let's be opportunistic!
                // if not, start chopping off from the right until it fits
                // keep rest for later
                // Q: is it better to try to pop words from the left until
                //    the text doesn't fit anymore?
                // A: probably yes. Lines can be pretty long and hence wrap
                //    multiple times. Trying to find the max amount of words
                //    that fit until the first break is necessary is faster
                //    in that case.
                //    Also, doing it this way makes it pretty straight-forward
                //    to wrap superlong words that wouldn't even fit the
                //    current line width - and can be broken down easily.
                //    --
                //    One more thing: as we're looping through the spans,
                //        we don't render from the start of the line but
                //        from the end of the last span.

                // check if whole line fits
                // orelse start wrapping (see above)
                //
                //

                var attempted_span_size: imgui.ImVec2 = .{};
                var available_width: f32 = layoutContext.origin_pos.x + layoutContext.available_size.x - layoutContext.current_pos.x;
                var render_text_c = try self.styledTextblockSize_toCstring(span.text.?, layoutContext.fontSize, element.fontStyle, Infinity_Width, &attempted_span_size);
                std.log.debug("available_width: {d}, attempted_span_size: {d:3.0}", .{ available_width, attempted_span_size.x });
                if (attempted_span_size.x < available_width) {
                    // we did not wrap so the entire span can be output!
                    element.text = render_text_c;
                    element.position = layoutContext.current_pos;
                    element.size.x = attempted_span_size.x;
                    //element.size = attempted_span_size;
                    std.log.debug(">>>>>>> appending non-wrapping text element: {s}@{d:3.0},{d:3.0}", .{ element.text, element.position.x, element.position.y });
                    try renderSlide.elements.append(element);
                    // advance render pos
                    layoutContext.current_pos.x += attempted_span_size.x;
                    // if something is rendered into the currend line, then adjust the line height if necessary
                    if (attempted_span_size.y > layoutContext.current_line_height) {
                        layoutContext.current_line_height = attempted_span_size.y;
                    }
                } else {
                    // we need to check with how many words  we can get away with:
                    std.log.debug("  -> we need to check where to wrap!", .{});

                    // first, let's pseudo-split into words:
                    //   (what's so pseudo about that? we don't actually split, we just remember separator positions)
                    // we find the first index of word-separator, then the 2nd, ...
                    // and use it to determine the length of the slice
                    var lastIdxOfSpace: usize = 0;
                    var lastConsumedIdx: usize = 0;
                    var currentIdxOfSpace: usize = 0;
                    var wordCount: usize = 0;
                    // TODO: FIXME: we don't like tabs
                    while (true) {
                        std.log.debug("lastConsumedIdx: {}, lastIdxOfSpace: {}, currentIdxOfSpace: {}", .{ lastConsumedIdx, lastIdxOfSpace, currentIdxOfSpace });
                        if (std.mem.indexOfPos(u8, span.text.?, currentIdxOfSpace, " ")) |idx| {
                            currentIdxOfSpace = idx;
                            // look-ahead only allowed if there is more text
                            if (span.text.?.len > currentIdxOfSpace + 1) {
                                if (span.text.?[currentIdxOfSpace + 1] == ' ') {
                                    currentIdxOfSpace += 1; // jump over consecutive spaces
                                    continue;
                                }
                            }
                            if (currentIdxOfSpace == 0) {
                                // special case: we start with a space
                                // we start searching for the next space 1 after the last found one
                                if (currentIdxOfSpace + 1 < span.text.?.len) {
                                    currentIdxOfSpace += 1;
                                    continue;
                                } else {
                                    // in this case we better break or else we will loop forever
                                    break;
                                }
                            }
                            wordCount += 1;
                        } else {
                            std.log.debug("no more space found", .{});
                            if (wordCount == 0) {
                                wordCount = 1;
                            }
                            // no more space found, render the rest and then break
                            if (lastConsumedIdx < span.text.?.len - 1) {
                                // render the remainder
                                currentIdxOfSpace = span.text.?.len; //- 1;
                                std.log.debug("Trying with the remainder", .{});
                            } else {
                                break;
                            }
                        }
                        std.log.debug("current idx of spc {d}", .{currentIdxOfSpace});
                        // try if we fit. if we don't -> render up until last idx
                        var render_text = span.text.?[lastConsumedIdx..currentIdxOfSpace];
                        render_text_c = try self.styledTextblockSize_toCstring(render_text, layoutContext.fontSize, element.fontStyle, Infinity_Width, &attempted_span_size);
                        std.log.debug("   current available_width: {d}, attempted_span_size: {d:3.0}", .{ available_width, attempted_span_size.x });
                        if (attempted_span_size.x > available_width and wordCount > 1) {
                            // we wrapped!
                            // so render everything up until the last word
                            // then, render the new word in the new line?
                            if (wordCount == 1 and false) {
                                // special case: the first word wrapped, so we need to split it
                                // TODO: implement me
                                std.log.debug(">>>>>>>>>>>>> FIRST WORD !!!!!!!!!!!!!!!!!!! <<<<<<<<<<<<<<<<", .{});
                            } else {
                                // we check how large the current string (without that last word that caused wrapping) really is, to adjust our new current_pos.x:
                                available_width = layoutContext.origin_pos.x + layoutContext.available_size.x - layoutContext.current_pos.x;
                                const end_of_string_pos = if (lastIdxOfSpace > span.text.?.len) span.text.?.len else lastIdxOfSpace;
                                render_text = span.text.?[lastConsumedIdx..end_of_string_pos];
                                render_text_c = try self.styledTextblockSize_toCstring(render_text, layoutContext.fontSize, element.fontStyle, available_width, &attempted_span_size);
                                lastConsumedIdx = lastIdxOfSpace;
                                lastIdxOfSpace = currentIdxOfSpace;
                                element.text = render_text_c;
                                element.position = layoutContext.current_pos;
                                element.size.x = attempted_span_size.x;
                                // element.size = attempted_span_size;
                                std.log.debug(">>>>>>> appending wrapping text element: {s} width={d:3.0}", .{ element.text, attempted_span_size.x });
                                try renderSlide.elements.append(element);
                                // advance render pos
                                layoutContext.current_pos.x += attempted_span_size.x;
                                // something is rendered into the currend line, so adjust the line height if necessary
                                if (attempted_span_size.y > layoutContext.current_line_height) {
                                    layoutContext.current_line_height = attempted_span_size.y;
                                }

                                // we line break here and render the remaining word
                                //    hmmm. if we render the remaining word - further words are likely to be rendered, too
                                //    so maybe skip rendering it now?
                                std.log.debug(">>> BREAKING THE LINE, height: {}", .{layoutContext.current_line_height});
                                layoutContext.current_pos.x = layoutContext.origin_pos.x;
                                layoutContext.current_pos.y += layoutContext.current_line_height;
                                layoutContext.current_line_height = 0;
                                available_width = layoutContext.origin_pos.x + layoutContext.available_size.x - layoutContext.current_pos.x;
                            }
                        } else {
                            // if it's the last, uncommitted word
                            if (lastIdxOfSpace >= currentIdxOfSpace) {
                                available_width = layoutContext.origin_pos.x + layoutContext.available_size.x - layoutContext.current_pos.x;
                                render_text = span.text.?[lastConsumedIdx..currentIdxOfSpace];
                                render_text_c = try self.styledTextblockSize_toCstring(render_text, layoutContext.fontSize, element.fontStyle, available_width, &attempted_span_size);
                                lastConsumedIdx = lastIdxOfSpace;
                                lastIdxOfSpace = currentIdxOfSpace;
                                element.text = render_text_c;
                                element.position = layoutContext.current_pos;
                                // element.size = attempted_span_size;
                                std.log.debug(">>>>>>> appending final text element: {s} width={d:3.0}", .{ element.text, attempted_span_size.x });
                                element.size.x = attempted_span_size.x;
                                try renderSlide.elements.append(element);
                                // advance render pos
                                layoutContext.current_pos.x += attempted_span_size.x;
                                // something is rendered into the currend line, so adjust the line height if necessary
                                if (attempted_span_size.y > layoutContext.current_line_height) {
                                    layoutContext.current_line_height = attempted_span_size.y;
                                }

                                // let's not break the line because of the last word
                                // std.log.debug(">>> BREAKING THE LINE, height: {}", .{layoutContext.current_line_height});
                                // layoutContext.current_pos.x = layoutContext.origin_pos.x;
                                // layoutContext.current_pos.y += layoutContext.current_line_height;
                                // layoutContext.current_line_height = 0;
                                break; // it's the last word after all
                            }
                        }

                        lastIdxOfSpace = currentIdxOfSpace + 1;
                        // we start searching for the next space 1 after the last found one
                        if (currentIdxOfSpace + 1 < span.text.?.len) {
                            currentIdxOfSpace += 1;
                        } else {
                            //break;
                        }
                    }
                    // we could have run out of text to check for wrapping
                    // if that's the case: render the remainder
                }
            }
        } else {
            // no spans
            std.log.debug("LEAVE2 renderMdBlock ", .{});
            return;
        }
        std.log.debug("LEAVE3 renderMdBlock ", .{});
    }

    fn lineHightAndBulletWidthForFontSize(self: *SlideshowRenderer, fontsize: i32) imgui.ImVec2 {
        _ = self;
        var size = imgui.ImVec2{};
        var ret = imgui.ImVec2{};
        // TODO: this might be inaccurate if we use different fonts in the text block
        // whose pixel sizes vary significantly for given font sizes
        my_fonts.pushStyledFontScaled(fontsize, .normal);
        const text: [*c]const u8 = "FontCheck";
        imgui.igCalcTextSize(&size, text, text + 5, false, 8000);
        ret.y = size.y;
        var bullet_text: [*c]const u8 = undefined;
        bullet_text = "> "; // TODO this should ideally honor the real bullet symbol but I don't care atm
        imgui.igCalcTextSize(&size, bullet_text, bullet_text + std.mem.len(bullet_text), false, 8000);
        ret.x = size.x;
        my_fonts.popFontScaled();
        return ret;
    }

    fn countIndentOfBullet(self: *SlideshowRenderer, line: []const u8, indent_out: *usize) bool {
        _ = self;
        var indent: usize = 0;
        for (line) |c| {
            if (c == '-' or c == '>') {
                indent_out.* = indent;
                return true;
            }
            if (c != ' ' and c != '\t') {
                return false;
            }
            if (c == ' ') {
                indent += 1;
            }
            if (c == '\t') {
                indent += 4;
                // TODO: make tab to spaces ratio configurable
            }
        }
        return false;
    }

    fn toCString(self: *SlideshowRenderer, text: []const u8) ![*c]const u8 {
        return try self.allocator.dupeZ(u8, text);
    }

    fn styledTextblockSize_toCstring(self: *SlideshowRenderer, text: []const u8, fontsize: i32, fontstyle: my_fonts.FontStyle, block_width: f32, size_out: *imgui.ImVec2) ![*c]const u8 {
        my_fonts.pushStyledFontScaled(fontsize, fontstyle);
        defer my_fonts.popFontScaled();
        const ctext = try self.toCString(text);
        std.log.debug("cstring: of {s} = `{s}`", .{ text, ctext });
        if (ctext[0] == 0) {
            size_out.x = 0;
            size_out.y = 0;
            return ctext;
        }
        imgui.igCalcTextSize(size_out, ctext, &ctext[std.mem.len(ctext)], false, block_width);
        return ctext;
    }

    fn createImg(self: *SlideshowRenderer, renderSlide: *RenderedSlide, item: slides.SlideItem, slideshow_filp: []const u8) !void {
        _ = self;
        if (item.img_path) |p| {
            var texture = tcache.getImg(p, slideshow_filp) catch null;
            if (texture) |t| {
                try renderSlide.elements.append(RenderElement{
                    .kind = .image,
                    .position = item.position,
                    .size = item.size,
                    .texture = t,
                });
            }
        }
    }

    pub fn render(self: *SlideshowRenderer, slide_number: i32, pos: imgui.ImVec2, size: imgui.ImVec2, internal_render_size: imgui.ImVec2) !void {
        if (self.renderedSlides.items.len == 0) {
            std.log.debug("0 renderedSlides", .{});
            return;
        }

        const slide = self.renderedSlides.items[@intCast(usize, slide_number)];
        if (slide.elements.items.len == 0) {
            std.log.debug("0 elements", .{});
            return;
        }

        // TODO: pass that in from G
        const img_tint_col: imgui.ImVec4 = imgui.ImVec4{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }; // No tint
        const img_border_col: imgui.ImVec4 = imgui.ImVec4{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.0 }; // 50% opaque black

        for (slide.elements.items) |element| {
            switch (element.kind) {
                .background => {
                    if (element.texture) |txt| {
                        renderImg(.{}, internal_render_size, txt, img_tint_col, img_border_col, pos, size, internal_render_size);
                    } else {
                        if (element.color) |color| {
                            renderBgColor(color, internal_render_size, pos, size, internal_render_size);
                        } else {
                            //. empty
                        }
                    }
                },
                .text => {
                    renderText(&element, pos, size, internal_render_size);
                },
                .image => {
                    if (element.texture) |txt| {
                        renderImg(element.position, element.size, txt, img_tint_col, img_border_col, pos, size, internal_render_size);
                    }
                },
            }
        }
    }
};

pub fn slidePosToRenderPos(pos: imgui.ImVec2, slide_tl: imgui.ImVec2, slide_size: imgui.ImVec2, internal_render_size: imgui.ImVec2) imgui.ImVec2 {
    var my_tl = imgui.ImVec2{
        .x = slide_tl.x + pos.x * slide_size.x / internal_render_size.x,
        .y = slide_tl.y + pos.y * slide_size.y / internal_render_size.y,
    };

    if (renderDistortionAnimation.running and pos.y > 0) {
        my_tl.x += renderDistortion.dx;
        my_tl.y += renderDistortion.dy;
    }
    return my_tl;
}

pub fn slideSizeToRenderSize(size: imgui.ImVec2, slide_size: imgui.ImVec2, internal_render_size: imgui.ImVec2) imgui.ImVec2 {
    const my_size = imgui.ImVec2{
        .x = size.x * slide_size.x / internal_render_size.x,
        .y = size.y * slide_size.y / internal_render_size.y,
    };
    return my_size;
}

fn renderImg(pos: imgui.ImVec2, size: imgui.ImVec2, texture: zt.gl.Texture, tint_color: imgui.ImVec4, border_color: imgui.ImVec4, slide_tl: imgui.ImVec2, slide_size: imgui.ImVec2, internal_render_size: imgui.ImVec2) void {
    var uv_min = imgui.ImVec2{ .x = 0.0, .y = 0.0 }; // Top-let
    var uv_max = imgui.ImVec2{ .x = 1.0, .y = 1.0 }; // Lower-right

    // position the img in the slide
    const my_tl = slidePosToRenderPos(pos, slide_tl, slide_size, internal_render_size);
    var my_size = slideSizeToRenderSize(size, slide_size, internal_render_size);

    imgui.igSetCursorPos(my_tl);
    imgui.igImage(@intToPtr(*zt.gl.Texture, @ptrToInt(&texture)).imguiId(), my_size, uv_min, uv_max, tint_color, border_color);
}

fn renderBgColor(bgcol: imgui.ImVec4, size: imgui.ImVec2, slide_tl: imgui.ImVec2, slide_size: imgui.ImVec2, internal_render_size: imgui.ImVec2) void {
    // TODO: might have to translate to render coordinates!!!
    _ = internal_render_size;
    _ = size;
    imgui.igSetCursorPos(slide_tl);
    var drawlist = imgui.igGetForegroundDrawList_Nil();
    if (drawlist == null) {
        std.log.warn("drawlist is null!", .{});
    } else {
        var br = slide_tl;
        br.x = slide_tl.x + slide_size.x;
        br.y = slide_tl.y + slide_size.y;
        const bgcolu32 = imgui.igGetColorU32_Vec4(bgcol);
        imgui.igRenderFrame(slide_tl, br, bgcolu32, true, 0.0);
    }
}

fn renderText(item: *const RenderElement, slide_tl: imgui.ImVec2, slide_size: imgui.ImVec2, internal_render_size: imgui.ImVec2) void {
    if (item.text == null and item.color == null) {
        return;
    }
    // new: box without text, but with color: make a colored box
    if (item.text == null and item.color != null) {
        const startpos = slidePosToRenderPos(item.position, slide_tl, slide_size, internal_render_size);
        imgui.igSetCursorPos(startpos);
        var drawlist = imgui.igGetForegroundDrawList_Nil();
        if (drawlist == null) {
            std.log.warn("drawlist is null!", .{});
        } else {
            var sz = item.size;
            sz.x += item.position.x;
            sz.y += item.position.y;
            const br = slidePosToRenderPos(sz, slide_tl, slide_size, internal_render_size);
            const bgcolu32 = imgui.igGetColorU32_Vec4(item.color.?);
            imgui.igRenderFrame(startpos, br, bgcolu32, true, 0.0);
        }
        return;
    }

    // check for empty text
    if (item.text.?[0] == 0) {
        return;
    }
    var wrap_pos = item.position;
    wrap_pos.x += item.size.x;

    // we need to make the wrap pos slightly larger:
    // since for underline, sizes are pixel exact, later scaling of this might screw the wrapping - safety margin is 10 pixels here
    var wrap_offset = slidePosToRenderPos(.{ .x = 10, .y = 0 }, slide_tl, slide_size, internal_render_size).x;
    if (wrap_offset < 10) {
        wrap_offset = 10;
    }
    wrap_pos.x += wrap_offset;

    imgui.igPushTextWrapPos(slidePosToRenderPos(wrap_pos, slide_tl, slide_size, internal_render_size).x);
    const fs = item.fontSize.?;
    const fsize = @floatToInt(i32, @intToFloat(f32, fs) * slide_size.y / internal_render_size.y);
    const col = item.color;

    my_fonts.pushStyledFontScaled(fsize, item.fontStyle);
    defer my_fonts.popFontScaled();

    // diplay the text
    const t = item.text.?;
    imgui.igSetCursorPos(slidePosToRenderPos(item.position, slide_tl, slide_size, internal_render_size));
    imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_Text, col.?);
    imgui.igText(t);
    imgui.igPopStyleColor(1);
    imgui.igPopTextWrapPos();

    //   we need to rely on the size here, so better make sure, the width is correct
    if (item.underlined) {
        // how to draw the line?
        var tl = item.position;
        tl.y += @intToFloat(f32, fs) + 2;
        var br = tl;
        br.x += item.size.x;
        br.y += 2;
        const bgcolu32 = imgui.igGetColorU32_Vec4(col.?);
        imgui.igRenderFrame(slidePosToRenderPos(tl, slide_tl, slide_size, internal_render_size), slidePosToRenderPos(br, slide_tl, slide_size, internal_render_size), bgcolu32, true, 0.0);
    }
}
