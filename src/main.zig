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
        .width = 1200,
        .height = 800,
    });
}

var tex: ?upaya.Texture = null;

fn assetPrefix() [*:0]const u8 {
    if (std.builtin.os.tag == .windows) {
        return "C:\\Projekte\\github\\renerocksai\\slides\\assets\\";
    } else {
        return "./assets/";
    }
}
fn init() void {
    my_fonts.loadFonts() catch unreachable;
    // upaya.colors.setTintColor(upaya.colors.rgbaToVec4(0xcd, 0x0f, 0x00, 0xff));
    if (tex == null)
        tex = upaya.Texture.initFromFile(assetPrefix() ++ "nim/1.png", .nearest) catch |err| {
            std.log.err("Error: png could not be loaded", .{});
            return;
        };
    if (std.builtin.os.tag == .windows) {
        std.log.info("on windows", .{});
    } else {
        std.log.info("on {}", .{std.builtin.os.tag});
    }

    // dummy fill editor with content
    initEditorContent() catch |err| {
        std.log.err("Not enough memory for editor!", .{});
    };
}

fn initEditorContent() !void {
    var allocator = std.heap.page_allocator;
    G.editor_memory = try allocator.alloc(u8, ed_anim.textbuf_size);
    ed_anim.textbuf = G.editor_memory.ptr;
    std.mem.set(u8, G.editor_memory, 0);

    // set to dummy content
    var data = @embedFile("test.sld");
    G.slideshow_filp = "test.sld";
    const l = data.len;
    @memcpy(ed_anim.textbuf, data, l);
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
    editor_memory: []u8 = undefined,
    content_window_size: ImVec2 = ImVec2{},
    internal_render_size: ImVec2 = ImVec2{ .x = 1920.0, .y = 1080.0 },
    slide_render_width: f32 = 1920.0,
    img_tint_col: ImVec4 = ImVec4{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, // No tint
    img_border_col: ImVec4 = ImVec4{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.5 }, // 50% opaque black
    slideshow_filp: ?[]const u8 = null,
    status_msg: [*c]const u8 = "",
};

var G = AppData{};

// .
// Animation
// .
var bt_anim_1 = ButtonAnim{};
var bt_anim_2 = ButtonAnim{};
var bt_anim_3 = ButtonAnim{};

var ed_anim = EditAnim{};
var bt_toggle_ed_anim = ButtonAnim{};
var bt_overview_anim = ButtonAnim{};
var bt_toggle_fullscreen_anim = ButtonAnim{};
var bt_backtomenu_anim = ButtonAnim{};
var bt_toggle_bottom_panel_anim = ButtonAnim{};
var bt_save_anim = ButtonAnim{};
var anim_bottom_panel = bottomPanelAnim{};
var anim_status_msg = MsgAnim{};

// .
// Main Update Frame Loop
// .

// update will be called at every swap interval. with swap_interval = 1 above, we'll get 60 fps
fn update() void {
    igGetWindowContentRegionMax(&G.content_window_size);

    var flags: c_int = 0;
    flags = ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoDocking | ImGuiWindowFlags_NoTitleBar;
    if (igBegin("main", null, flags)) {
        // make the "window" fill the whole available area
        igSetWindowPosStr("main", .{ .x = 0, .y = 0 }, ImGuiCond_Always);
        igSetWindowSizeStr("main", G.content_window_size, ImGuiCond_Always);

        switch (G.app_state) {
            .mainmenu => showMainMenu(&G),
            .presenting => showSlide() catch unreachable,
            else => {
                var b: bool = true;
                igShowMetricsWindow(&b);
            },
        }
        igEnd();
    }
}

fn showSlide() !void {
    // optionally show editor
    igSetCursorPos(trxy(ImVec2{ .x = G.internal_render_size.x - ed_anim.current_size.x, .y = 0.0 }));
    my_fonts.pushFontScaled(16);
    var editor_size = ImVec2{ .x = 600.0, .y = G.content_window_size.y - 37 };
    if (anim_bottom_panel.visible == false) {
        editor_size.y += 20.0;
    }
    _ = try animatedEditor(&ed_anim, editor_size, G.content_window_size, G.internal_render_size);
    my_fonts.popFontScaled();

    // render slide
    G.slide_render_width = G.internal_render_size.x - ed_anim.current_size.x;

    // background color or background image
    tex = null;
    igSetCursorPos(trxyToSlideXY(ImVec2{}));
    var bgcolor = igGetStyleColorVec4(ImGuiCol_Button).*;
    var drawlist = igGetForegroundDrawListNil();
    if (drawlist == null) {
        std.log.info("drawlist is null!", .{});
    } else {
        const tl = slideAreaTL();
        var br = tl;
        const rsize = scaleToSlide(G.internal_render_size);
        br.x = tl.x + rsize.x;
        br.y = tl.y + rsize.y;
        const bgcol = igGetColorU32Vec4(bgcolor);
        ImDrawList_AddRectFilled(drawlist, slideAreaTL(), br, bgcol, 1.0, 0);
        //pub extern fn ImDrawList_AddRectFilled(self: [*c]ImDrawList, p_min: ImVec2, p_max: ImVec2, col: ImU32, rounding: f32, rounding_corners: ImDrawCornerFlags) void;
    }
    if (tex) |texture| {
        slideImg(ImVec2{}, G.internal_render_size, &tex, G.img_tint_col, G.img_border_col);
    } else {
        igSetCursorPos(trxyToSlideXY(ImVec2{}));
        _ = igBeginChildStr("", scaleToSlide(G.internal_render_size), true, 0);
        igEndChild();
    }

    // .
    // button row
    // .
    showBottomPanel();

    showStatusMsgV(G.status_msg);
}

const bottomPanelAnim = struct {
    visible: bool = false
};

fn showBottomPanel() void {
    my_fonts.pushFontScaled(16);
    igSetCursorPos(ImVec2{ .x = 0, .y = G.content_window_size.y - 30 });
    if (anim_bottom_panel.visible) {
        igColumns(6, null, false);
        bt_toggle_bottom_panel_anim.arrow_dir = 0;
        if (animatedButton("<", ImVec2{ .x = 20, .y = 20 }, &bt_toggle_bottom_panel_anim) == .released) {
            anim_bottom_panel.visible = false;
        }
        igNextColumn();
        if (animatedButton("main menu", ImVec2{ .x = igGetColumnWidth(0), .y = 22 }, &bt_backtomenu_anim) == .released) {
            G.app_state = .mainmenu;
        }
        igNextColumn();
        if (animatedButton("fullscreen", ImVec2{ .x = igGetColumnWidth(1), .y = 22 }, &bt_toggle_fullscreen_anim) == .released) {
            sapp_toggle_fullscreen();
        }
        igNextColumn();
        if (animatedButton("overview", ImVec2{ .x = igGetColumnWidth(1), .y = 22 }, &bt_overview_anim) == .released) {
            setStatusMsg("Not implemented!");
        }
        igNextColumn();
        if (animatedButton("editor", ImVec2{ .x = igGetColumnWidth(2), .y = 22 }, &bt_toggle_ed_anim) == .released) {
            ed_anim.visible = !ed_anim.visible;
        }
        // dummy column for the editor save button
        igNextColumn();
        if (ed_anim.visible) {
            if (animatedButton("save", ImVec2{ .x = igGetColumnWidth(2), .y = 22 }, &bt_save_anim) == .released) {
                // save the shit
                _ = saveSlideshow(G.slideshow_filp, ed_anim.textbuf);
            }
        }
        igEndColumns();
    } else {
        igColumns(5, null, false);
        bt_toggle_bottom_panel_anim.arrow_dir = 1;
        if (animatedButton(">", ImVec2{ .x = 20, .y = 20 }, &bt_toggle_bottom_panel_anim) == .released) {
            anim_bottom_panel.visible = true;
        }
        igNextColumn();
        igNextColumn();
        igNextColumn();
        igNextColumn();
        igEndColumns();
    }
    my_fonts.popFontScaled();
}

fn showStatusMsg(msg: [*c]const u8) void {
    const y = G.content_window_size.y - 50 - 64;
    const pos = ImVec2{ .x = 10, .y = y };
    const flyin_pos = ImVec2{ .x = G.content_window_size.x, .y = y };
    const color = ImVec4{ .x = 1, .y = 1, .z = 0x80 / 255.0, .w = 1 };
    my_fonts.pushFontScaled(64);
    showMsg(msg.?, pos, flyin_pos, color, &anim_status_msg);
    my_fonts.popFontScaled();
}

fn setStatusMsg(msg: [*c]const u8) void {
    G.status_msg = msg;
    anim_status_msg.anim_state = .fadein;
    anim_status_msg.ticker_ms = 0;
}

fn saveSlideshow(filp: ?[]const u8, contents: [*c]u8) bool {
    if (filp == null) {
        std.log.err("no filename!", .{});
        return false;
    }
    std.log.debug("saving to: {s} ", .{filp.?});
    const file = std.fs.cwd().createFile(
        filp.?,
        .{},
    ) catch |err| {
        setStatusMsg("ERROR saving slideshow");
        return false;
    };
    defer file.close();

    const contents_slice: []u8 = std.mem.spanZ(contents);
    file.writeAll(contents_slice) catch |err| {
        setStatusMsg("ERROR saving slideshow");
        return false;
    };
    setStatusMsg("Saved!");
    return true;

    // interesting snippet: null-check for c-style pointers expressed via optional slices
    // const prompt = c"> ";
    //
    // fn readline() ?[]const u8 {
    //     if (editline.readline(prompt)) |line| {
    //             return std.mem.toSliceConst(u8, line);
    //     }
    //     return null;
    // }
}

fn trx(x: f32) f32 {
    return x * G.internal_render_size.x / G.content_window_size.x;
}

fn trxy(pos: ImVec2) ImVec2 {
    return ImVec2{ .x = pos.x * G.content_window_size.x / G.internal_render_size.x, .y = pos.y * G.content_window_size.y / G.internal_render_size.y };
}

fn slideSizeInWindow() ImVec2 {
    var ret = ImVec2{};
    var new_content_window_size = G.content_window_size;
    new_content_window_size.x -= (G.internal_render_size.x - G.slide_render_width) / G.internal_render_size.x * G.content_window_size.x;

    ret.x = new_content_window_size.x;

    // aspect ratio
    ret.y = ret.x * G.internal_render_size.y / G.internal_render_size.x;
    if (ret.y > G.content_window_size.y) {
        ret.y = G.content_window_size.y - 1;
        ret.x = ret.y * G.internal_render_size.x / G.internal_render_size.y;
    }
    return ret;
}

fn slideAreaTL() ImVec2 {
    var ss = slideSizeInWindow();
    var ret = ImVec2{};

    ret.y = (G.content_window_size.y - ss.y) / 2.0;
    return ret;
}

// translate pos in internal_render_size coords onto projection of slide in window
fn trxyToSlideXY(pos: ImVec2) ImVec2 {
    var ss = slideSizeInWindow();
    var tl = slideAreaTL();
    var ret = scaleToSlide(pos);
    ret.y += tl.y;
    return ret;
}

fn scaleToSlide(size: ImVec2) ImVec2 {
    var ss = slideSizeInWindow();
    var tl = slideAreaTL();
    var ret = ImVec2{};

    ret.x = size.x * ss.x / G.internal_render_size.x;
    ret.y = size.y * ss.y / G.internal_render_size.y;
    return ret;
}

// render an image into the slide
fn slideImg(pos: ImVec2, size: ImVec2, texture: *?Texture, tint_color: ImVec4, border_color: ImVec4) void {
    var uv_min = ImVec2{ .x = 0.0, .y = 0.0 }; // Top-let
    var uv_max = ImVec2{ .x = 1.0, .y = 1.0 }; // Lower-right

    // position the img in the slide
    igSetCursorPos(trxyToSlideXY(pos));

    var imgsize_translated = scaleToSlide(size);

    if (texture.* != null)
        igImage(texture.*.?.imTextureID(), imgsize_translated, uv_min, uv_max, tint_color, border_color);
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
        if (animatedButton("Load ...", bt_size, &bt_anim_1) == .released) {
            // file dialog
            var buf: [2048]u8 = undefined;
            const my_path: []u8 = std.os.getcwd(buf[0..]) catch |err| "";
            buf[my_path.len] = 0;
            const x = buf[0 .. my_path.len + 1];
            const y = x[0..my_path.len :0];
            const sel = upaya.filebrowser.openFileDialog("Open Slideshow", y, "*.sld");
            if (sel == null) {
                std.log.info("canceled", .{});
                setStatusMsg("canceled");
            } else {
                // TODO: now load the file
                const filepath = std.mem.span(sel);
                if (std.fs.openFileAbsolute(filepath, .{ .read = true })) |f| {
                    defer f.close();
                    if (f.read(G.editor_memory)) |howmany| {
                        G.app_state = .presenting;
                        const input = std.fs.path.basename(filepath);
                        setStatusMsg(sliceToC(input));
                    } else |err| {
                        setStatusMsg("Loading failed!");
                    }
                } else |err| {
                    setStatusMsg("Loading failed!");
                }
            }
        }

        igSetCursorPos(ImVec2{ .x = bt_width, .y = 3 * line_height });
        if (animatedButton("Present!", bt_size, &bt_anim_2) == .released) {
            G.app_state = .presenting;
            const input = std.fs.path.basename(G.slideshow_filp.?);
            setStatusMsg(sliceToC(input));
            //            setStatusMsg("Welcome back!");
        }

        igSetCursorPos(ImVec2{ .x = bt_width, .y = 5 * line_height });
        if (animatedButton("Quit", bt_size, &bt_anim_3) == .released) {
            std.process.exit(0);
        }
    }
    my_fonts.popFontScaled();
    showStatusMsgV(G.status_msg);
}

