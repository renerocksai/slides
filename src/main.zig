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

fn init() void {
    my_fonts.loadFonts() catch unreachable;
    // upaya.colors.setTintColor(upaya.colors.rgbaToVec4(0xcd, 0x0f, 0x00, 0xff));
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
    std.log.info("new global_scale: {}, new relative scale: {}", .{ global_scale * new_relative_scale, new_relative_scale });
    global_scale = new_scale;
}

// .
// Main Update Frame Loop
// .

var bt_state_1 = ButtonAnim{};
var bt_state_2 = ButtonAnim{};
var bt_state_3 = ButtonAnim{};

const AppState = enum {
    mainmenu,
    presenting,
    slide_overview,
};

const AppData = struct {
    app_state: AppState = .mainmenu,
    content_window_size: ImVec2 = ImVec2{},
};

var g_app_data = AppData{};

// update will be called at every swap interval. with swap_interval = 1 above, we'll get 60 fps
fn update() void {
    // replace the default font
    my_fonts.pushFontScaled(14);
    igGetWindowContentRegionMax(&g_app_data.content_window_size);

    var flags: c_int = 0;
    flags = ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoDocking | ImGuiWindowFlags_AlwaysVerticalScrollbar | ImGuiWindowFlags_AlwaysHorizontalScrollbar | ImGuiWindowFlags_NoTitleBar;
    flags = ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoDocking | ImGuiWindowFlags_NoTitleBar;
    if (igBegin("hello", null, flags)) {
        // make the "window" fill the whole available area
        igSetWindowPosStr("hello", .{ .x = 0, .y = 0 }, ImGuiCond_Always);
        igSetWindowSizeStr("hello", g_app_data.content_window_size, ImGuiCond_Always);

        switch (g_app_data.app_state) {
            .mainmenu => showMainMenu(&g_app_data),
            else => {
                var b: bool = true;
                igShowMetricsWindow(&b);
            },
        }
        // pop the default font
        my_fonts.popFontScaled();
    }
}

fn showMainMenu(app_data: *AppData) void {
    // we don't want the button size to be scaled shittily. Hence we look for the nearest (lower bound) font size.
    my_fonts.pushFontScaled(my_fonts.getNearestFontSize(32));
    var line_height = app_data.content_window_size.y / 7;
    var bt_width = app_data.content_window_size.x / 3;
    var bt_size = ImVec2{ .x = bt_width, .y = line_height };

    {
        igSetCursorPos(ImVec2{ .x = bt_width, .y = line_height });
        if (animatedButton("Load Presentation", bt_size, &bt_state_1) == .released) {
            std.log.info("clicked!", .{});
        }

        igSetCursorPos(ImVec2{ .x = bt_width, .y = 3 * line_height });
        if (animatedButton("Present", bt_size, &bt_state_2) == .released) {
            std.log.info("clicked!", .{});
        }

        igSetCursorPos(ImVec2{ .x = bt_width, .y = 5 * line_height });
        if (animatedButton("Exit", bt_size, &bt_state_3) == .released) {
            std.process.exit(0);
        }
    }
    my_fonts.popFontScaled();
    igEnd();
}
