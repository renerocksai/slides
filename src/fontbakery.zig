const imgui = @import("imgui");
const zt = @import("zt");
const Texture = zt.gl.Texture;
const std = @import("std");
const relpathToAbspath = @import("texturecache.zig").relpathToAbspath;

pub const FontStyle = enum {
    normal,
    bold,
    italic,
    bolditalic,
    zig,
};

const FontMap = std.AutoHashMap(i32, *imgui.ImFont);
//const baked_font_sizes = [_]i32{ 14, 20, 28, 36, 40, 45, 52, 60, 68, 72, 90, 96, 104, 128, 136, 144, 192, 300, 600 };
const baked_font_sizes = [_]i32{
    14,
    16, // editor font -- in its own font now, but let's leave the 16 in here anyway
    20,
    22,
    28,
    32,
    36,
    40,
    45,
    52,
    60,
    68,
    72,
    90,
    96,
    104,
    136,
    144,
    192,
    300,
};

pub const FontLoadDesc = struct {
    ttf_filn: []const u8,
    baked_font_sizes: ?[]const i32,
};

pub const FontConfig = struct {
    gui_font_size: ?i32 = null,
    normal: ?FontLoadDesc = null,
    bold: ?FontLoadDesc = null,
    italic: ?FontLoadDesc = null,
    bolditalic: ?FontLoadDesc = null,
    zig: ?FontLoadDesc = null,
};

const fontdata_gui = @embedFile("../ZT/example/assets/public-sans.ttf");
const fontdata_normal = @embedFile("../assets/Calibri Light.ttf");
const fontdata_bold = @embedFile("../assets/Calibri Regular.ttf"); // Calibri is the bold version of Calibri Light for us
const fontdata_italic = @embedFile("../assets/Calibri Light Italic.ttf");
const fontdata_bolditalic = @embedFile("../assets/Calibri Italic.ttf"); // Calibri is the bold version of Calibri Light for us
const fontdata_zig = @embedFile("../assets/press-start-2p.ttf");

const StyledFontMap = std.AutoHashMap(FontStyle, *FontMap);
var allFonts: StyledFontMap = StyledFontMap.init(std.heap.page_allocator);

pub var gui_font: *imgui.ImFont = undefined;

var my_fonts = FontMap.init(std.heap.page_allocator);
var my_fonts_bold = FontMap.init(std.heap.page_allocator);
var my_fonts_italic = FontMap.init(std.heap.page_allocator);
var my_fonts_bolditalic = FontMap.init(std.heap.page_allocator);
var my_fonts_zig = FontMap.init(std.heap.page_allocator);

pub fn addFont(style: FontStyle, size: i32, fontdata: [:0]const u8) !void {
    if (style == .zig and size >= 192) return; // no point in super-large
    // if you remove above check, imgui will not be able to handle it
    // not even the gui font will work then

    // set up the font rasges
    // The following spits out the range {32, 255} :
    // const default_font_ranges: [*:0]const imgui.ImWchar = imgui.ImFontAtlas_GetGlyphRangesDefault(io.*.Fonts);
    // std.log.debug("font ranges: {d}", .{default_font_ranges});
    // bullets: 2022, 2023, 2043
    const my_font_ranges = [_]imgui.ImWchar{
        32, 255, // default range
        0x2022, 0x2023, // bullet and triangular bullet(triangular does not work with my calibri light)
        0, // sentinel
    };

    var font_config = imgui.ImFontConfig_ImFontConfig();
    font_config[0].MergeMode = false;
    font_config[0].PixelSnapH = true;
    font_config[0].OversampleH = 1;
    font_config[0].OversampleV = 1;
    font_config[0].FontDataOwnedByAtlas = false;
    var io = imgui.igGetIO();
    var font = imgui.ImFontAtlas_AddFontFromMemoryTTF(
        io.*.Fonts,
        @intToPtr(*anyopaque, @ptrToInt(&fontdata[0])),
        @intCast(c_int, fontdata.len + 1),
        @intToFloat(f32, size),
        font_config,
        &my_font_ranges,
    );

    std.log.debug("loaded font: style={}, size={}, bufferlen: {} => {*}", .{ style, size, fontdata.len, font });

    var fontmap = switch (style) {
        .normal => &my_fonts,
        .bold => &my_fonts_bold,
        .italic => &my_fonts_italic,
        .bolditalic => &my_fonts_bolditalic,
        .zig => &my_fonts_zig,
    };

    try fontmap.put(size, font);
}

fn castaway_const(ptr: *const anyopaque) *anyopaque {
    return (@intToPtr(*anyopaque, @ptrToInt(ptr)));
}

