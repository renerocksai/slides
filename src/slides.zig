const std = @import("std");
const upaya = @import("upaya");

usingnamespace upaya.imgui;

pub const SlideList = std.ArrayList(*Slide);

pub const SlideShow = struct {
    slides: SlideList = undefined,

    // defaults that can be overridden while parsing
    default_font: []const u8 = "assets/Calibri Regular.ttf",
    default_font_bold: []const u8 = "assets/Calibri Regular.ttf",
    default_font_italic: []const u8 = "assets/Calibri Regular.ttf",
    default_font_bold_italic: []const u8 = "assets/Calibri Regular.ttf",
    default_fontsize: i32 = 16,
    default_underline_width: i32 = 1,
    default_color: ImVec4 = .{ .w = 0.9 },
    default_bullet_color: ImVec4 = .{ .x = 1, .w = 1 },

    // TODO: maybe later: font encountered while parsing
    fonts: std.ArrayList([]u8) = undefined,
    fontsizes: std.ArrayList(i32) = undefined,

    pub fn new(a: *std.mem.Allocator) !*SlideShow {
        var buffer = try a.alloc(SlideShow, 1);
        var instance: *SlideShow = &buffer[0];
        instance.slides = SlideList.init(a);
        // TODO: init font, fontsize arraylists
        return instance;
    }

    pub fn deinit(self: *SlideShow) void {
        self.slides.deinit();
    }
};

// .
// Slides
// .
pub const Slide = struct {
    pos_in_editor: usize = 0,
    line_in_editor: usize = 0,
    // TODO: don't we want to store pointers?
    items: std.ArrayList(SlideItem) = undefined,
    fontsize: i32 = 16,
    text_color: ImVec4 = .{ .w = 1 },
    bullet_color: ImVec4 = ImVec4{ .x = 1, .w = 1 },
    underline_width: i32 = 1,

    // .

    pub fn new(a: *std.mem.Allocator) !*Slide {
        var slide_buffer = try a.alloc(Slide, 1);
        var slide: *Slide = &slide_buffer[0];
        slide.items = std.ArrayList(SlideItem).init(a);
        return slide;
    }
    pub fn deinit(self: *Slide) void {
        self.items.deinit();
    }

    pub fn applyContext(self: *Slide, ctx: *ItemContext) void {
        if (ctx.fontSize) |fs| self.fontsize = fs;
        if (ctx.color) |col| self.text_color = col;
        if (ctx.bullet_color) |bul| self.bullet_color = bul;
        if (ctx.underline_width) |uw| self.underline_width = uw;
    }
};

pub const SlideItemKind = enum {
    background,
    textbox,
    img,
};

pub const SlideItem = struct {
    kind: SlideItemKind = .background,
    text: ?[*:0]u8 = undefined,
    fontSize: ?i32 = undefined,
    color: ?ImVec4 = ImVec4{},
    img_path: ?[]const u8 = undefined,
    position: ImVec2 = ImVec2{},
    size: ImVec2 = ImVec2{},
    underline_width: ?i32 = undefined,
    bullet_color: ?ImVec4 = undefined,

    pub fn new(a: *std.mem.Allocator) !*SlideItem {
        var slide_item_buffer = try a.alloc(SlideItem, 1);
        var slide_item: *SlideItem = &slide_item_buffer[0];
        return slide_item;
    }
    pub fn deinit(self: *Slide) void {
        // empty
    }

    pub fn applyContext(self: *SlideItem, allocator: *std.mem.Allocator, context: ItemContext) !void {
        if (context.text) |text| self.text = @ptrCast([*:0]u8, &try std.fmt.allocPrintZ(allocator, "{s}", .{text}));

        if (context.img_path) |img_path| self.img_path = img_path;
        if (context.fontSize) |fontsize| self.fontSize = fontsize;
        if (context.color) |color| self.color = color;
        if (context.position) |position| self.position = position;
        if (context.size) |size| self.size = size;
        if (context.underline_width) |w| self.underline_width = w;
        if (context.bullet_color) |color| self.bullet_color = color;
    }
    pub fn applySlideDefaultsIfNecessary(self: *SlideItem, slide: *Slide) void {
        if (self.fontSize == null) self.fontSize = slide.fontsize;
        if (self.color == null) self.color = slide.text_color;
        if (self.underline_width == null) self.underline_width = slide.underline_width;
        if (self.bullet_color == null) self.bullet_color = slide.bullet_color;
    }
    pub fn applySlideShowDefaultsIfNecessary(self: *SlideItem, slideshow: *SlideShow) void {
        if (self.fontSize == null) self.fontSize = slideshow.default_fontsize;
        if (self.color == null) self.color = slideshow.default_color;
        if (self.underline_width == null) self.underline_width = slideshow.default_underline_width;
        if (self.bullet_color == null) self.bullet_color = slideshow.default_bullet_color;
    }
};

