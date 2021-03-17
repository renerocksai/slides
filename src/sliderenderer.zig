const std = @import("std");
const tcache = @import("texturecache.zig");
const slides = @import("slides.zig");
const upaya = @import("upaya");
const my_fonts = @import("myscalingfonts.zig");
const markdownlineparser = @import("markdownlineparser.zig");

usingnamespace upaya.imgui;
usingnamespace slides;
usingnamespace markdownlineparser;

const RenderElementKind = enum {
    background,
    text,
    image,
};

const RenderElement = struct {
    kind: RenderElementKind = .background,
    position: ImVec2 = ImVec2{},
    size: ImVec2 = ImVec2{},
    color: ?ImVec4 = ImVec4{},
    text: ?[*:0]const u8 = null,
    fontSize: ?i32 = null,
    underline_width: ?i32 = null,
    bullet_color: ?ImVec4 = null,
    texture: ?*upaya.Texture = null,
};

const RenderedSlide = struct {
    elements: std.ArrayList(RenderElement) = undefined,

    fn new(allocator: *std.mem.Allocator) !*RenderedSlide {
        var self: *RenderedSlide = try allocator.create(RenderedSlide);
        self.* = .{};
        self.elements = std.ArrayList(RenderElement).init(allocator);
        return self;
    }
};

