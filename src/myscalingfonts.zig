const upaya = @import("upaya");
const sokol = @import("sokol");
const Texture = upaya.Texture;
const std = @import("std");
usingnamespace upaya.imgui;
usingnamespace sokol;

pub const FontStyle = enum {
    normal,
    bold,
    italic,
    bolditalic,
};

const FontMap = std.AutoHashMap(i32, *ImFont);
// const FontFileSpec = struct {
//     style: FontStyles = undefined,
//     filename: []const u8 = undefined,
//     size2font: ?*FontMap = null,
// };
//
// const FontNames = [_]FontFileSpec{
//     FontFileSpec{ .style = .normal, .filename = "../assets/Calibri Light.ttf" },
//     FontFileSpec{ .style = .bold, .filename = "../assets/Calibri Regular.ttf" }, // Calibri is the bold version of Calibri Light for us
//     FontFileSpec{ .style = .italic, .filename = "../assets/Calibri Light Italic.ttf" },
//     FontFileSpec{ .style = .bolditalic, .filename = "../assets/Calibri Italic.ttf" }, // Calibri is the bold version of Calibri Light for us
// };

//const baked_font_sizes = [_]i32{ 14, 20, 28, 36, 40, 45, 52, 60, 68, 72, 90, 96, 104, 128, 136, 144, 192, 300, 600 };
const baked_font_sizes = [_]i32{
    14,
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

const StyledFontMap = std.AutoHashMap(FontStyle, *FontMap);

const fontdata_normal = @embedFile("../assets/Calibri Light.ttf");
const fontdata_bold = @embedFile("../assets/Calibri Regular.ttf"); // Calibri is the bold version of Calibri Light for us
const fontdata_italic = @embedFile("../assets/Calibri Light Italic.ttf");
const fontdata_bolditalic = @embedFile("../assets/Calibri Italic.ttf"); // Calibri is the bold version of Calibri Light for us

var allFonts: StyledFontMap = StyledFontMap.init(std.heap.page_allocator);
var my_fonts = FontMap.init(std.heap.page_allocator);
var my_fonts_bold = FontMap.init(std.heap.page_allocator);
var my_fonts_italic = FontMap.init(std.heap.page_allocator);
var my_fonts_bolditalic = FontMap.init(std.heap.page_allocator);

pub fn loadFonts() error{OutOfMemory}!void {
    var io = igGetIO();
    ImFontAtlas_Clear(io.Fonts);
    _ = ImFontAtlas_AddFontDefault(io.Fonts, null);

    // init stuff
    try allFonts.put(.normal, &my_fonts);
    try allFonts.put(.bold, &my_fonts_bold);
    try allFonts.put(.italic, &my_fonts_italic);
    try allFonts.put(.bolditalic, &my_fonts_bolditalic);

    // actual font loading
    for (baked_font_sizes) |fsize, i| {
        try addFont(fsize);
    }
    commitFonts();
}

pub fn addFont(fsize: i32) !void {
    var io = igGetIO();
    var font_config = ImFontConfig_ImFontConfig();
    font_config[0].MergeMode = false;
    font_config[0].PixelSnapH = true;
    font_config[0].OversampleH = 1;
    font_config[0].OversampleV = 1;
    font_config[0].FontDataOwnedByAtlas = false;
    var font = ImFontAtlas_AddFontFromMemoryTTF(io.Fonts, fontdata_normal, fontdata_normal.len, @intToFloat(f32, fsize), font_config, ImFontAtlas_GetGlyphRangesDefault(io.Fonts));
    try my_fonts.put(fsize, font);

    var font_config_bold = ImFontConfig_ImFontConfig();
    font_config_bold[0].MergeMode = false;
    font_config_bold[0].PixelSnapH = true;
    font_config_bold[0].OversampleH = 1;
    font_config_bold[0].OversampleV = 1;
    font_config_bold[0].FontDataOwnedByAtlas = false;
    var font_bold = ImFontAtlas_AddFontFromMemoryTTF(io.Fonts, fontdata_bold, fontdata_bold.len, @intToFloat(f32, fsize), font_config_bold, ImFontAtlas_GetGlyphRangesDefault(io.Fonts));
    try my_fonts_bold.put(fsize, font_bold);

    var font_config_italic = ImFontConfig_ImFontConfig();
    font_config_italic[0].MergeMode = false;
    font_config_italic[0].PixelSnapH = true;
    font_config_italic[0].OversampleH = 1;
    font_config_italic[0].OversampleV = 1;
    font_config_italic[0].FontDataOwnedByAtlas = false;
    var font_italic = ImFontAtlas_AddFontFromMemoryTTF(io.Fonts, fontdata_italic, fontdata_italic.len, @intToFloat(f32, fsize), font_config_italic, ImFontAtlas_GetGlyphRangesDefault(io.Fonts));
    try my_fonts_italic.put(fsize, font_italic);

    var font_config_bolditalic = ImFontConfig_ImFontConfig();
    font_config_bolditalic[0].MergeMode = false;
    font_config_bolditalic[0].PixelSnapH = true;
    font_config_bolditalic[0].OversampleH = 1;
    font_config_bolditalic[0].OversampleV = 1;
    font_config_bolditalic[0].FontDataOwnedByAtlas = false;
    var font_bolditalic = ImFontAtlas_AddFontFromMemoryTTF(io.Fonts, fontdata_bolditalic, fontdata_bolditalic.len, @intToFloat(f32, fsize), font_config_bolditalic, ImFontAtlas_GetGlyphRangesDefault(io.Fonts));
    try my_fonts_bolditalic.put(fsize, font_bolditalic);
}

pub fn commitFonts() void {
    var io = igGetIO();
    var w: i32 = undefined;
    var h: i32 = undefined;
    var bytes_per_pixel: i32 = undefined;
    var pixels: [*c]u8 = undefined;
    ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, &pixels, &w, &h, &bytes_per_pixel);

    var tex = Texture.initWithData(pixels[0..@intCast(usize, w * h * bytes_per_pixel)], w, h, .nearest);
    ImFontAtlas_SetTexID(io.Fonts, tex.imTextureID());
}

