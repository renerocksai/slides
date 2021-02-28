const upaya = @import("upaya");
const sokol = @import("sokol");
const Texture = @import("../zig-upaya/src/texture.zig").Texture;
const std = @import("std");
const uianim = @import("uianim.zig");

usingnamespace upaya.imgui;
usingnamespace sokol;
usingnamespace uianim;

const my_fonts = @import("myscalingfonts.zig");

pub fn main() !void {
    upaya.run(.{
        .init = init,
        .update = update,
        .app_name = "Slides",
        .window_title = "Slides",
        .ini_file_storage = .none,
        .swap_interval = 1, // ca 16ms
        .width = 1920,
        .height = 1080,
    });
}

var tex: ?upaya.Texture = null;

fn init() void {
    my_fonts.loadFonts() catch unreachable;
    // upaya.colors.setTintColor(upaya.colors.rgbaToVec4(0xcd, 0x0f, 0x00, 0xff));
    if (tex == null) tex = upaya.Texture.initFromFile("./assets/nim/1.png", .nearest) catch unreachable;
    std.log.info("tex: {}", .{tex});
    std.log.info("checking for undefined", .{});
}

// .
// UI scaling
// .
var global_scale: f32 = 1.0;

fn relativeScaleForAbsoluteScale(new_scale: f32) f32 {
    return new_scale / global_scale;
}

fn scaleUI(new_scale: f32) void {
    var new_relative_scale = relativeScaleForAbsoluteScale(new_scale);
    ImGuiStyle_ScaleAllSizes(igGetStyle(), new_relative_scale);
    igGetIO().*.FontGlobalScale = new_scale;
    global_scale = new_scale;
}

// .
// App State
// .
const AppState = enum {
    mainmenu,
    presenting,
    slide_overview,
};