pub const SlideshowRenderer = struct {
    renderedSlides: std.ArrayList(*RenderedSlide) = undefined,
    allocator: *std.mem.Allocator = undefined,
    md_parser: MdLineParser = .{},

    pub fn new(allocator: *std.mem.Allocator) !*SlideshowRenderer {
        var self: *SlideshowRenderer = try allocator.create(SlideshowRenderer);
        self.* = .{};
        self.*.allocator = allocator;
        self.renderedSlides = std.ArrayList(*RenderedSlide).init(allocator);
        self.md_parser.init(self.allocator);
        return self;
    }

    pub fn preRender(self: *SlideshowRenderer, slideshow: *const SlideShow, slideshow_filp: []const u8) !void {
        if (slideshow.slides.items.len == 0) {
            return;
        }

        self.renderedSlides.shrinkRetainingCapacity(0);

        for (slideshow.slides.items) |slide, i| {
            const slide_number = i + 1;

            if (slide.items.items.len == 0) {
                continue;
            }

            // add a renderedSlide
            var renderSlide = try RenderedSlide.new(self.allocator);

            for (slide.items.items) |item, j| {
                switch (item.kind) {
                    .background => try self.createBg(renderSlide, item, slideshow_filp),
                    .textbox => try self.preRenderTextBlock(renderSlide, item, slide_number),
                    // .textbox => try self.createTextBlock(renderSlide, item),
                    .img => try self.createImg(renderSlide, item, slideshow_filp),
                }
            }

            // now add the slide
            try self.renderedSlides.append(renderSlide);
        }
    }

    fn createBg(self: *SlideshowRenderer, renderSlide: *RenderedSlide, item: SlideItem, slideshow_filp: []const u8) !void {
        if (item.img_path) |p| {
            var texptr = try tcache.getImg(p, slideshow_filp);
            if (texptr) |t| {
                try renderSlide.elements.append(RenderElement{ .kind = .background, .texture = t });
            }
        } else {
            if (item.color) |color| {
                try renderSlide.elements.append(RenderElement{ .kind = .background, .color = color });
            }
        }
    }

    fn preRenderTextBlock(self: *SlideshowRenderer, renderSlide: *RenderedSlide, item: SlideItem, slide_number: usize) !void {
        // for line in lines:
        //     if line is bulleted: emit bullet, adjust x pos
        //     render spans
        const spaces_per_indent: usize = 4;
        var fontSize: i32 = 0;

        if (item.fontSize) |fs| {
            line_height_bullet_width = self.lineHightAndBulletWidthForFontSize(fs);
            fontSize = fs;
        } else {
            // no fontsize  - error!
            std.log.err("No fontsize for text {s}", .{item.text});
            return;
        }
        var bulletColor: ImVec4 = .{};
        if (item.bullet_color) |bc| {
            bulletColor = bc;
        } else {
            // no bullet color - error!
            std.log.err("No bullet color for text {s}", .{item.text});
            return;
        }

        const color = item.color orelse return;
        const underline_width = item.underline_width orelse 0;

        if (item.text) |t| {
            const tl_pos = ImVec2{ .x = item.position.x, .y = item.position.y };
            var layoutContext = TextLayoutContext{
                .size = .{ .x = item.size.x, .y = item.size.y },
                .pos = tl_pos,
                .fontSize = fontSize,
                .underline_width = underline_width,
                .color = color,
                .text = "", // will be overridden immediately
                .current_line_height = line_height_bullet_width.y, // will be overridden immediately but needed if text starts with empty line(s)
            };

            // split into lines
            var it = std.mem.split(t, "\n");
            while (it.next()) |line| {
                if (line.len == 0) {
                    // empty line
                    layoutContext.pos.y += layoutContext.current_line_height;
                    continue;
                }
                // find out, if line is a list item:
                //    - starts with `-` or `>`
                var bullet_indent_in_spaces: usize = 0;
                const is_bulleted = self.countIndentOfBullet(line, &bullet_indent_in_spaces);
                const indent_level = bullet_indent_in_spaces / spaces_per_indent;
                const indent_in_pixels = line_height_bullet_width.x * @intToFloat(f32, bullet_indent_in_spaces / spaces_per_indent);
                const available_width = item.size.x - indent_in_pixels;
                layoutContext.available_size.x = available_width;
                layoutContext.pos.x = tl_pos.x + indent_in_pixels;
                layoutContext.fontSize = fontSize;
                layoutContext.underline_width = underline_width;
                layoutContext.color = color;
                layoutContext.text = line;

                if (is_bulleted) {
                    // 1. add indented bullet symbol at the current pos
                    try renderSlide.elements.append(RenderElement{
                        .kind = .text,
                        .position = .{ .x = tl_pos.x + indent_in_pixels, .y = layoutContext.pos.y },
                        .size = .{ .x = available_width, .y = layoutContext.available_size.y },
                        .fontSize = fontSize,
                        .underline_width = underline_width,
                        .text = ">",
                        .color = bulletColor,
                    });
                    // 2. increase indent by 1 and add indented text block
                    available_width -= line_height_bullet_width.x;
                    layoutContext.pos.x += line_height_bullet_width.x;
                    layoutContext.size.x = available_width;
                    layoutContext.text = std.mem.trimLeft(u8, line, " \t->");
                }

                try self.renderMdBlock(renderSlide, &layoutContext);

                // advance to the next line
                layoutContext.pos.x = tl_pos.x;
                layoutContext.pos.y += layoutContext.current_line_height.y;

                // don't render (much) beyond size
                //
                // with this check, we will not render anything that would start outside the size rect.
                // Also, lines using the regular font will not exceed the size rect.
                // however,
                // - if a line uses a bigger font (more pixels) than the regular font, we might still exceed the size rect by the delta
                // - we might still draw underlines beyond the size.y if the last line fits perfectly.
                if (layoutContext.pos.y >= tl_pos.y + item.size.y - lineHightAndBulletWidthForFontSize.y) {
                    break;
                }
            }
        }
    }

    const TextLayoutContext = struct {
        pos: ImVec2 = .{},
        available_size: ImVec2 = .{},
        current_line_height: f32 = 0,
        fontSize: i32 = 0,
        underline_width: usize = 0,
        color: ImVec4 = .{},
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

        self.md_parser.init(self.allocator);
        try self.md_parser.parseLine(layoutContext.text);
        if (self.md_parser.result_spans) |spans| {
            if (spans.items.len == 0) {
                return;
            }
            self.md_parser.logSpans();

            const default_color = layoutContext.color;

            for (spans.items) |span| {
                // work out and push the font
                var fontstyle: FontStyle = .normal;
                var is_underlined = span.styleflags & StyleFlags.underline > 0;
                var is_colored = span.styleflags & StyleFlags.colored > 0;

                if (span.styleflags & (StyleFlags.bold | StyleFlags.italic) > 0) {
                    fontstyle = .bolditalic;
                } else if (span.styleflags & StyleFlags.bold > 0) {
                    fontstyle = .bold;
                } else if (span.styleflags & StyleFlags.italic > 0) {
                    fontstyle = italic;
                }

                my_fonts.pushStyledFontScaled(px, fontstyle);
                defer my_fonts.popFontScaled();

                // work out and push the color
                if (is_colored) {
                    igPushStyleColorVec4(default_color);
                } else {
                    igPushStyleColorVec4(span.color);
                }
                defer igPopStyleColor(1);

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

                // TODO: you are here!
                // check if whole line fits
                // orelse start wrapping (see above)
            }
        } else {
            // no spans
            return;
        }
    }

    fn createTextBlock(self: *SlideshowRenderer, renderSlide: *RenderedSlide, item: SlideItem) !void {
        var current_line_y: f32 = item.position.y;
        var current_available_height = item.size.y;
        var line_height_bullet_width: ImVec2 = .{};

        const spaces_per_indent: usize = 4;

        var fontSize: i32 = 0;
        if (item.fontSize) |fs| {
            line_height_bullet_width = self.lineHightAndBulletWidthForFontSize(fs);
            fontSize = fs;
        } else {
            // no fontsize  - error!
            std.log.err("No fontsize for text {s}", .{item.text});
            return;
        }

        var bulletColor: ImVec4 = .{};
        if (item.bullet_color) |bc| {
            bulletColor = bc;
        } else {
            // no bullet color - error!
            std.log.err("No bullet color for text {s}", .{item.text});
            return;
        }

        if (item.text) |t| {
            // split into lines
            var it = std.mem.split(t, "\n");
            while (it.next()) |line| {
                if (line.len == 0) {
                    // empty line
                    current_line_y += line_height_bullet_width.y;
                    continue;
                }
                // find out, if line is a list item:
                //    - starts with `-` or `>`
                var bullet_indent_in_spaces: usize = 0;
                const is_bulleted = self.countIndentOfBullet(line, &bullet_indent_in_spaces);

                const indent_level = bullet_indent_in_spaces / spaces_per_indent;
                const indent_in_pixels = line_height_bullet_width.x * @intToFloat(f32, bullet_indent_in_spaces / spaces_per_indent);
                var available_width = item.size.x - indent_in_pixels;
                var text_block_height: f32 = 0;

                if (is_bulleted) {
                    const render_text = std.mem.trimLeft(u8, line, " \t->");
                    const render_text_c = try self.heightOfTextblock_toCstring(render_text, fontSize, available_width, &text_block_height);
                    // 1. add indented bullet symbol at the current pos
                    try renderSlide.elements.append(RenderElement{
                        .kind = .text,
                        .position = .{ .x = item.position.x + indent_in_pixels, .y = current_line_y },
                        .size = .{ .x = available_width, .y = current_available_height },
                        .fontSize = fontSize,
                        .underline_width = item.underline_width,
                        .text = ">",
                        .color = bulletColor,
                    });
                    // 2. increase indent by 1 and add indented text block
                    available_width -= line_height_bullet_width.x;
                    try renderSlide.elements.append(RenderElement{
                        .kind = .text,
                        .position = .{ .x = item.position.x + indent_in_pixels + line_height_bullet_width.x, .y = current_line_y },
                        .size = .{ .x = available_width, .y = current_available_height },
                        .fontSize = fontSize,
                        .underline_width = item.underline_width,
                        .text = render_text_c,
                        .color = item.color,
                    });
                } else {
                    // normal text line
                    const render_text_c = try self.heightOfTextblock_toCstring(line, fontSize, available_width, &text_block_height);
                    try renderSlide.elements.append(RenderElement{
                        .kind = .text,
                        .position = .{ .x = item.position.x, .y = current_line_y },
                        .size = .{ .x = available_width, .y = current_available_height },
                        .fontSize = fontSize,
                        .underline_width = item.underline_width,
                        .text = render_text_c,
                        .color = item.color,
                    });
                }
                current_available_height -= text_block_height;
                current_line_y += text_block_height;
            }
        }
    }

    fn lineHightAndBulletWidthForFontSize(self: *SlideshowRenderer, fontsize: i32) ImVec2 {
        var size = ImVec2{};
        var ret = ImVec2{};
        my_fonts.pushFontScaled(fontsize);
        const text: [*c]const u8 = "FontCheck";
        igCalcTextSize(&size, text, text + 5, false, 8000);
        ret.y = size.y;
        var bullet_text: [*c]const u8 = undefined;
        bullet_text = "> ";
        igCalcTextSize(&size, bullet_text, bullet_text + std.mem.lenZ(bullet_text), false, 8000);
        ret.x = size.x;
        my_fonts.popFontScaled();
        return ret;
    }

    fn countIndentOfBullet(self: *SlideshowRenderer, line: []const u8, indent_out: *usize) bool {
        var indent: usize = 0;
        for (line) |c, i| {
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

    fn heightOfTextblock_toCstring(self: *SlideshowRenderer, text: []const u8, fontsize: i32, block_width: f32, height_out: *f32) ![*c]const u8 {
        var size = ImVec2{};
        my_fonts.pushFontScaled(fontsize);
        const ctext = try self.toCString(text);
        igCalcTextSize(&size, ctext, &ctext[std.mem.len(ctext) - 1], false, block_width);
        my_fonts.popFontScaled();
        height_out.* = size.y;
        return ctext;
    }

    fn createImg(self: *SlideshowRenderer, renderSlide: *RenderedSlide, item: SlideItem, slideshow_filp: []const u8) !void {
        if (item.img_path) |p| {
            var texptr = try tcache.getImg(p, slideshow_filp);
            if (texptr) |t| {
                try renderSlide.elements.append(RenderElement{
                    .kind = .image,
                    .position = item.position,
                    .size = item.size,
                    .texture = t,
                });
            }
        }
    }

    pub fn render(self: *SlideshowRenderer, slide_number: i32, pos: ImVec2, size: ImVec2, internal_render_size: ImVec2) !void {
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
        const img_tint_col: ImVec4 = ImVec4{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }; // No tint
        const img_border_col: ImVec4 = ImVec4{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.5 }; // 50% opaque black

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
                    renderImg(element.position, element.size, element.texture.?, img_tint_col, img_border_col, pos, size, internal_render_size);
                },
            }
        }
    }
};