var last_scale: f32 = 0.0;
var last_font: *ImFont = undefined;

pub const bakedFontInfo = struct {
    font: *ImFont, size: i32
};

pub fn pushFontScaled(pixels: i32) void {
    const font_info = getFontScaled(pixels);

    // we assume we have a font, now scale it
    last_scale = font_info.font.*.Scale;
    const new_scale: f32 = @intToFloat(f32, pixels) / @intToFloat(f32, font_info.size);
    //std.log.debug("--> Requested font size: {}, scaling from size: {} with scale: {}\n", .{ pixels, font_info.size, new_scale });
    font_info.font.*.Scale = new_scale;
    igPushFont(font_info.font);
    last_font = font_info.font;
}

pub fn pushStyledFontScaled(pixels: i32, style: FontStyle) void {
    const font_info = getStyledFontScaled(pixels, style);

    // TURN THIS ON to see what font sizes you need
    // std.log.info("fontsize {}", .{pixels});

    // we assume we have a font, now scale it
    last_scale = font_info.font.*.Scale;
    const new_scale: f32 = @intToFloat(f32, pixels) / @intToFloat(f32, font_info.size);
    //std.log.debug("--> Requested font size: {}, scaling from size: {} with scale: {}\n", .{ pixels, font_info.size, new_scale });
    font_info.font.*.Scale = new_scale;
    igPushFont(font_info.font);
    last_font = font_info.font;
}

pub fn notLikeThispushStyledFontScaled(pixels: i32, style: FontStyle) void {
    var font_info = getStyledFontScaled(pixels, style);
    if (font_info.size != pixels) {
        addFont(pixels) catch unreachable;
        commitFonts();
    }

    font_info = getStyledFontScaled(pixels, style);

    igPushFont(font_info.font);
    last_font = font_info.font;
}

pub fn getFontScaled(pixels: i32) bakedFontInfo {
    var min_diff: i32 = 1000;
    var found_font_size: i32 = baked_font_sizes[0];
    var font: *ImFont = my_fonts.get(baked_font_sizes[0]).?; // we don't ever down-scale. hence, default to minimum font size

    // the bloody hash map says it doesn't support field access when trying to iterate:
    //    var it = my_fonts.iterator();
    //     for (it.next()) |item| {
    for (baked_font_sizes) |fsize, i| {
        var diff = pixels - fsize;

        // std.log.debug("diff={}, pixels={}, fsize={}", .{ diff, pixels, fsize });

        // we only ever upscale, hence we look for positive differences only
        if (diff >= 0) {
            // we try to find the minimum difference
            if (diff < min_diff) {
                // std.log.debug("  diff={} is < than {}, so our new temp found_font_size={}", .{ diff, min_diff, fsize });
                min_diff = diff;
                font = my_fonts.get(fsize).?;
                found_font_size = fsize;
            }
        }
    }

    const ret = bakedFontInfo{ .font = font, .size = found_font_size };

    return ret;
}

pub fn getStyledFontScaled(pixels: i32, style: FontStyle) bakedFontInfo {
    var min_diff: i32 = 1000;
    var found_font_size: i32 = baked_font_sizes[0];

    var the_map = allFonts.get(style).?;
    var font: *ImFont = the_map.get(baked_font_sizes[0]).?; // we don't ever down-scale. hence, default to minimum font size

    // the bloody hash map says it doesn't support field access when trying to iterate:
    //    var it = my_fonts.iterator();
    //     for (it.next()) |item| {
    for (baked_font_sizes) |fsize, i| {
        var diff = pixels - fsize;

        // std.log.debug("diff={}, pixels={}, fsize={}", .{ diff, pixels, fsize });

        // we only ever upscale, hence we look for positive differences only
        if (diff >= 0) {
            // we try to find the minimum difference
            if (diff < min_diff) {
                // std.log.debug("  diff={} is < than {}, so our new temp found_font_size={}", .{ diff, min_diff, fsize });
                min_diff = diff;
                font = the_map.get(fsize).?;
                found_font_size = fsize;
            }
        }
    }

    const ret = bakedFontInfo{ .font = font, .size = found_font_size };

    return ret;
}

pub fn getNearestFontSize(pixels: i32) i32 {
    var min_diff: i32 = 1000;
    var found_font_size: i32 = baked_font_sizes[0];

    // the bloody hash map says it doesn't support field access when trying to iterate:
    //    var it = my_fonts.iterator();
    //     for (it.next()) |item| {
    for (baked_font_sizes) |fsize, i| {
        var diff = pixels - fsize;

        // std.log.debug("diff={}, pixels={}, fsize={}", .{ diff, pixels, fsize });

        // we only ever upscale, hence we look for positive differences only
        if (diff >= 0) {
            // we try to find the minimum difference
            if (diff < min_diff) {
                // std.log.debug("  diff={} is < than {}, so our new temp found_font_size={}", .{ diff, min_diff, fsize });
                min_diff = diff;
                found_font_size = fsize;
            }
        }
    }
    // std.log.debug("--> Nearest font size of {} is {}", .{ pixels, found_font_size });
    return found_font_size;
}

pub fn popFontScaled() void {
    igPopFont();
    last_font.*.Scale = last_scale;
}