pub const ItemContext = struct {
    directive: []const u8 = undefined, // @push, @slide, ...
    context_name: ?[]const u8 = null,
    text: ?[]const u8 = null,
    fontSize: ?i32 = null,
    color: ?ImVec4 = null,
    img_path: ?[]const u8 = null,
    position: ?ImVec2 = null,
    size: ?ImVec2 = null,
    underline_width: ?i32 = null,
    bullet_color: ?ImVec4 = null,
};

// .
// demo slides
// .

//pub fn makeDemoSlides(slides: *std.ArrayList(*Slide), allocator: *std.mem.Allocator) void {
pub fn makeDemoSlides(slides: *SlideList, allocator: *std.mem.Allocator) void {
    // title fontsize 96 color black, x=219, y=481, w=836 (, h=328)
    // subtitle fontsize 45 color #cd0f2d, x=219, y=758, w=1149, (y=246)
    // authors color #993366
    const demoimgpath1 = "assets/nim/1.png";
    const demoimgpath2 = "assets/nim/5.png";
    const demoimgpath3 = "assets/example.png";

    var slide_1: *Slide = Slide.new(allocator) catch unreachable;
    var slide_2: *Slide = Slide.new(allocator) catch unreachable;

    slide_1.pos_in_editor = 0;
    slide_2.pos_in_editor = 0;

    // Slide 1
    // background
    slide_1.items.append(SlideItem{ .kind = .background, .img_path = demoimgpath1[0..demoimgpath1.len] }) catch unreachable;
    // title
    slide_1.items.append(SlideItem{
        .kind = .textbox,
        .fontSize = 96,
        .text = "Artififial Voices in Human Choices",
        .color = ImVec4{ .w = 0.9 },
        .position = ImVec2{ .x = 219, .y = 481 },
        .size = ImVec2{ .x = 836, .y = 238 },
    }) catch unreachable;
    // subtitle etc
    slide_1.items.append(SlideItem{
        .kind = .textbox,
        .fontSize = 45,
        .text = "SOMETHING SOMETHING REJECTIONS\n\nDr. Carolin Kaiser, Rene Schallner",
        .color = ImVec4{ .x = 0xcd / 255.0, .y = 0x0f / 255.0, .z = 0x2d / 255.0, .w = 0.9 },
        .position = ImVec2{ .x = 219, .y = 758 },
        .size = ImVec2{ .x = 1149, .y = 246 },
    }) catch unreachable;
    slides.append(slide_1) catch unreachable;

    // Slide 2
    // background
    slide_2.items.append(SlideItem{ .kind = .background, .img_path = demoimgpath2[0..demoimgpath2.len] }) catch unreachable;
    // title
    slide_2.items.append(SlideItem{
        .kind = .textbox,
        .fontSize = 96,
        .text = "Artififial Voices in Human Choices",
        .color = ImVec4{ .w = 0.9 },
        .position = ImVec2{ .x = 219, .y = 481 },
        .size = ImVec2{ .x = 836, .y = 238 },
    }) catch unreachable;
    // subtitle etc
    slide_2.items.append(SlideItem{
        .kind = .textbox,
        .fontSize = 45,
        .text = "Milestone 3\n\nDr. Carolin Kaiser, Rene Schallner",
        .color = ImVec4{ .x = 0xcd / 255.0, .y = 0x0f / 255.0, .z = 0x2d / 255.0, .w = 0.9 },
        .position = ImVec2{ .x = 219, .y = 758 },
        .size = ImVec2{ .x = 1149, .y = 246 },
    }) catch unreachable;
    slide_2.items.append(SlideItem{
        .kind = .img,
        .img_path = demoimgpath3[0..demoimgpath3.len],
        .position = ImVec2{ .x = 916, .y = 121 },
        .size = ImVec2{ .x = 1916 / 3, .y = 2121 / 3 },
    }) catch unreachable;
    slides.append(slide_2) catch unreachable;
}