fn slidePosToRenderPos(pos: ImVec2, slide_tl: ImVec2, slide_size: ImVec2, internal_render_size: ImVec2) ImVec2 {
    const my_tl = ImVec2{
        .x = slide_tl.x + pos.x * slide_size.x / internal_render_size.x,
        .y = slide_tl.y + pos.y * slide_size.y / internal_render_size.y,
    };
    return my_tl;
}

fn slideSizeToRenderSize(size: ImVec2, slide_size: ImVec2, internal_render_size: ImVec2) ImVec2 {
    const my_size = ImVec2{
        .x = size.x * slide_size.x / internal_render_size.x,
        .y = size.y * slide_size.y / internal_render_size.y,
    };
    return my_size;
}

fn renderImg(pos: ImVec2, size: ImVec2, texture: *upaya.Texture, tint_color: ImVec4, border_color: ImVec4, slide_tl: ImVec2, slide_size: ImVec2, internal_render_size: ImVec2) void {
    var uv_min = ImVec2{ .x = 0.0, .y = 0.0 }; // Top-let
    var uv_max = ImVec2{ .x = 1.0, .y = 1.0 }; // Lower-right

    // position the img in the slide
    const my_tl = slidePosToRenderPos(pos, slide_tl, slide_size, internal_render_size);
    const my_size = slideSizeToRenderSize(size, slide_size, internal_render_size);

    igSetCursorPos(my_tl);
    igImage(texture.*.imTextureID(), my_size, uv_min, uv_max, tint_color, border_color);
}