pub fn loadDefaultFonts(gui_font_size: ?i32) !void {
    var io = imgui.igGetIO();
    imgui.ImFontAtlas_Clear(io.*.Fonts);
    const gfs = gui_font_size orelse 16;
    std.log.debug("gui font size: {}", .{gfs});
    gui_font = imgui.ImFontAtlas_AddFontFromMemoryTTF(
        io.*.Fonts,
        castaway_const(fontdata_gui),
        fontdata_gui.len,
        @intToFloat(f32, gfs),
        null,
        imgui.ImFontAtlas_GetGlyphRangesDefault(io.*.Fonts),
    );

    // init hash maps for different font styles
    try allFonts.put(.normal, &my_fonts);
    try allFonts.put(.bold, &my_fonts_bold);
    try allFonts.put(.italic, &my_fonts_italic);
    try allFonts.put(.bolditalic, &my_fonts_bolditalic);
    try allFonts.put(.zig, &my_fonts_zig);

    // actual font loading
    for (baked_font_sizes) |fsize| {
        for (std.enums.values(FontStyle)) |style| {
            var fontdata: [:0]const u8 = switch (style) {
                .normal => fontdata_normal,
                .bold => fontdata_bold,
                .italic => fontdata_italic,
                .bolditalic => fontdata_bolditalic,
                .zig => fontdata_zig,
            };
            try addFont(style, fsize, fontdata);
        }
    }
}

pub fn loadCustomFonts(fontConfig: FontConfig) !void {
    var io = imgui.igGetIO();
    imgui.ImFontAtlas_Clear(io.*.Fonts);
    const gfs = fontConfig.gui_font_size orelse 16;
    std.log.debug("gui font size: {}", .{gfs});
    gui_font = imgui.ImFontAtlas_AddFontFromMemoryTTF(
        io.*.Fonts,
        castaway_const(fontdata_gui),
        fontdata_gui.len,
        @intToFloat(f32, gfs),
        null,
        imgui.ImFontAtlas_GetGlyphRangesDefault(io.*.Fonts),
    );

    // clear hash maps for different font styles
    // TODO: deinit the actual font maps returned by imgui
    my_fonts.deinit();
    my_fonts_bold.deinit();
    my_fonts_italic.deinit();
    my_fonts_bolditalic.deinit();
    my_fonts_zig.deinit();
    allFonts.deinit();

    // now re-init the hash maps
    allFonts = StyledFontMap.init(std.heap.page_allocator);
    my_fonts = FontMap.init(std.heap.page_allocator);
    my_fonts_bold = FontMap.init(std.heap.page_allocator);
    my_fonts_italic = FontMap.init(std.heap.page_allocator);
    my_fonts_bolditalic = FontMap.init(std.heap.page_allocator);
    my_fonts_zig = FontMap.init(std.heap.page_allocator);
    try allFonts.put(.normal, &my_fonts);
    try allFonts.put(.bold, &my_fonts_bold);
    try allFonts.put(.italic, &my_fonts_italic);
    try allFonts.put(.bolditalic, &my_fonts_bolditalic);
    try allFonts.put(.zig, &my_fonts_zig);

    // load the fonts from files
    // TODO : <--------------------------------------------------- TODO : YOU : TODO ARE :TODO HERE

    // and do the actual font loading
}

var last_scale: f32 = 0.0;
var last_font: *imgui.ImFont = undefined;

pub const bakedFontInfo = struct { font: *imgui.ImFont, size: i32 };

pub fn pushGuiFont(scale: f32) void {
    // we assume we have a font, now scale it
    gui_font.Scale = scale;
    imgui.igPushFont(gui_font);
}

pub fn popGuiFont() void {
    imgui.igPopFont();
}

pub fn pushStyledFontScaled(pixels: i32, style: FontStyle) void {
    const font_info = getStyledFontScaled(pixels, style);

    // TURN THIS ON to see what font sizes you need
    // std.log.info("fontsize {}", .{pixels});

    // we assume we have a font, now scale it
    last_scale = font_info.font.*.Scale;
    const new_scale: f32 = @intToFloat(f32, pixels) / @intToFloat(f32, font_info.size);
    font_info.font.*.Scale = new_scale;
    imgui.igPushFont(font_info.font);
    last_font = font_info.font;
}

pub fn getStyledFontScaled(pixels: i32, style: FontStyle) bakedFontInfo {
    var min_diff: i32 = 1000;
    var found_font_size: i32 = baked_font_sizes[0];

    var the_map = allFonts.get(style).?;
    var font: *imgui.ImFont = the_map.get(baked_font_sizes[0]).?; // we don't ever down-scale. hence, default to minimum font size

    for (baked_font_sizes) |fsize| {
        if (style == .zig) {
            if (fsize >= 192) {
                continue;
            }
        }
        var diff = pixels - fsize;

        // we only ever upscale, hence we look for positive differences only
        if (diff >= 0) {
            // we try to find the minimum difference
            if (diff < min_diff) {
                min_diff = diff;
                font = the_map.get(fsize).?;
                found_font_size = fsize;
            }
        }
    }

    if (style == .zig) {
        if (found_font_size >= 192) {
            found_font_size = 144; // TODO: hack
        }
    }
    return bakedFontInfo{ .font = font, .size = found_font_size };
}

pub fn popFontScaled() void {
    imgui.igPopFont();
    last_font.*.Scale = last_scale;
}
