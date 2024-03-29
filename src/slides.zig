const std = @import("std");
const imgui = @import("imgui");
const FontConfig = @import("fontbakery.zig").FontConfig;

const ImVec4 = imgui.ImVec4;
const ImVec2 = imgui.ImVec2;

pub const SlideList = std.ArrayList(*Slide);

pub const SlideShow = struct {
    slides: SlideList = undefined,

    // defaults that can be overridden while parsing
    default_fontsize: i32 = 16,
    default_underline_width: i32 = 1,
    default_color: ImVec4 = .{ .w = 0.9 },
    default_bullet_color: ImVec4 = .{ .x = 1, .w = 1 },
    default_bullet_symbol: []const u8 = ">",

    // TODO: maybe later: font encountered while parsing
    fonts: std.ArrayList([]u8) = undefined,
    fontsizes: std.ArrayList(i32) = undefined,

    pub fn new(a: std.mem.Allocator) !*SlideShow {
        var self = try a.create(SlideShow);
        self.* = .{};
        self.slides = SlideList.init(a);
        // TODO: init font, fontsize arraylists
        return self;
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
    items: ?std.ArrayList(SlideItem) = null,
    fontsize: i32 = 16,
    text_color: ImVec4 = .{ .w = 1 },
    bullet_color: ImVec4 = ImVec4{ .x = 1, .w = 1 },
    bullet_symbol: ?[]const u8 = null,
    underline_width: i32 = 1,

    // .

    pub fn new(a: std.mem.Allocator) !*Slide {
        std.log.debug("slide create 0 ", .{});
        // FIXME: loog above. why does zig want to return an optional here?
        var self: ?*Slide = try a.create(Slide);

        std.log.debug("slide create 2", .{});
        self.?.* = .{};
        std.log.debug("slide create 3", .{});
        self.?.items = std.ArrayList(SlideItem).init(a);
        std.log.debug("slide create 4", .{});
        return self.?;
    }
    pub fn deinit(self: *Slide) void {
        self.items.deinit();
    }

    pub fn applyContext(self: *Slide, ctx: *ItemContext) void {
        if (ctx.fontSize) |fs| self.fontsize = fs;
        if (ctx.color) |col| self.text_color = col;
        if (ctx.bullet_color) |bul| self.bullet_color = bul;
        if (ctx.underline_width) |uw| self.underline_width = uw;
        if (ctx.bullet_symbol) |bs| self.bullet_symbol = bs;
    }

    pub fn fromSlide(orig: *Slide, a: std.mem.Allocator) !*Slide {
        var n = try new(a);
        try n.items.?.appendSlice(orig.items.?.items);
        return n;
    }
};

pub const SlideItemKind = enum {
    background,
    textbox,
    img,
};

pub const SlideItemError = error{
    TextNull,
    ImgPathNull,
    FontSizeNull,
    ColorNull,
    UnderlineWidthNull,
    BulletColorNull,
    BulletSymbolNull,
};

pub const SlideItem = struct {
    kind: SlideItemKind = .background,
    text: ?[]const u8 = null,
    fontSize: ?i32 = null,
    color: ?ImVec4 = ImVec4{},
    img_path: ?[]const u8 = null,
    position: ImVec2 = ImVec2{},
    size: ImVec2 = ImVec2{},
    underline_width: ?i32 = null,
    bullet_color: ?ImVec4 = null,
    bullet_symbol: ?[]const u8 = null,

    pub fn new(a: std.mem.Allocator) !*SlideItem {
        var self = try a.create(SlideItem);
        self.* = .{};
        return self;
    }
    pub fn deinit(_: *Slide) void {
        // empty
    }

    pub fn applyContext(self: *SlideItem, context: ItemContext) void {
        if (context.text) |text| self.text = text;

        if (context.img_path) |img_path| self.img_path = img_path;
        if (context.fontSize) |fontsize| self.fontSize = fontsize;
        if (context.color) |color| self.color = color;
        if (context.position) |position| self.position = position;
        if (context.size) |size| self.size = size;
        if (context.underline_width) |w| self.underline_width = w;
        if (context.bullet_color) |color| self.bullet_color = color;
        if (context.bullet_symbol) |symbol| self.bullet_symbol = symbol;
    }
    pub fn applySlideDefaultsIfNecessary(self: *SlideItem, slide: *Slide) void {
        if (self.fontSize == null) self.fontSize = slide.fontsize;
        if (self.color == null) self.color = slide.text_color;
        if (self.underline_width == null) self.underline_width = slide.underline_width;
        if (self.bullet_color == null) self.bullet_color = slide.bullet_color;
        if (self.bullet_symbol == null) self.bullet_symbol = slide.bullet_symbol;
    }
    pub fn applySlideShowDefaultsIfNecessary(self: *SlideItem, slideshow: *SlideShow) void {
        if (self.fontSize == null) {
            self.fontSize = slideshow.default_fontsize;
        }
        if (self.color == null) {
            self.color = slideshow.default_color;
        }

        // TODO: BUG BUG compiler BUG ?!?!?!?!?!
        // if(self.underline_width == null) { A } else { B }
        // does not work. Even when it is null, the B branch is always executed
        // -- I am not sure whether it is really a bug or if I just got the concept
        // of optionals wrong back then
        if (self.underline_width) |_| {} else {
            self.underline_width = slideshow.default_underline_width;
        }

        if (self.bullet_color) |_| {} else {
            self.bullet_color = slideshow.default_bullet_color;
        }

        if (self.bullet_symbol) |_| {} else {
            self.bullet_symbol = slideshow.default_bullet_symbol;
        }
    }

    pub fn sanityCheck(self: *SlideItem) SlideItemError!void {
        if (self.text == null and self.color == null and self.kind == .textbox) return SlideItemError.TextNull;
        if (self.fontSize == null and self.kind == .textbox) return SlideItemError.FontSizeNull;
        if (self.color == null and self.kind == .textbox) return SlideItemError.ColorNull;
        if (self.underline_width == null and self.kind == .textbox) return SlideItemError.UnderlineWidthNull;
        if (self.bullet_color == null and self.kind == .textbox) return SlideItemError.BulletColorNull;
        if (self.bullet_symbol == null and self.kind == .textbox) return SlideItemError.BulletSymbolNull;

        if (self.img_path == null and (self.kind == .img)) return SlideItemError.ImgPathNull;
        if (self.kind == .background) {
            if (self.img_path == null and self.color == null) {
                return SlideItemError.ColorNull;
            }
        }
    }

    pub fn printToLog(self: *const SlideItem) void {
        const indent = "    ";
        switch (self.kind) {
            .background => {
                std.log.info(indent ++ "Kind: Background", .{});
                if (self.img_path) {
                    std.log.info(indent ++ "   img: {any}", .{self.img_path});
                    std.log.info(indent ++ "   pos: {any}", .{self.position});
                    std.log.info(indent ++ "  size: {any}", .{self.size});
                } else {
                    std.log.info(indent ++ " color: {any}", .{self.color});
                }
            },
            .img => {
                std.log.info(indent ++ "Kind: Image", .{});
                std.log.info(indent ++ "   img: {any}", .{self.img_path});
                std.log.info(indent ++ "   pos: {any}", .{self.position});
                std.log.info(indent ++ "  size: {any}", .{self.size});
            },
            .textbox => {
                std.log.info(indent ++ "Kind: TextBox", .{});
                std.log.info(indent ++ "   pos: {any}", .{self.position});
                std.log.info(indent ++ "  size: {any}", .{self.size});
                if (self.text) |text| {
                    std.log.info(indent ++ "  text:({d}) `{s}`", .{ std.mem.len(text), text });
                } else {
                    std.log.info(indent ++ "  text: (null)", .{});
                }
                std.log.info(indent ++ " fsize: {any}", .{self.fontSize});
                std.log.info(indent ++ "uwidth: {any}", .{self.underline_width});
                std.log.info(indent ++ "bcolor: {any}", .{self.bullet_color});
                std.log.info(indent ++ "bsymbl: {any}", .{self.bullet_symbol});
            },
        }
        std.log.info(indent ++ "-----------------------", .{});
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
    bullet_symbol: ?[]const u8 = null,
    line_number: usize = 0,
    line_offset: usize = 0,

    pub fn applyOtherIfNull(self: *ItemContext, other: ItemContext) void {
        if (self.text == null) {
            if (other.text) |text| self.text = text;
        }

        if (self.img_path == null) {
            if (other.img_path) |img_path| self.img_path = img_path;
        }
        if (self.fontSize == null) {
            if (other.fontSize) |fontsize| self.fontSize = fontsize;
        }
        if (self.color == null) {
            if (other.color) |color| self.color = color;
        }
        if (self.position == null) {
            if (other.position) |position| self.position = position;
        }
        if (self.size == null) {
            if (other.size) |size| self.size = size;
        }
        if (self.underline_width == null) {
            if (other.underline_width) |w| self.underline_width = w;
        }
        if (self.bullet_color == null) {
            if (other.bullet_color) |color| self.bullet_color = color;
        }
        if (self.bullet_symbol == null) {
            if (other.bullet_symbol) |symbol| self.bullet_symbol = symbol;
        }
    }
};
