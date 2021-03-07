const std = @import("std");
const upaya = @import("upaya");

usingnamespace upaya.imgui;

pub const SlideList = std.ArrayList(*Slide);

pub const SlideShow = struct {
    slides: SlideList = undefined,

    // defaults that can be overridden while parsing
    default_font: []u8 = "assets/Calibri Regular.ttf",
    default_font_bold: []u8 = "assets/Calibri Regular.ttf",
    default_font_italic: []u8 = "assets/Calibri Regular.ttf",
    default_font_bold_italic: []u8 = "assets/Calibri Regular.ttf",
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
    pos_in_editor: i32 = 0,
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
};

pub const SlideItemKind = enum {
    background,
    textbox,
    img,
};

pub const SlideItem = struct {
    kind: SlideItemKind = .background,
    text: ?[*:0]u8 = undefined,
    fontSize: i32 = 128,
    color: ImVec4 = ImVec4{},
    img_path: ?[]const u8 = undefined,
    position: ImVec2 = ImVec2{},
    size: ImVec2 = ImVec2{},
    underline_width: i32 = 1,
    bullet_color: ImVec4 = .{ .x = 1, .w = 1 },

    pub fn applyContext(self: *SlideItem, context: ItemContext) void {
        if (context.text) |text| self.text = text;
        if (context.fontSize) |fontsize| self.fontSize = fontsize;
        if (context.color) |color| self.color = color;
        if (context.position) |position| self.position = position;
        if (context.size) |size| self.size = size;
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
    const demoimgpath2 = "assets/nim/3.png";

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
        .text = "SOMETHING SOMETHING REJECTIONS\n\nDr. Carolin Kaiser, Rene Schallner",
        .color = ImVec4{ .x = 0xcd / 255.0, .y = 0x0f / 255.0, .z = 0x2d / 255.0, .w = 0.9 },
        .position = ImVec2{ .x = 219, .y = 758 },
        .size = ImVec2{ .x = 1149, .y = 246 },
    }) catch unreachable;
    slide_2.items.append(SlideItem{
        .kind = .img,
        .img_path = demoimgpath1[0..demoimgpath1.len],
        .position = ImVec2{ .x = 1000, .y = 300 },
        .size = ImVec2{ .x = 512, .y = 384 },
    }) catch unreachable;
    slides.append(slide_2) catch unreachable;
}
