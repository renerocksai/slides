const upaya = @import("upaya");
const sokol = @import("sokol");
const Texture = upaya.Texture;
const std = @import("std");
const uianim = @import("uianim.zig");
const tcache = @import("texturecache.zig");
const slides = @import("slides.zig");
const parser = @import("parser.zig");
const render = @import("sliderenderer.zig");

const md = @import("markdownlineparser.zig");
usingnamespace md;

usingnamespace upaya.imgui;
usingnamespace sokol;
usingnamespace uianim;
usingnamespace slides;

pub extern "c" fn sched_getaffinity(pid: c_int, size: usize, set: *cpu_set_t) c_int;

const my_fonts = @import("myscalingfonts.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = &arena.allocator;
    defer arena.deinit();

    try G.init(allocator);
    defer G.deinit();

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
    G.loaded_content = try G.allocator.alloc(u8, ed_anim.textbuf_size);
    ed_anim.textbuf = G.editor_memory.ptr;
    std.mem.set(u8, G.editor_memory, 0);
    std.mem.set(u8, G.loaded_content, 0);
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
    slideshow_arena: std.heap.ArenaAllocator = undefined,
    slideshow_allocator: *std.mem.Allocator = undefined,
    app_state: AppState = .mainmenu,
    editor_memory: []u8 = undefined,
    loaded_content: []u8 = undefined, // we will check for dirty editor against this
    last_window_size: ImVec2 = .{},
    content_window_size: ImVec2 = .{},
    internal_render_size: ImVec2 = .{ .x = 1920.0, .y = 1080.0 },
    slide_render_width: f32 = 1920.0,
    slide_render_height: f32 = 1080.0,
    slide_renderer: *render.SlideshowRenderer = undefined,
    img_tint_col: ImVec4 = .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, // No tint
    img_border_col: ImVec4 = .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.5 }, // 50% opaque black
    slideshow_filp: ?[]const u8 = undefined,
    status_msg: [*c]const u8 = "",
    slideshow: *SlideShow = undefined,
    current_slide: i32 = 0,
    hot_reload_ticker: usize = 0,
    hot_reload_interval_ticks: usize = 1500 / 16,
    hot_reload_last_stat: ?std.fs.File.Stat = undefined,
    show_saveas: bool = true,
    show_saveas_reason: SaveAsReason = .none,

    fn init(self: *AppData, alloc: *std.mem.Allocator) !void {
        self.allocator = alloc;

        self.slideshow_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.slideshow_allocator = &self.slideshow_arena.allocator;
        self.slideshow = try SlideShow.new(self.slideshow_allocator);
        self.slide_renderer = try render.SlideshowRenderer.new(self.slideshow_allocator);
    }

    fn deinit(self: *AppData) void {
        self.slideshow_arena.deinit();
    }

    fn reinit(self: *AppData) !void {
        self.slideshow_arena.deinit();
        self.slideshow_filp = null;
        try self.init(self.allocator);
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

const LaserpointerAnim = struct {
    frame_ticker: usize = 0,
    anim_ticker: f32 = 0,
    show_laserpointer: bool = false,
    laserpointer_size: f32 = 15,
    laserpointer_zoom: f32 = 1.0,
    alpha_table: [6]f32 = [_]f32{ 0.875, 0.875, 0.85, 0.85, 0.825, 0.825 },
    alpha_index_step: i32 = 1,
    alpha_index: i32 = 0,
    size_jiggle_table: [6]f32 = [_]f32{ 1.5, 1.4, 1.30, 1.2, 1.1, 1.0 },
    size_jiggle_index_step: i32 = 1,
    size_jiggle_index: i32 = 0,

    fn anim(self: *LaserpointerAnim, mousepos: ImVec2) void {
        if (self.show_laserpointer) {
            igSetCursorPos(mousepos);
            sapp_show_mouse(false);
            var drawlist = igGetForegroundDrawListNil();
            const colu32 = igGetColorU32Vec4(ImVec4{ .x = 1, .w = self.alpha_table[@intCast(usize, self.alpha_index)] });
            ImDrawList_AddCircleFilled(drawlist, mousepos, self.laserpointer_size * self.laserpointer_zoom + 10 * self.size_jiggle_table[@intCast(usize, self.size_jiggle_index)], colu32, 256);

            self.frame_ticker += 1;

            if (self.frame_ticker > 6) {
                self.advance_anim();
                self.anim_ticker += 1;
                self.frame_ticker = 0;
            }
        }
    }

    fn advance_anim(self: *LaserpointerAnim) void {
        if (self.alpha_index == self.alpha_table.len - 1) {
            self.alpha_index_step = -1;
        }
        if (self.alpha_index == 0) {
            self.alpha_index_step = 1;
        }
        if (self.size_jiggle_index == self.size_jiggle_table.len - 1) {
            self.size_jiggle_index_step = -1;
        }
        if (self.size_jiggle_index == 0) {
            self.size_jiggle_index_step = 1;
        }
        self.size_jiggle_index += self.size_jiggle_index_step;
        self.alpha_index += self.alpha_index_step;
    }

    fn toggle(self: *LaserpointerAnim) void {
        self.show_laserpointer = !self.show_laserpointer;
        self.frame_ticker = 0;
        self.anim_ticker = 0;
        if (self.show_laserpointer) {
            // mouse cursor manipulation such as hiding and changing shape doesn't do anything
            // igSetMouseCursor(ImGuiMouseCursor_TextInput);
            sapp_show_mouse(false);
            std.log.debug("Hiding mouse", .{});
        } else {
            //igSetMouseCursor(ImGuiMouseCursor_Arrow);
            std.log.debug("Showing mouse", .{});
            sapp_show_mouse(true);
        }
    }
};

var anim_laser = LaserpointerAnim{};

// .
// Main Update Frame Loop
// .

var time_prev: i64 = 0;
var time_now: i64 = 0;

// update will be called at every swap interval. with swap_interval = 1 above, we'll get 60 fps
fn update() void {

    // debug update loop timing
    if (false) {
        time_now = std.time.milliTimestamp();
        const time_delta = time_now - time_prev;
        time_prev = time_now;
        std.log.debug("delta_t: {}", .{time_delta});
    }

    var mousepos: ImVec2 = undefined;
    igGetMousePos(&mousepos);
    igGetWindowContentRegionMax(&G.content_window_size);
    if (G.content_window_size.x != G.last_window_size.x or G.content_window_size.y != G.last_window_size.y) {
        // window size changed
        std.log.debug("win size changed from {} to {}", .{ G.last_window_size, G.content_window_size });
        G.last_window_size = G.content_window_size;
    }

    var flags: c_int = 0;
    flags = ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoDocking | ImGuiWindowFlags_NoTitleBar;
    flags = ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoTitleBar;
    const is_fullscreen = sapp_is_fullscreen();
    if (!is_fullscreen) {
        flags |= ImGuiWindowFlags_MenuBar;
    }
    if (igBegin("main", null, flags)) {
        // make the "window" fill the whole available area
        igSetWindowPosStr("main", .{ .x = 0, .y = 0 }, ImGuiCond_Always);
        igSetWindowSizeStr("main", G.content_window_size, ImGuiCond_Always);

        if (!is_fullscreen) {
            showMenu();
        }

        handleKeyboard();

        const do_reload = checkAutoReload() catch false;
        if (do_reload) {
            loadSlideshow(G.slideshow_filp.?) catch |err| {
                std.log.err("Unable to auto-reload: {any}", .{err});
            };
        }

        if (G.slideshow.slides.items.len > 0) {
            if (G.current_slide > G.slideshow.slides.items.len) {
                G.current_slide = @intCast(i32, G.slideshow.slides.items.len - 1);
            }
            showSlide2(G.current_slide) catch |err| {
                std.log.err("SlideShow Error: {any}", .{err});
            };
        } else {
            if (makeDefaultSlideshow()) |_| {
                G.current_slide = 0;
                showSlide2(G.current_slide) catch |err| {
                    std.log.err("SlideShow Error: {any}", .{err});
                };
            } else |err| {
                std.log.err("SlideShow Error: {any}", .{err});
            }
        }
        igEnd();

        if (G.show_saveas) {
            igOpenPopup("Save slideshow?");
        }

        if (savePopup(G.show_saveas_reason)) {
            G.show_saveas = false;
            G.show_saveas_reason = .none;
        }

        // laser pointeer
        if (mousepos.x > 0 and mousepos.y > 0) {
            anim_laser.anim(mousepos);
        }
    }
}

fn makeDefaultSlideshow() !void {
    var empty: *Slide = undefined;
    empty = try Slide.new(G.slideshow_allocator);
    // make a grey background
    var bg = SlideItem{ .kind = .background, .color = .{ .x = 0.5, .y = 0.5, .z = 0.5, .w = 0.9 } };
    try empty.items.append(bg);
    try G.slideshow.slides.append(empty);
    try G.slide_renderer.preRender(G.slideshow, "");
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
    const ctrl = igIsKeyDown(SAPP_KEYCODE_LEFT_CONTROL) or igIsKeyDown(SAPP_KEYCODE_RIGHT_CONTROL);
    const shift = igIsKeyDown(SAPP_KEYCODE_LEFT_SHIFT) or igIsKeyDown(SAPP_KEYCODE_RIGHT_SHIFT);
    if (igIsKeyReleased(SAPP_KEYCODE_Q) and ctrl) {
        cmdQuit();
        return;
    }
    if (igIsKeyReleased(SAPP_KEYCODE_O) and ctrl) {
        cmdLoadSlideshow();
        return;
    }
    if (igIsKeyReleased(SAPP_KEYCODE_N) and ctrl) {
        cmdNewSlideshow();
        return;
    }
    if (igIsKeyReleased(SAPP_KEYCODE_S) and ctrl) {
        cmdSave();
        return;
    }
    if (igIsKeyReleased(SAPP_KEYCODE_L) and ctrl and !shift) {
        anim_laser.toggle();
        return;
    }
    if (igIsKeyReleased(SAPP_KEYCODE_L) and ctrl and shift) {
        anim_laser.laserpointer_zoom *= 1.5;
        if (anim_laser.laserpointer_zoom > 10) {
            anim_laser.laserpointer_zoom = 1.0;
        }
        return;
    }
    // don't consume keys while the editor is visible
    if ((igGetActiveID() == igGetIDStr("editor")) or ed_anim.search_ed_active or ed_anim.search_ed_active or (igGetActiveID() == igGetIDStr("##search"))) {
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

    if (igIsKeyReleased(SAPP_KEYCODE_BACKSPACE)) {
        deltaindex = -1;
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
        cmdToggleFullscreen();
    }

    if (igIsKeyReleased(SAPP_KEYCODE_M)) {
        if (igIsKeyDown(SAPP_KEYCODE_LEFT_SHIFT) or igIsKeyDown(SAPP_KEYCODE_RIGHT_SHIFT)) {
            G.app_state = .mainmenu;
        } else {
            cmdToggleBottomPanel();
        }
    }

    var new_slide_index: i32 = G.current_slide + deltaindex;

    // special slide navigation: 1 and 0
    // needs to happen after applying deltaindex!!!!!
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

fn showSlide2(slide_number: i32) !void {
    // optionally show editor
    my_fonts.pushFontScaled(16);

    var start_y: f32 = 22;
    if (sapp_is_fullscreen()) {
        start_y = 0;
    }
    ed_anim.desired_size.y = G.content_window_size.y - 37 - start_y;
    if (!anim_bottom_panel.visible) {
        ed_anim.desired_size.y += 20.0;
    }
    const editor_active = try animatedEditor(&ed_anim, start_y, G.content_window_size, G.internal_render_size);
    if (!editor_active and !ed_anim.search_ed_active) {
        if (igIsKeyPressed(SAPP_KEYCODE_E, false)) {
            cmdToggleEditor();
        }
    }

    my_fonts.popFontScaled();

    // render slide
    G.slide_render_width = G.internal_render_size.x - ed_anim.current_size.x;
    try G.slide_renderer.render(slide_number, slideAreaTL(), slideSizeInWindow(), G.internal_render_size);

    // .
    // button row
    // .
    showBottomPanel();

    showStatusMsgV(G.status_msg);
}

const bottomPanelAnim = struct { visible: bool = false, visible_before_editor: bool = false };

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
        igNextColumn();
        // TODO: using the button can cause crashes, whereas the shortcut and menu don't -- what's going on here?
        //       when button is removed, we also saw it with the shortcut
        if (animatedButton("[f]ullscreen", ImVec2{ .x = igGetColumnWidth(1), .y = 22 }, &bt_toggle_fullscreen_anim) == .released) {
            cmdToggleFullscreen();
        }
        igNextColumn();
        if (animatedButton("[o]verview", ImVec2{ .x = igGetColumnWidth(1), .y = 22 }, &bt_overview_anim) == .released) {
            setStatusMsg("Not implemented!");
        }
        igNextColumn();
        if (animatedButton("[e]ditor", ImVec2{ .x = igGetColumnWidth(2), .y = 22 }, &bt_toggle_ed_anim) == .released) {
            cmdToggleEditor();
        }
        igNextColumn();
        if (ed_anim.visible) {
            if (animatedButton("save", ImVec2{ .x = igGetColumnWidth(2), .y = 22 }, &bt_save_anim) == .released) {
                cmdSave();
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

fn checkAutoReload() !bool {
    if (G.slideshow_filp) |filp| {
        G.hot_reload_ticker += 1;
        if (filp.len > 0) {
            if (G.hot_reload_ticker > G.hot_reload_interval_ticks) {
                std.log.debug("Checking for auto-reload of `{s}`", .{filp});
                G.hot_reload_ticker = 0;
                var f = try std.fs.openFileAbsolute(filp, .{ .read = true });
                defer f.close();
                const x = try f.stat();
                if (G.hot_reload_last_stat) |last| {
                    if (x.mtime != last.mtime) {
                        std.log.debug("RELOAD {s}", .{filp});
                        return true;
                    }
                } else {
                    G.hot_reload_last_stat = x;
                }
            }
        }
    } else {}
    return false;
}

fn loadSlideshow(filp: []const u8) !void {
    if (std.fs.openFileAbsolute(filp, .{ .read = true })) |f| {
        defer f.close();
        G.hot_reload_last_stat = try f.stat();
        if (f.read(G.editor_memory)) |howmany| {
            G.editor_memory[howmany] = 0;
            std.mem.copy(u8, G.loaded_content, G.editor_memory);
            G.app_state = .presenting;
            const input = std.fs.path.basename(filp);
            setStatusMsg(sliceToC(input));

            const new_is_old_name = try std.fmt.allocPrint(G.allocator, "{s}", .{filp});
            // parse the shit
            if (G.reinit()) |_| {
                G.slideshow_filp = new_is_old_name;
                std.log.debug("filp is now {s}", .{G.slideshow_filp});
                if (parser.constructSlidesFromBuf(G.editor_memory, G.slideshow, G.slideshow_allocator)) |pcontext| {
                    ed_anim.parser_context = pcontext;
                } else |err| {
                    std.log.err("{any}", .{err});
                    setStatusMsg("Loading failed!");
                }

                if (false) {
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
                }
                if (G.slide_renderer.preRender(G.slideshow, filp)) |_| {
                    // . empty
                } else |err| {
                    std.log.err("Pre-rendering failed: {any}", .{err});
                }
            } else |err| {
                setStatusMsg("Loading failed!");
                std.log.err("Loading failed: {any}", .{err});
            }
        } else |err| {
            setStatusMsg("Loading failed!");
            std.log.err("Loading failed: {any}", .{err});
        }
    } else |err| {
        setStatusMsg("Loading failed!");
        std.log.err("Loading failed: {any}", .{err});
    }
}

fn isEditorDirty() bool {
    return !std.mem.eql(u8, G.editor_memory, G.loaded_content);
}

// .
// COMMANDS
// .
fn cmdToggleFullscreen() void {
    sapp_toggle_fullscreen();
}

fn cmdToggleEditor() void {
    ed_anim.visible = !ed_anim.visible;
    if (ed_anim.visible) {
        ed_anim.startFlashAnimation();
        anim_bottom_panel.visible_before_editor = anim_bottom_panel.visible;
        anim_bottom_panel.visible = true;
    } else {
        anim_bottom_panel.visible = anim_bottom_panel.visible_before_editor;
    }
}

fn cmdToggleBottomPanel() void {
    anim_bottom_panel.visible = !anim_bottom_panel.visible;
}

fn cmdSave() void {
    if (G.slideshow_filp) |filp| {
        // save the shit
        _ = saveSlideshow(filp, ed_anim.textbuf);
    } else {
        saveSlideshowAs();
    }
    if (G.slideshow_filp) |filp| {
        loadSlideshow(filp) catch unreachable;
    }
}

fn saveSlideshowAs() void {
    // file dialog
    var selected_file: []const u8 = undefined;
    var buf: [2048]u8 = undefined;
    const my_path: []u8 = std.os.getcwd(buf[0..]) catch |err| "";
    buf[my_path.len] = 0;
    const x = buf[0 .. my_path.len + 1];
    const y = x[0..my_path.len :0];
    const sel = upaya.filebrowser.saveFileDialog("Save Slideshow as...", y, "*.sld");
    if (sel == null) {
        selected_file = "canceled";
    } else {
        selected_file = std.mem.span(sel);
    }

    if (std.mem.startsWith(u8, selected_file, "canceled")) {
        setStatusMsg("canceled");
    } else {
        // now load the file
        G.slideshow_filp = selected_file;
        _ = saveSlideshow(selected_file, ed_anim.textbuf);
    }
}

fn cmdSaveAs() void {
    saveSlideshowAs();
}

fn doQuit() void {
    std.process.exit(0);
}

fn doLoadSlideshow() void {
    // file dialog
    var selected_file: []const u8 = undefined;
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

    if (std.mem.startsWith(u8, selected_file, "canceled")) {
        setStatusMsg("canceled");
    } else {
        // now load the file
        loadSlideshow(selected_file) catch |err| {
            std.log.err("loadSlideshow: {any}", .{err});
        };
    }
}

fn doNewSlideshow() void {
    G.reinit() catch |err| {
        std.log.err("Reinit failed: {any}", .{err});
    };
    initEditorContent() catch |err| {
        std.log.err("Reinit editor failed: {any}", .{err});
    };
    std.log.debug("Re-initted", .{});
}

fn doNewFromTemplate() void {
    setStatusMsg("Not implemented!");
}

fn cmdQuit() void {
    if (isEditorDirty()) {
        G.show_saveas_reason = .quit;
        G.show_saveas = true;
    } else {
        doQuit();
    }
}

fn cmdLoadSlideshow() void {
    if (isEditorDirty()) {
        G.show_saveas_reason = .load;
        G.show_saveas = true;
    } else {
        doLoadSlideshow();
    }
}

fn cmdNewSlideshow() void {
    if (isEditorDirty()) {
        G.show_saveas_reason = .new;
        G.show_saveas = true;
    } else {
        doNewSlideshow();
    }
}

fn cmdNewFromTemplate() void {
    if (isEditorDirty()) {
        G.show_saveas_reason = .newtemplate;
        G.show_saveas = true;
    } else {
        doNewFromTemplate();
    }
}

const SaveAsReason = enum {
    none,
    quit,
    load,
    new,
    newtemplate,
};

fn savePopup(reason: SaveAsReason) bool {
    if (reason == .none) {
        return true;
    }
    igSetNextWindowSize(.{ .x = 500, .y = -1 }, ImGuiCond_Always);
    var open: bool = true;
    my_fonts.pushFontScaled(14);
    defer my_fonts.popFontScaled();
    var doit = false;
    if (igBeginPopupModal("Save slideshow?", &open, ImGuiWindowFlags_AlwaysAutoResize)) {
        defer igEndPopup();

        igText("The slideshow has unsaved changes.\nSave it?");
        igColumns(2, "id-x", true);

        var no = igButton("No", .{ .x = -1, .y = 30 });
        igNextColumn();
        var yes = igButton("YES", .{ .x = -1, .y = 30 });
        doit = yes or no;
        if (doit) {
            if (yes) {
                cmdSave();
            }
            switch (reason) {
                .quit => {
                    doQuit();
                },
                .load => {
                    doLoadSlideshow();
                },
                .new => {
                    doNewSlideshow();
                },
                .newtemplate => {
                    doNewFromTemplate();
                },
                .none => {},
            }
        }
    }
    return doit;
}

// .
// .
// MENU
// .
// .

fn showMenu() void {
    my_fonts.pushFontScaled(14);
    if (igBeginMenuBar()) {
        defer igEndMenuBar();

        if (igBeginMenu("File", true)) {
            if (igMenuItemBool("New", "Ctrl + N", false, true)) {
                cmdNewSlideshow();
            }
            // if (igMenuItemBool("New from template...", "", false, true)) {
            //     cmdNewFromTemplate();
            // }
            if (igMenuItemBool("Open...", "Ctrl + O", false, true)) {
                cmdLoadSlideshow();
            }
            if (igMenuItemBool("Save", "Ctrl + S", false, isEditorDirty())) {
                cmdSave();
            }
            if (igMenuItemBool("Save as...", "", false, true)) {
                cmdSaveAs();
            }
            if (igMenuItemBool("Quit", "Ctrl + Q", false, true)) {
                cmdQuit();
            }
            igEndMenu();
        }
        if (igBeginMenu("View", true)) {
            if (igMenuItemBool("Toggle editor", "E", false, true)) {
                cmdToggleEditor();
            }
            if (igMenuItemBool("Toggle full-screen", "F", false, true)) {
                cmdToggleFullscreen();
            }
            if (igMenuItemBool("Overview", "O", false, true)) {}
            if (igMenuItemBool("Toggle Laserpointer", "Ctrl + L", false, true)) {
                anim_laser.toggle();
            }
            if (igMenuItemBool("Toggle on-screen menu buttons", "M", false, true)) {
                cmdToggleBottomPanel();
            }
            igEndMenu();
        }
        if (igBeginMenu("Help", true)) {
            if (igMenuItemBool("About", "", false, true)) {
                setStatusMsg("Not implemented!");
            }
            igEndMenu();
        }
    }
    my_fonts.popFontScaled();
}
