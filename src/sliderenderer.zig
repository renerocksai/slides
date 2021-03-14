const std = @import("std");
const tcache = @import("texturecache.zig");
const slides = @import("slides.zig");
const upaya = @import("upaya");
const my_fonts = @import("myscalingfonts.zig");

usingnamespace upaya.imgui;
usingnamespace slides;

const RenderElementKind = enum {
    background,
    text,
    bulleted_text,
    image,
};

const RenderElement = struct {
    kind: RenderElementKind = .background,
    position: ImVec2 = ImVec2{},
    size: ImVec2 = ImVec2{},
    color: ?ImVec4 = ImVec4{},
    text: ?[:0]const u8 = undefined,
    fontSize: ?i32 = undefined,
    underline_width: ?i32 = undefined,
    bullet_color: ?ImVec4 = undefined,
    texture: ?*upaya.Texture = undefined,
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

    pub fn new(allocator: *std.mem.Allocator) !*SlideshowRenderer {
        var self: *SlideshowRenderer = try allocator.create(SlideshowRenderer);
        self.* = .{};
        self.*.allocator = allocator;
        self.renderedSlides = std.ArrayList(*RenderedSlide).init(allocator);
        return self;
    }

    pub fn preRender(self: *SlideshowRenderer, slideshow: *const SlideShow, slideshow_filp: []const u8) !void {
        if (slideshow.slides.items.len == 0) {
            return;
        }

        // TODO: is this a good choice? Keeping the array but emptying it?
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
                    .textbox => try self.createTextBlock(renderSlide, item),
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
                try renderSlide.elements.append(RenderElement{ .kind = .background, .texture = texptr });
            }
        } else {
            if (item.color) |color| {
                try renderSlide.elements.append(RenderElement{ .kind = .background, .color = color });
            }
        }
    }

    fn createTextBlock(self: *SlideshowRenderer, renderSlide: *RenderedSlide, item: SlideItem) !void {
        // Split text:
        // Append lines
        // if line starts with - : terminate text block and create bulleted_text
        if (item.text) |t| {
            try renderSlide.elements.append(RenderElement{
                .kind = .text,
                .position = item.position,
                .size = item.size,
                .color = item.color,
                .text = try std.mem.dupeZ(self.allocator, u8, t),
                .fontSize = item.fontSize,
                .underline_width = item.underline_width,
                .bullet_color = item.bullet_color,
            });
        }
    }

    fn createImg(self: *SlideshowRenderer, renderSlide: *RenderedSlide, item: SlideItem, slideshow_filp: []const u8) !void {
        if (item.img_path) |p| {
            var texptr = try tcache.getImg(p, slideshow_filp);
            if (texptr) |t| {
                try renderSlide.elements.append(RenderElement{
                    .kind = .image,
                    .position = item.position,
                    .size = item.size,
                });
            }
        }
    }

    pub fn render(self: *SlideshowRenderer, slide_number: usize, pos: ImVec2, size: ImVec2, internal_render_size: ImVec2) !void {
        // .
    }
};

fn slidePosToRenderPos(pos: ImVec2, slide_tl: ImVec2, slide_size: ImVec2, internal_render_size: ImVec2) void {
    const my_tl = ImVec2{
        .x = slide_tl.x + pos.x * slide_size.x / internal_render_size.x,
        .y = slide_tl.y + pos.y * slide_size.y / internal_render_size.y,
    };
    return my_tl;
}

fn slideSizeToRenderSize(size: ImVec2, slide_size: ImVec2, internal_render_size: ImVec2) void {
    const my_size = ImVec2{
        .x = size.x * slide_size.x / internal_render_size.x,
        .y = size.y * slide_size.y / internal_render_size.y,
    };
    return my_size;
}

fn renderImg(pos: ImVec2, size: ImVec2, texture: *Texture, tint_color: ImVec4, border_color: ImVec4, slide_tl: ImVec2, slide_size: ImVec2, internal_render_size: ImVec2) void {
    var uv_min = ImVec2{ .x = 0.0, .y = 0.0 }; // Top-let
    var uv_max = ImVec2{ .x = 1.0, .y = 1.0 }; // Lower-right

    // position the img in the slide
    const my_tl = slidePosToRenderPos(pos, slide_tl, slide_size, internal_render_size);
    const my_size = slideSizeToRenderSize(size, slide_size, internal_render_size);

    const tint_color: ImVec2 = .{};
    const border_color: ImVec2 = .{};

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
        br.x = tl.x + slide_size.x;
        br.y = tl.y + slide_size.y;
        const bgcol = igGetColorU32Vec4(color);
        igRenderFrame(slide_tl, br, bgcol, true, 0.0);
    }
}

fn renderText(item: *RenderElement) void {
    var pos = item.position;
    pos.x += item.size.x;
    igPushTextWrapPos(trxyToSlideXY(pos).x);
    const fs = item.fontSize orelse slide.fontsize;
    const fsize = @floatToInt(i32, @intToFloat(f32, fs) * slideSizeInWindow().y / G.internal_render_size.y);
    my_fonts.pushFontScaled(fsize);
    const col = item.color orelse slide.text_color;

    // diplay the text
    // replace $slide_number by the slide number
    // TODO: FIXME : maybe need more buffer -- or be more flexible here
    var tt_buf: [1024]u8 = undefined;
    var tt: []u8 = tt_buf[0..];
    if (std.mem.lenZ(t) < tt_buf.len) {
        // pass 1: replace all `^-` with `> `
        // replace $slide_number first
        _ = std.mem.replace(u8, t, "$slide_number", "1", tt);
        _ = std.mem.replace(u8, tt, "\n- ", "\n", tt);
        // special case: 1st char is bullet
        const ttt = if (std.mem.startsWith(u8, tt, "- ")) tt[2..] else tt[0..];

        igSetCursorPos(trxyToSlideXY(.{ .x = item.position.x + 25, .y = item.position.y }));
        igPushStyleColorVec4(ImGuiCol_Text, col);
        igText(sliceToCforImguiText(ttt)); // TODO: store item texts as [*:0] -- see ParserErrorContext.getFormattedStr for inspiration
        igPopStyleColor(1);

        // pass 2: render only the bullet symbols
        const bullet_color = item.bullet_color orelse slide.bullet_color;
        igPushStyleColorVec4(ImGuiCol_Text, bullet_color);
        if (std.mem.startsWith(u8, tt, "- ")) {
            tt[0] = '>';
        }
        var newline: bool = true;
        for (t) |c, i| {
            if (c == '\n') {
                newline = true;
                tt[i] = c;
            } else {
                if (c == '-' and newline) {
                    tt[i] = '>';
                    continue;
                }
                newline = false;
                tt[i] = ' ';
            }
        }

        igSetCursorPos(trxyToSlideXY(item.position));
        igText(sliceToCforImguiText(tt));
        igPopStyleColor(1);
    }
    my_fonts.popFontScaled();
    igPopTextWrapPos();
}