fn showStatusMsgV(msg: [*c]const u8) void {
    var tsize = ImVec2{};
    my_fonts.pushFontScaled(64);
    igCalcTextSize(&tsize, msg, msg + std.mem.lenZ(msg), false, 2000.0);
    const maxw = G.content_window_size.x * 0.9;
    if (tsize.x > maxw) {
        tsize.x = maxw;
    }

    const x = (G.content_window_size.x - tsize.x) / 2.0;
    const y = G.content_window_size.y / 4;

    const pos = ImVec2{ .x = x, .y = y };
    const flyin_pos = ImVec2{ .x = x, .y = G.content_window_size.y - tsize.y - 8 };
    const color = ImVec4{ .x = 1, .y = 1, .z = 0x80 / 255.0, .w = 1 };
    igPushTextWrapPos(maxw + x);
    showMsg(msg.?, pos, flyin_pos, color, &anim_status_msg);
    igPopTextWrapPos();
    my_fonts.popFontScaled();
}

var slicetocbuf: [1024]u8 = undefined;
fn sliceToC(input: []const u8) [:0]u8 {
    var input_cut = input;
    if (input.len > slicetocbuf.len) {
        input_cut = input[0 .. slicetocbuf.len - 1];
    }
    std.mem.copy(u8, slicetocbuf[0..], input_cut);
    slicetocbuf[input_cut.len] = 0;
    const xx = slicetocbuf[0 .. input_cut.len + 1];
    const yy = xx[0..input_cut.len :0];
    return yy;
}

// .
// Slides
// .
const Slide = struct {
    pos_in_editor: i32,
};

const SlideItemKind = enum {
    background,
    textbox,
    img,
};

const SlideItem = struct {
    text: ?[]u8,
};
