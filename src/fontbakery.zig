const imgui = @import("imgui");
const zt = @import("zt");
const Texture = zt.gl.Texture;
const std = @import("std");
const relpathToAbspath = @import("utils.zig").relpathToAbspath;
const gl = @import("gl");

const defaultGuiFontSize = 24;
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

    // for some reason, adding too many sizes just leads to font loading not working at all

    // 104,
    // 136,
    // 144,
    // 192,
    // 300,
};

pub const FontLoadDesc = struct {
    ttf_filn: []const u8,
    baked_font_sizes: ?[]const i32 = null,
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

// custom font data if loaded from the slide
var custom_fontdata_normal: [:0]const u8 = fontdata_normal;
var custom_fontdata_bold: [:0]const u8 = fontdata_bold;
var custom_fontdata_italic: [:0]const u8 = fontdata_italic;
var custom_fontdata_bolditalic: [:0]const u8 = fontdata_bolditalic;
var custom_fontdata_zig: [:0]const u8 = fontdata_zig;

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

    // set up the font ranges
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
    const gfs = gui_font_size orelse defaultGuiFontSize;
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

fn cleanFontMap(m: *FontMap) void {
    var it = m.valueIterator();
    while (it.next()) |fontptrptr| {
        imgui.ImFont_destroy(fontptrptr.*);
    }

    // the following is probably not necessary, as .deinit() should take care of it
    var kit = m.keyIterator();
    while (kit.next()) |p| {
        _ = m.remove(p.*);
    }
}

pub fn loadCustomFonts(fontConfig: FontConfig, slideshow_filp: []const u8) !void {
    var io = imgui.igGetIO();

    // try to delete all fonts
    cleanFontMap(&my_fonts);
    cleanFontMap(&my_fonts_bold);
    cleanFontMap(&my_fonts_italic);
    cleanFontMap(&my_fonts_bolditalic);
    cleanFontMap(&my_fonts_zig);

    // deinit hash maps for different font styles
    my_fonts.deinit();
    my_fonts_bold.deinit();
    my_fonts_italic.deinit();
    my_fonts_bolditalic.deinit();
    my_fonts_zig.deinit();
    allFonts.deinit();

    // we don't want to leak ttf binary data from a previous loadCustomFonts
    if (custom_fontdata_normal.ptr != fontdata_normal) std.heap.page_allocator.free(custom_fontdata_normal);
    if (custom_fontdata_bold.ptr != fontdata_bold) std.heap.page_allocator.free(custom_fontdata_bold);
    if (custom_fontdata_italic.ptr != fontdata_italic) std.heap.page_allocator.free(custom_fontdata_italic);
    if (custom_fontdata_bolditalic.ptr != fontdata_bolditalic) std.heap.page_allocator.free(custom_fontdata_bolditalic);
    if (custom_fontdata_zig.ptr != fontdata_zig) std.heap.page_allocator.free(custom_fontdata_zig);

    // all commented-out functions fail
    // imgui.ImFontAtlas_ClearFonts(io.*.Fonts);
    // imgui.ImFontAtlas_Clear(io.*.Fonts);
    // imgui.ImFontAtlas_ClearInputData(io.*.Fonts);
    imgui.ImFontAtlas_ClearTexData(io.*.Fonts);
    // imgui.ImFontAtlas_destroy(io.*.Fonts);

    // first, delete the texture from the previous font atlas
    var texId = @intCast(c_uint, @ptrToInt(io.*.Fonts.*.TexID));
    gl.glDeleteTextures(1, &texId);

    // then, create a new font atlas
    io.*.Fonts = imgui.ImFontAtlas_ImFontAtlas();

    const gfs = fontConfig.gui_font_size orelse defaultGuiFontSize;
    gui_font = imgui.ImFontAtlas_AddFontFromMemoryTTF(
        io.*.Fonts,
        castaway_const(fontdata_gui),
        fontdata_gui.len,
        @intToFloat(f32, gfs),
        null,
        imgui.ImFontAtlas_GetGlyphRangesDefault(io.*.Fonts),
    );

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

    if (fontConfig.normal) |fc| custom_fontdata_normal = loadTTF(fc.ttf_filn, slideshow_filp) catch fontdata_normal;
    if (fontConfig.bold) |fc| custom_fontdata_bold = loadTTF(fc.ttf_filn, slideshow_filp) catch fontdata_bold;
    if (fontConfig.italic) |fc| custom_fontdata_italic = loadTTF(fc.ttf_filn, slideshow_filp) catch fontdata_italic;
    if (fontConfig.bolditalic) |fc| custom_fontdata_bolditalic = loadTTF(fc.ttf_filn, slideshow_filp) catch fontdata_bolditalic;
    if (fontConfig.zig) |fc| custom_fontdata_zig = loadTTF(fc.ttf_filn, slideshow_filp) catch fontdata_zig;

    // and do the actual font loading
    // actual font loading
    for (baked_font_sizes) |fsize| {
        for (std.enums.values(FontStyle)) |style| {
            var fontdata: [:0]const u8 = switch (style) {
                .normal => custom_fontdata_normal,
                .bold => custom_fontdata_bold,
                .italic => custom_fontdata_italic,
                .bolditalic => custom_fontdata_bolditalic,
                .zig => custom_fontdata_zig,
            };
            try addFont(style, fsize, fontdata);
        }
    }
    _ = imgui.ImFontAtlas_Build(io.*.Fonts);
}

const FontLoadError = error{
    FileNotFoundError,
    ReadReturnedTooLittle,
};

fn loadTTF(ttf_filn: []const u8, slideshow_filp: []const u8) ![:0]const u8 {
    // careful: relpathToAbspath returns static buffer
    const abspath = try relpathToAbspath(ttf_filn, slideshow_filp);
    const file = try std.fs.openFileAbsolute(abspath, .{ .read = true });
    defer file.close();

    // now stat the file to get filesize
    const stat = try file.stat();
    const filesize = stat.size;

    // allocate mem for the file
    const allocator = std.heap.page_allocator;
    var buffer: []u8 = try allocator.alloc(u8, filesize);
    errdefer allocator.free(buffer);
    defer allocator.free(buffer);

    var howmany = try file.read(buffer);
    if (howmany != filesize)
        return FontLoadError.ReadReturnedTooLittle;

    var buffer2 = try std.cstr.addNullByte(allocator, buffer);

    return buffer2;
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
    var font_info = getStyledFontScaled(pixels, style);

    if (font_info) |finfo| {
        // TURN THIS ON to see what font sizes you need
        // std.log.info("fontsize {}", .{pixels});

        // we assume we have a font, now scale it
        last_scale = finfo.font.*.Scale;
        const new_scale: f32 = @intToFloat(f32, pixels) / @intToFloat(f32, finfo.size);
        finfo.font.*.Scale = new_scale;
        imgui.igPushFont(finfo.font);
        last_font = finfo.font;
    } else {
        // we cannot get the font, so don't change it
        // however, we must push something because the app wants to pop it off afterwards
        std.log.warn("Could not push font style {}, size {} -> pushing default font", .{ style, pixels });
        imgui.igPushFont(imgui.igGetDefaultFont());
    }
}

pub fn getStyledFontScaled(pixels: i32, style: FontStyle) ?bakedFontInfo {
    var min_diff: i32 = 1000;
    var found_font_size: i32 = baked_font_sizes[0];

    var the_map = allFonts.get(style);
    if (the_map) |map| {
        var the_font: ?*imgui.ImFont = map.get(baked_font_sizes[0]); // we don't ever down-scale. hence, default to minimum font size
        if (the_font) |_| {
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
                        the_font = map.get(fsize).?; // HERE we get the font out of the map
                        found_font_size = fsize;
                    }
                }
            }

            return bakedFontInfo{ .font = the_font.?, .size = found_font_size };
        } else {
            return null;
        }
    } else {
        return null;
    }
}

pub fn popFontScaled() void {
    imgui.igPopFont();
    last_font.*.Scale = last_scale;
}
