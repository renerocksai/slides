const upaya = @import("upaya");
const sokol = @import("sokol");
const Texture = upaya.Texture;
const std = @import("std");
const uianim = @import("uianim.zig");
const tcache = @import("texturecache.zig");
const slides = @import("slides.zig");
const parser = @import("parser.zig");

const DEBUG = false;

usingnamespace upaya.imgui;
usingnamespace sokol;
usingnamespace uianim;
usingnamespace slides;

const my_fonts = @import("myscalingfonts.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = &arena.allocator;
    defer arena.deinit();

    try G.init(allocator);

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

fn init() void {
    my_fonts.loadFonts() catch unreachable;
    if (std.builtin.os.tag == .windows) {
        std.log.info("on windows", .{});
    } else {
        std.log.info("on {}", .{std.builtin.os.tag});
    }

    initEditorContent() catch |err| {
        std.log.err("Not enough memory for editor!", .{});
    };
}

fn initEditorContent() !void {
    G.editor_memory = try G.allocator.alloc(u8, ed_anim.textbuf_size);
    ed_anim.textbuf = G.editor_memory.ptr;
    std.mem.set(u8, G.editor_memory, 0);

    ed_anim.textbuf[0] = 0;

    // dummy slides
    //makeDemoSlides(&G.slideshow.slides, G.allocator);
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
    allocator: *std.mem.Allocator = undefined,
    app_state: AppState = .mainmenu,
    editor_memory: []u8 = undefined,
    content_window_size: ImVec2 = ImVec2{},
    internal_render_size: ImVec2 = ImVec2{ .x = 1920.0, .y = 1080.0 },
    slide_render_width: f32 = 1920.0,
    slide_render_height: f32 = 1080.0,
    img_tint_col: ImVec4 = ImVec4{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, // No tint
    img_border_col: ImVec4 = ImVec4{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.5 }, // 50% opaque black
    slideshow_filp: ?[]const u8 = undefined,
    status_msg: [*c]const u8 = "",
    slideshow: *SlideShow = undefined,
    current_slide: i32 = 0,
    fn init(self: *AppData, alloc: *std.mem.Allocator) !void {
        self.allocator = alloc;
        self.slideshow = try SlideShow.new(alloc);
    }
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
            .presenting => {
                handleKeyboard();
                if (G.slideshow.slides.items.len > 0) {
                    if (G.current_slide > G.slideshow.slides.items.len) {
                        G.current_slide = @intCast(i32, G.slideshow.slides.items.len - 1);
                    }
                    showSlide(G.slideshow.slides.items[@intCast(usize, G.current_slide)]) catch |err| {
                        std.log.err("SlideShow Error: {any}", .{err});
                    };
                } else {
                    anim_bottom_panel.visible = true;
                    if (makeDefaultSlideshow()) |_| {
                        showSlide(G.slideshow.slides.items[0]) catch |err| {
                            std.log.err("SlideShow Error: {any}", .{err});
                        };
                    } else |err| {
                        std.log.err("SlideShow Error: {any}", .{err});
                    }
                }
            },
            else => {
                var b: bool = true;
                igShowMetricsWindow(&b);
            },
        }
        igEnd();
    }
}

fn makeDefaultSlideshow() !void {
    var empty: *Slide = undefined;
    empty = try Slide.new(G.allocator);
    // make a red background
    var bg = SlideItem{ .kind = .background, .color = .{ .x = 0.5, .y = 0.5, .z = 0.5, .w = 0.9 } };
    try empty.items.append(bg);
    try G.slideshow.slides.append(empty);
    std.log.debug("created empty slideshow", .{});
}

fn jumpToSlide(slidenumber: i32) void {
    if (G.current_slide == slidenumber) {
        return;
    }
    G.current_slide = slidenumber;
    const pos_in_editor = G.slideshow.slides.items[@intCast(usize, slidenumber)].pos_in_editor;
    if (ed_anim.visible) {
        ed_anim.jumpToPosAndHighlightLine(pos_in_editor, false);
    }
}

