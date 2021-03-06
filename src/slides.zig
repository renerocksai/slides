const std = @import("std");
const upaya = @import("upaya");

usingnamespace upaya.imgui;

// .
// Slides
// .
pub const Slide = struct {
    pos_in_editor: i32 = 0,
    items: std.ArrayList(SlideItem) = undefined,
    fn new(a: *std.mem.Allocator) *Slide {
        var slide_buffer = a.alloc(Slide, 1) catch unreachable;
        var slide: *Slide = &slide_buffer[0];
        slide.items = std.ArrayList(SlideItem).init(a);
        return slide;
    }
    fn deinit(self: *Slide) void {
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
};

// .
// demo slides
// .

pub fn makeDemoSlides(slides: *std.ArrayList(*Slide), allocator: *std.mem.Allocator) void {
    // title fontsize 96 color black, x=219, y=481, w=836 (, h=328)
    // subtitle fontsize 45 color #cd0f2d, x=219, y=758, w=1149, (y=246)
    // authors color #993366
    const demoimgpath1 = "assets/nim/1.png";
    const demoimgpath2 = "assets/nim/3.png";

    var slide_1: *Slide = Slide.new(allocator);
    var slide_2: *Slide = Slide.new(allocator);
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