fn renderBgColor(bgcol: ImVec4, size: ImVec2, slide_tl: ImVec2, slide_size: ImVec2, internal_render_size: ImVec2) void {
    igSetCursorPos(slide_tl);
    var drawlist = igGetForegroundDrawListNil();
    if (drawlist == null) {
        std.log.warn("drawlist is null!", .{});
    } else {
        var br = slide_tl;
        br.x = slide_tl.x + slide_size.x;
        br.y = slide_tl.y + slide_size.y;
        const bgcolu32 = igGetColorU32Vec4(bgcol);
        igRenderFrame(slide_tl, br, bgcolu32, true, 0.0);
    }
}

fn renderText(item: *const RenderElement, slide_tl: ImVec2, slide_size: ImVec2, internal_render_size: ImVec2) void {
    var pos = item.position;
    pos.x += item.size.x;
    igPushTextWrapPos(slidePosToRenderPos(pos, slide_tl, slide_size, internal_render_size).x);
    const fs = item.fontSize.?;
    const fsize = @floatToInt(i32, @intToFloat(f32, fs) * slide_size.y / internal_render_size.y);
    my_fonts.pushFontScaled(fsize);
    const col = item.color;

    // diplay the text
    const t = item.text.?;
    // special case: 1st char is bullet
    igSetCursorPos(slidePosToRenderPos(.{ .x = item.position.x + 25, .y = item.position.y }, slide_tl, slide_size, internal_render_size));
    igPushStyleColorVec4(ImGuiCol_Text, col.?);
    igText(t);
    igPopStyleColor(1);
    my_fonts.popFontScaled();
    igPopTextWrapPos();
}