fn handleKeyboard() void {
    // don't consume keys while the editor is visible
    if (igGetActiveID() == igGetIDStr("editor")) {
        return;
    }
    var deltaindex: i32 = 0;
    if (igIsKeyReleased(' ')) {
        deltaindex = 1;
    }

    if (igIsKeyReleased(SAPP_KEYCODE_LEFT)) {
        deltaindex = -1;
    }

    if (igIsKeyReleased(SAPP_KEYCODE_RIGHT)) {
        deltaindex = 1;
    }

    if (igIsKeyReleased(SAPP_KEYCODE_PAGE_UP)) {
        deltaindex = -1;
    }

    if (igIsKeyReleased(SAPP_KEYCODE_PAGE_DOWN)) {
        deltaindex = 1;
    }
    if (igIsKeyReleased(SAPP_KEYCODE_UP)) {
        ed_anim.grow();
    }

    if (igIsKeyReleased(SAPP_KEYCODE_DOWN)) {
        ed_anim.shrink();
    }

    if (igIsKeyReleased(SAPP_KEYCODE_F)) {
        sapp_toggle_fullscreen();
    }

    if (igIsKeyReleased(SAPP_KEYCODE_M)) {
        if (igIsKeyDown(SAPP_KEYCODE_LEFT_SHIFT) or igIsKeyDown(SAPP_KEYCODE_RIGHT_SHIFT)) {
            G.app_state = .mainmenu;
        } else {
            anim_bottom_panel.visible = !anim_bottom_panel.visible;
        }
    }

    var new_slide_index: i32 = G.current_slide + deltaindex;

    // special slide navigation: 1 and 0
    // needs to be after applying deltaindex!!!!!
    if (igIsKeyReleased(SAPP_KEYCODE_1)) {
        new_slide_index = 0;
    }

    if (igIsKeyReleased(SAPP_KEYCODE_0)) {
        new_slide_index = @intCast(i32, G.slideshow.slides.items.len - 1);
    }

    // clamp slide index
    if (G.slideshow.slides.items.len > 0 and new_slide_index >= @intCast(i32, G.slideshow.slides.items.len)) {
        new_slide_index = @intCast(i32, G.slideshow.slides.items.len - 1);
    } else if (G.slideshow.slides.items.len == 0 and G.current_slide > 0) {
        new_slide_index = 0;
    }
    if (new_slide_index < 0) {
        new_slide_index = 0;
    }

    jumpToSlide(new_slide_index);
}

fn showSlide(slide: *const Slide) !void {
    // optionally show editor
    my_fonts.pushFontScaled(16);

    ed_anim.desired_size.y = G.content_window_size.y - 37;
    if (anim_bottom_panel.visible == false) {
        ed_anim.desired_size.y += 20.0;
    }
    const editor_active = try animatedEditor(&ed_anim, G.content_window_size, G.internal_render_size);
    if (!editor_active) {
        if (igIsKeyPressed(SAPP_KEYCODE_E, false)) {
            toggleEditor();
        }
    }

    my_fonts.popFontScaled();

    // render slide
    G.slide_render_width = G.internal_render_size.x - ed_anim.current_size.x;

    if (slide.items.items.len > 0) {
        for (slide.items.items) |item, i| {
            switch (item.kind) {
                .background => {
                    if (item.img_path) |p| {
                        var texptr = tcache.getImg(p, G.slideshow_filp) catch |err| null;
                        if (texptr) |t| {
                            slideImg(ImVec2{}, G.internal_render_size, t, G.img_tint_col, G.img_border_col);
                        }
                    } else {
                        if (item.color) |color| {
                            setSlideBgColor(color);
                        }
                    }
                },
                .textbox => {
                    if (item.text) |t| {
                        var pos = item.position;
                        pos.x += item.size.x;
                        igPushTextWrapPos(trxyToSlideXY(pos).x);
                        igSetCursorPos(trxyToSlideXY(item.position));
                        const fs = item.fontSize orelse slide.fontsize;
                        const fsize = @floatToInt(i32, @intToFloat(f32, fs) * slideSizeInWindow().y / G.internal_render_size.y);
                        my_fonts.pushFontScaled(fsize);
                        const col = item.color orelse slide.text_color;
                        igPushStyleColorVec4(ImGuiCol_Text, col);
                        igText(sliceToCforImguiText(t)); // TODO: store item texts as [*:0] -- see ParserErrorContext.getFormattedStr for inspiration
                        my_fonts.popFontScaled();
                        igPopStyleColor(1);
                        igPopTextWrapPos();
                    }
                },
                .img => {
                    if (item.img_path) |p| {
                        var texptr = tcache.getImg(p, G.slideshow_filp) catch |err| null;
                        if (texptr) |t| {
                            slideImg(item.position, item.size, t, G.img_tint_col, G.img_border_col);
                        }
                    } else {
                        std.log.err("No img path!?!?!?", .{});
                    }
                },
            }
        }
    }

    // .
    // button row
    // .
    showBottomPanel();

    showStatusMsgV(G.status_msg);
}

