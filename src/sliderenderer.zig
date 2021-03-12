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

    fn new(allocator: *std.mem.All) !void {
        var self: *RenderedSlide = try allocator.create(RenderedSlide);
        self.* = .{};
        self.elements = std.ArrayList(RenderElement).init(allocator);
        return self;
    }
};

pub const SlideshowRenderer = struct {
    renderedSlides: std.ArrayList(*RenderedSlide) = undefined,

    pub fn new(allocator: *std.mem.Allocator) !*SlideshowRenderer {
        var self: *SlideshowRenderer = try allocator.create(SlideshowRenderer);
        self.* = .{};
        self.renderedSlides = std.ArrayList(*RenderedSlide).init(allocator);
        return self;
    }

    pub fn preRender(self: *SlideshowRenderer, slideshow: *const SlideShow) !void {
        if (slideshow.slides.items.len == 0) {
            return;
        }

        for (slideshow.slides.items) |slide, i| {
            const slide_number = i + 1;

            if (slide.items.items.len == 0) {
                continue;
            }

            // add a renderedSlide
            var renderSlide = RenderedSlide.new();

            for (slide.items.items) |item, j| {
                switch (item.kind) {
                    .background => try self.createBg(item),
                    .textbox => try self.createTextBlock(item),
                    .img => try self.createImg(item),
                }
            }

            // now add the slide
            try self.renderedSlides.append(renderSlide);
        }
    }

    fn createBg(self: *SlideshowRenderer, renderSlide: *RenderedSlide, item: SlideItem) !void {
        if (item.img_path) |p| {
            var texptr = try tcache.getImg(p, G.slideshow_filp);
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
        try renderedSlide.elements.append(RenderElement{
            .kind = .text,
            .position = item.position,
            .size = item.size,
            .color = item.color,
            .text = item.text,
            .fontSize = item.fontSize,
            .underline_width = item.underline_width,
            .bullet_color = item.bullet_color,
        });
    }

    fn createImg(self: *SlideshowRenderer, renderSlide: *RenderedSlide, item: SlideItem) !void {
        if (item.img_path) |p| {
            var texptr = try tcache.getImg(p, G.slideshow_filp);
            if (texptr) |t| {
                try renderedSlide.elements.append(RenderElement{
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

fn scaleToSlide(size: ImVec2, slide_pos: ImVec2, slide_size: ImVec2, internal_render_size: ImVec2) ImVec2 {
    var ss = slide_size;
    var tl = slide_pos;
    var ret = ImVec2{};

    ret.x = size.x * ss.x / G.internal_render_size.x;
    ret.y = size.y * ss.y / G.internal_render_size.y;
    return ret;
}

fn slideImg(pos: ImVec2, size: ImVec2, texture: *Texture, tint_color: ImVec4, border_color: ImVec4, slide_tl: ImVec2, slide_size: ImVec2, internal_render_size: ImVec2) void {
    var uv_min = ImVec2{ .x = 0.0, .y = 0.0 }; // Top-let
    var uv_max = ImVec2{ .x = 1.0, .y = 1.0 }; // Lower-right

    // position the img in the slide
    const my_tl = ImVec2{
        .x = slide_pos.x + pos.x * slide_size.x / internal_render_size.x,
        .y = slide_pos.y + pos.y * slide_size.y / internal_render_size.y,
    };

    const my_size = ImVec2{
        .x = size.x * slide_size.x / internal_render_size.x,
        .y = size.y * slide_size.y / internal_render_size.y,
    };

    const tint_color: ImVec2 = .{};
    const border_color: ImVec2 = .{};

    igSetCursorPos(my_tl);
    igImage(texture.*.imTextureID(), my_size, uv_min, uv_max, tint_color, border_color);
}

fn slidePosToRenderPos