const AppData = struct {
    app_state: AppState = .mainmenu,
    content_window_size: ImVec2 = ImVec2{},
    internal_render_size: ImVec2 = ImVec2{ .x = 1920.0, .y = 1080.0 },
    slide_render_width: f32 = 1920.0,
    img_tint_col: ImVec4 = ImVec4{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, // No tint
    img_border_col: ImVec4 = ImVec4{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.5 }, // 50% opaque black
};

var g_app_data = AppData{};

// .
// Animation
// .
var bt_anim_1 = ButtonAnim{};
var bt_anim_2 = ButtonAnim{};
var bt_anim_3 = ButtonAnim{};

var ed_anim = EditAnim{};
var bt_toggle_ed_anim = ButtonAnim{};
var bt_toggle_fullscreen_anim = ButtonAnim{};
var bt_backtomenu_anim = ButtonAnim{};

// .
// Main Update Frame Loop
// .

// update will be called at every swap interval. with swap_interval = 1 above, we'll get 60 fps
fn update() void {
    // replace the default font
    my_fonts.pushFontScaled(14);
    igGetWindowContentRegionMax(&g_app_data.content_window_size);

    var flags: c_int = 0;
    flags = ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoDocking | ImGuiWindowFlags_NoTitleBar;
    if (igBegin("main", null, flags)) {
        // make the "window" fill the whole available area
        igSetWindowPosStr("main", .{ .x = 0, .y = 0 }, ImGuiCond_Always);
        igSetWindowSizeStr("main", g_app_data.content_window_size, ImGuiCond_Always);

        switch (g_app_data.app_state) {
            .mainmenu => showMainMenu(&g_app_data),
            .presenting => showSlide() catch unreachable,
            else => {
                var b: bool = true;
                igShowMetricsWindow(&b);
            },
        }
        // pop the default font
        my_fonts.popFontScaled();
        igEnd();
    }
}

fn showSlide() !void {
    // optionally show editor
    igSetCursorPos(trxy(ImVec2{ .x = g_app_data.internal_render_size.x - ed_anim.current_size.x, .y = 0.0 }));
    my_fonts.pushFontScaled(32);
    try animatedEditor(&ed_anim, ImVec2{ .x = 600.0, .y = g_app_data.internal_render_size.y - 35 }, g_app_data.content_window_size, g_app_data.internal_render_size);
    my_fonts.popFontScaled();

    // render slide
    g_app_data.slide_render_width = g_app_data.internal_render_size.x - ed_anim.current_size.x;
    slideImg(slideAreaTL(), g_app_data.internal_render_size, &tex.?, g_app_data.img_tint_col, g_app_data.img_border_col);

    // button row
    igSetCursorPos(trxy(ImVec2{ .x = (300.0), .y = g_app_data.internal_render_size.y - 35.0 }));
    if (animatedButton("main menu", trxy(ImVec2{ .x = 100, .y = 20 }), &bt_backtomenu_anim) == .released) {
        g_app_data.app_state = .mainmenu;
    }
    igSetCursorPos(trxy(ImVec2{ .x = (1920.0 - 100.0) / 2.0, .y = g_app_data.internal_render_size.y - 35.0 }));
    if (animatedButton("fullscreen", trxy(ImVec2{ .x = 100, .y = 20 }), &bt_toggle_fullscreen_anim) == .released) {
        sapp_toggle_fullscreen();
    }
    igSetCursorPos(trxy(ImVec2{ .x = (1920.0 - 300.0), .y = g_app_data.internal_render_size.y - 35.0 }));
    if (animatedButton("toggle editor", trxy(ImVec2{ .x = 100, .y = 20 }), &bt_toggle_ed_anim) == .released) {
        ed_anim.visible = !ed_anim.visible;
    }
}
fn trx(x: f32) f32 {
    return x * g_app_data.internal_render_size.x / g_app_data.content_window_size.x;
}

fn trxy(pos: ImVec2) ImVec2 {
    return ImVec2{ .x = pos.x * g_app_data.content_window_size.x / g_app_data.internal_render_size.x, .y = pos.y * g_app_data.content_window_size.y / g_app_data.internal_render_size.y };
}

// scale and fit coordinate in internal render coordinate system,
fn trxyIntoSlideArea(pos: ImVec2) ImVec2 {
    var ret = ImVec2{};
    var new_content_window_size = g_app_data.content_window_size;
    new_content_window_size.x -= (g_app_data.internal_render_size.x - g_app_data.slide_render_width) / g_app_data.internal_render_size.x * g_app_data.content_window_size.x;

    ret.x = pos.x * new_content_window_size.x / g_app_data.internal_render_size.x;
    // aspect ratio
    var max_content_window_y = new_content_window_size.x * g_app_data.internal_render_size.y / g_app_data.internal_render_size.x;
    ret.y = pos.y * new_content_window_size.y / g_app_data.internal_render_size.y;
    if (ret.y > max_content_window_y) {
        ret.y = max_content_window_y;
    }

    // offset y by height of the cinema bar
    var max_y_translated = g_app_data.internal_render_size.y * new_content_window_size.y / g_app_data.internal_render_size.y;
    var offset_y = (new_content_window_size.y - max_y_translated) / 2.0;

    ret.y += offset_y;

    return ret;
}

fn slideAreaTL() ImVec2 {
    var new_content_window_size = g_app_data.content_window_size;
    new_content_window_size.x -= (g_app_data.internal_render_size.x - g_app_data.slide_render_width) / g_app_data.internal_render_size.x * g_app_data.slide_render_width;
    var screen_size = new_content_window_size;
    var internal_size = g_app_data.internal_render_size;
    var render_size = ImVec2{ .x = screen_size.x, .y = screen_size.x * internal_size.y / internal_size.x };
    var screen_pos = ImVec2{ .x = 0, .y = (screen_size.y - render_size.y) / 2 };
    return screen_pos;
}

// render an image into the slide
fn slideImg(pos: ImVec2, size: ImVec2, texture: *Texture, tint_color: ImVec4, border_color: ImVec4) void {
    var uv_min = ImVec2{ .x = 0.0, .y = 0.0 }; // Top-let
    var uv_max = ImVec2{ .x = 1.0, .y = 1.0 }; // Lower-right

    // position the img
    igSetCursorPos(pos);

    var imgsize_translated = trxyIntoSlideArea(size);

    igImage(texture.imTextureID(), imgsize_translated, uv_min, uv_max, tint_color, border_color);
}

fn showMainMenu(app_data: *AppData) void {
    // we don't want the button size to be scaled shittily. Hence we look for the nearest (lower bound) font size.
    my_fonts.pushFontScaled(my_fonts.getNearestFontSize(32));
    var line_height = app_data.content_window_size.y / 7;

    var bt_width = app_data.content_window_size.x / 3;
    var bt_size = ImVec2{ .x = bt_width, .y = line_height };

    if (bt_size.y > 200.0) {
        bt_size.y = 200;
    }

    {
        igSetCursorPos(ImVec2{ .x = bt_width, .y = line_height });
        if (animatedButton("Load Slides...", bt_size, &bt_anim_1) == .released) {
            std.log.info("clicked!", .{});
            g_app_data.app_state = .presenting;
        }

        igSetCursorPos(ImVec2{ .x = bt_width, .y = 3 * line_height });
        if (animatedButton("Help", bt_size, &bt_anim_2) == .released) {
            std.log.info("clicked!", .{});
        }

        igSetCursorPos(ImVec2{ .x = bt_width, .y = 5 * line_height });
        if (animatedButton("Exit", bt_size, &bt_anim_3) == .released) {
            std.process.exit(0);
        }
    }
    my_fonts.popFontScaled();
}