fn setSlideBgColor(color: ImVec4) void {
    igSetCursorPos(trxyToSlideXY(ImVec2{}));
    var drawlist = igGetForegroundDrawListNil();
    if (drawlist == null) {
        std.log.warn("drawlist is null!", .{});
    } else {
        const tl = slideAreaTL();
        var br = tl;
        const rsize = scaleToSlide(G.internal_render_size);
        br.x = tl.x + rsize.x;
        br.y = tl.y + rsize.y;
        const bgcol = igGetColorU32Vec4(color);
        igRenderFrame(slideAreaTL(), br, bgcol, true, 0.0);
    }
}

const bottomPanelAnim = struct { visible: bool = false };

fn toggleEditor() void {
    ed_anim.visible = !ed_anim.visible;
    if (ed_anim.visible) {
        ed_anim.startFlashAnimation();
    }
}

fn showBottomPanel() void {
    my_fonts.pushFontScaled(16);
    igSetCursorPos(ImVec2{ .x = 0, .y = G.content_window_size.y - 30 });
    if (anim_bottom_panel.visible) {
        igColumns(6, null, false);
        bt_toggle_bottom_panel_anim.arrow_dir = 0;
        if (animatedButton("a", ImVec2{ .x = 20, .y = 20 }, &bt_toggle_bottom_panel_anim) == .released) {
            anim_bottom_panel.visible = false;
        }
        igNextColumn();
        if (animatedButton("[m]ain menu", ImVec2{ .x = igGetColumnWidth(0), .y = 22 }, &bt_backtomenu_anim) == .released) {
            G.app_state = .mainmenu;
        }
        igNextColumn();
        if (animatedButton("[f]ullscreen", ImVec2{ .x = igGetColumnWidth(1), .y = 22 }, &bt_toggle_fullscreen_anim) == .released) {
            sapp_toggle_fullscreen();
        }
        igNextColumn();
        if (animatedButton("[o]verview", ImVec2{ .x = igGetColumnWidth(1), .y = 22 }, &bt_overview_anim) == .released) {
            setStatusMsg("Not implemented!");
        }
        igNextColumn();
        if (animatedButton("[e]ditor", ImVec2{ .x = igGetColumnWidth(2), .y = 22 }, &bt_toggle_ed_anim) == .released) {
            toggleEditor();
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
        if (animatedButton("a", ImVec2{ .x = 20, .y = 20 }, &bt_toggle_bottom_panel_anim) == .released) {
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
        setStatusMsg("Save as -> not implemented!");
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
fn slideImg(pos: ImVec2, size: ImVec2, texture: *Texture, tint_color: ImVec4, border_color: ImVec4) void {
    var uv_min = ImVec2{ .x = 0.0, .y = 0.0 }; // Top-let
    var uv_max = ImVec2{ .x = 1.0, .y = 1.0 }; // Lower-right

    // position the img in the slide
    igSetCursorPos(trxyToSlideXY(pos));

    var imgsize_translated = scaleToSlide(size);

    igImage(texture.*.imTextureID(), imgsize_translated, uv_min, uv_max, tint_color, border_color);
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
        if (animatedButton("[L]oad ...", bt_size, &bt_anim_1) == .released or igIsKeyReleased(SAPP_KEYCODE_L)) {
            // file dialog
            var selected_file: []const u8 = undefined;
            if (!DEBUG) {
                var buf: [2048]u8 = undefined;
                const my_path: []u8 = std.os.getcwd(buf[0..]) catch |err| "";
                buf[my_path.len] = 0;
                const x = buf[0 .. my_path.len + 1];
                const y = x[0..my_path.len :0];
                const sel = upaya.filebrowser.openFileDialog("Open Slideshow", y, "*.sld");
                if (sel == null) {
                    selected_file = "canceled";
                } else {
                    selected_file = std.mem.span(sel);
                }
            } else {
                var cwdbuf: [2048]u8 = undefined;
                const cwd: []u8 = std.os.getcwd(cwdbuf[0..]) catch |err| "";

                selected_file = std.fmt.bufPrint(&cwdbuf, "{s}{c}{s}", .{ cwd, std.fs.path.sep, "test.sld" }) catch unreachable;
            }

            if (std.mem.startsWith(u8, selected_file, "canceled")) {
                setStatusMsg("canceled");
            } else {
                // now load the file
                loadSlideshow(selected_file) catch |err| {
                    std.log.err("loadSlideshow: {any}", .{err});
                };
            }
        }

        igSetCursorPos(ImVec2{ .x = bt_width, .y = 3 * line_height });
        // New or present - depends on whether we have stuff loaded or not
        var lbl: [*:0]const u8 = undefined;
        if (G.slideshow_filp) |_| {
            lbl = "[P]resent!";
        } else {
            lbl = "New [P]resentation";
        }

        if (animatedButton(lbl, bt_size, &bt_anim_2) == .released or igIsKeyReleased(SAPP_KEYCODE_P)) {
            G.app_state = .presenting;
            const input = std.fs.path.basename(G.slideshow_filp orelse "empty.sld");
            setStatusMsg(sliceToC(input));
        }

        igSetCursorPos(ImVec2{ .x = bt_width, .y = 5 * line_height });
        if (animatedButton("[Q]uit", bt_size, &bt_anim_3) == .released or igIsKeyReleased(SAPP_KEYCODE_Q)) {
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
fn loadSlideshow(filp: []const u8) !void {
    if (std.fs.openFileAbsolute(filp, .{ .read = true })) |f| {
        G.slideshow_filp = filp;
        defer f.close();
        if (f.read(G.editor_memory)) |howmany| {
            G.app_state = .presenting;
            const input = std.fs.path.basename(filp);
            setStatusMsg(sliceToC(input));

            // TODO: deinit the slides

            // parse the shit
            // TODO: this re-inits the slideshow
            G.init(G.allocator) catch unreachable;
            if (parser.constructSlidesFromBuf(G.editor_memory, G.slideshow, G.allocator)) |pcontext| {
                ed_anim.parser_context = pcontext;
            } else |err| {
                std.log.err("{any}", .{err});
                setStatusMsg("Loading failed!");
            }

            std.log.info("=================================", .{});
            std.log.info("          Load Summary:", .{});
            std.log.info("=================================", .{});
            std.log.info("Constructed {d} slides:", .{G.slideshow.slides.items.len});
            for (G.slideshow.slides.items) |slide, i| {
                std.log.info("================================================", .{});
                std.log.info("   slide {d} pos in editor: {}", .{ i, slide.pos_in_editor });
                std.log.info("   slide {d} has {d} items", .{ i, slide.items.items.len });
                for (slide.items.items) |item| {
                    item.printToLog();
                }
            }
        } else |err| {
            setStatusMsg("Loading failed!");
        }
    } else |err| {
        setStatusMsg("Loading failed!");
    }
}

// TODO: get rid of this!
var bigslicetocbuf: [10240]u8 = undefined;
fn sliceToCforImguiText(input: []const u8) [:0]u8 {
    var input_cut = input;
    if (input.len > bigslicetocbuf.len) {
        input_cut = input[0 .. bigslicetocbuf.len - 1];
    }
    std.mem.copy(u8, bigslicetocbuf[0..], input_cut);
    bigslicetocbuf[input_cut.len] = 0;
    const xx = bigslicetocbuf[0 .. input_cut.len + 1];
    const yy = xx[0..input_cut.len :0];
    return yy;
}
