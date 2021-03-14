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
    text: ?[:0]const u8 = null,
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
                try renderSlide.elements.append(RenderElement{ .kind = .background, .texture = t });
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

        for (slide.elements.items) |element| {
            switch (element.kind) {
                .background => {
                    if (element.texture) |txt| {
                        const img_tint_col: ImVec4 = ImVec4{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }; // No tint
                        const img_border_col: ImVec4 = ImVec4{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.5 }; // 50% opaque black
                        renderImg(.{}, internal_render_size, txt, img_tint_col, img_border_col, pos, size, internal_render_size);
                    } else {
                        std.log.debug("bg: no texture", .{});
                        if (element.color) |color| {
                            renderBgColor(color, internal_render_size, pos, size, internal_render_size);
                        } else {
                            std.log.debug("bg: no color", .{});
                        }
                    }
                },
                .text => {
                    renderText(&element, pos, size, internal_render_size);
                },
                .image => {
                    std.log.debug("not rendering image", .{});
                },
                .bulleted_text => {
                    std.log.debug("not bulleted text", .{});
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
    std.log.debug("rendering img at {} size {}", .{ my_tl, my_size });
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
