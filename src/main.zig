const std = @import("std");
const uianim = @import("uianim.zig");
const tc = @import("texturecache.zig");
const slides = @import("slides.zig");
const parser = @import("parser.zig");
const render = @import("sliderenderer.zig");
const screenshot = @import("screenshot.zig");
const mdlineparser = @import("markdownlineparser.zig");
const my_fonts = @import("fontbakery.zig");
const fontbakery = my_fonts;
const filedialog = @import("filedialog");
const pptx = @import("pptx.zig");

const zt = @import("zt");
const zg = zt.custom_components;
const imgui = @import("imgui");
const ig = imgui;
const glfw = @import("glfw");

const SlideShow = slides.SlideShow;
const Slide = slides.Slide;
const SlideItem = slides.SlideItem;
const ButtonAnim = uianim.ButtonAnim;
const EditAnim = uianim.EditAnim;
const animatedEditor = uianim.animatedEditor;
const animatedButton = uianim.animatedButton;
const showMsg = uianim.showMsg;
const MsgAnim = uianim.MsgAnim;
const AutoRunAnim = uianim.AutoRunAnim;

const ImVec2 = imgui.ImVec2;
const ImVec4 = imgui.ImVec4;

/// SampleData will be available through the application's context.data.
pub const SampleData = struct {
    consoleOpen: bool = false,
    showMenuBar: bool = true,
    showButtonMenu: bool = true,
};

pub const SampleApplication = zt.App(SampleData);

const WINDOW_START_WIDTH = 1200;
const WINDOW_START_HEIGHT = 800;

var screenshot_requested: bool = false;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    try G.init(allocator);
    defer G.deinit();

    // init our stuff
    init();
    var context = try SampleApplication.begin(std.heap.c_allocator);
    // Lets customize!
    try my_fonts.loadDefaultFonts(null);
    context.rebuildFont();

    // Set up state
    context.settings.energySaving = false; // Some examples are games, and will benefit from this.
    // here, more context stuff (access to SazmpleData field members) could be done

    context.setWindowSize(WINDOW_START_WIDTH, WINDOW_START_HEIGHT);
    context.setWindowTitle("Slides");
    context.setWindowIcon(zt.path("texture/ico.png"));

    G.setContext(context);

    // You control your own main loop, all you got to do is call begin and end frame,
    // and zt will handle the rest.

    var post_load = false;
    var once = true;
    while (context.open) {
        if (once) context.setWindowSize(WINDOW_START_WIDTH, WINDOW_START_HEIGHT);
        once = false;
        if (screenshot_requested) doSaveScreen();
        screenshot_requested = false;

        // BEGIN FRAME
        context.beginFrame();

        // after loading, we need to PRE-render in an imgui frame
        if (post_load) {
            G.slide_renderer.preRender(G.slideshow, G.slideshow_filp.?) catch |err| {
                std.log.err("Pre-rendering failed: {any}", .{err});
            };
            post_load = false;
        }

        // call update with our context
        update(context);
        inspectContext(context);
        elementInspector() catch |err| {
            showStatusMsgV("Ooops!");
            std.log.debug("Ooopsie {}", .{err});
        };
        context.endFrame();

        if (G.slideshow_filp_to_load) |filp| {
            try loadSlideshow(filp);
            context.rebuildFont();
            post_load = true;
        }

        if (G.doZipIt) doExportPowerpoint();
    }

    context.deinit();
}

fn elementInspector() !void {
    if (!G.showElementInspector or G.slideshow.slides.items.len == 0 or anim_autorun.running) return;
    my_fonts.pushGuiFont(1);

    // var io = ig.igGetIO();
    const flags = 0 | ig.ImGuiWindowFlags_NoSavedSettings;
    const height = 600;
    const width = 300;
    const startposx = 500;
    const startposy = 40;

    ig.igSetNextWindowPos(zt.math.vec2(startposx, startposy), ig.ImGuiCond_Once, .{});
    ig.igSetNextWindowSize(zt.math.vec2(width, height), ig.ImGuiCond_Once);

    if (ig.igBegin("Inspector Gadget", null, flags)) {
        const slideIndex: usize = @intCast(usize, G.current_slide);
        const crs = G.slide_renderer.renderedSlides.items[slideIndex];

        // index
        if (ig.igInputInt("index", &G.elementInspectorIndex, 1, 1, ig.ImGuiInputTextFlags_None)) {
            if (G.elementInspectorIndex >= crs.elements.items.len) {
                G.elementInspectorIndex = @intCast(i32, crs.elements.items.len - 1);
            }
            if (G.elementInspectorIndex < 0) G.elementInspectorIndex = 0;
        }
        var elIndex = G.elementInspectorIndex;
        var renderElement = &crs.elements.items[@intCast(usize, elIndex)];

        // kind
        ig.igSeparator();
        const textbuffers = struct {
            var strKind: [40]u8 = undefined;
            var strKindAll: [80]u8 = undefined;
        };
        _ = std.fmt.bufPrintZ(&textbuffers.strKind, "{}", .{renderElement.kind}) catch unreachable;
        _ = std.fmt.bufPrintZ(&textbuffers.strKindAll, "Kind: {s}", .{textbuffers.strKind[18..]}) catch unreachable;
        ig.igText(&textbuffers.strKindAll);

        // position
        ig.igSeparator();
        ig.igText("Position:");
        _ = zg.edit("pos.X", &renderElement.position.x);
        _ = zg.edit("pos.Y", &renderElement.position.y);

        // size
        ig.igSeparator();
        ig.igText("Size:");
        _ = zg.edit("size.X", &renderElement.size.x);
        _ = zg.edit("size.Y", &renderElement.size.y);

        // color
        if (renderElement.color) |*color| {
            ig.igSeparator();
            ig.igText("Color:");
            const colorflags = 0; // | ig.ImGuiColorEditFlags_Float;
            _ = ig.igColorPicker4("###color", @intToPtr(*f32, @ptrToInt(color)), colorflags, null);
        }

        // text
        if (renderElement.text) |text| {
            ig.igSeparator();
            // font size
            _ = zg.edit("Font size", &renderElement.fontSize.?);
            ig.igText("TEXT:");
            ig.igText(text);
        }
    }
    my_fonts.popGuiFont();
    ig.igEnd();
}

fn renderElementInspectorEffects() void {
    if (!G.showElementInspector or G.slideshow.slides.items.len == 0 or anim_autorun.running) return;
    const slideIndex: usize = @intCast(usize, G.current_slide);
    const crs = G.slide_renderer.renderedSlides.items[slideIndex];
    var elIndex = G.elementInspectorIndex;
    const renderElement = crs.elements.items[@intCast(usize, elIndex)];
    // std.log.debug("slide_index: {}, elementIndex: {}, element: {}", .{
    //     slideIndex,
    //     elIndex,
    //     renderElement,
    // });

    const slide_tl = slideAreaTL();
    const slide_size = slideSizeInWindow();

    ig.igSetCursorPos(slide_tl);
    var drawlist = ig.igGetForegroundDrawList_Nil();
    if (drawlist == null) {
        std.log.warn("drawlist is null!", .{});
    } else {
        const screenPos = render.slidePosToRenderPos(renderElement.position, slide_tl, slide_size, G.internal_render_size);
        const screenSize = render.slideSizeToRenderSize(renderElement.size, slide_size, G.internal_render_size);
        var inner_rect = ig.ImRect{ .Min = screenPos, .Max = screenPos };
        inner_rect.Max.x = screenSize.x + screenPos.x;
        inner_rect.Max.y = screenSize.y + screenPos.y;
        var outer_rect = inner_rect;
        const thickness = 8;
        outer_rect.Min.x -= thickness;
        outer_rect.Min.y -= thickness;
        outer_rect.Max.x += thickness;
        outer_rect.Max.y += thickness;
        const bgcolu32 = imgui.igGetColorU32_Vec4(anim_elementinspector.anim());
        ig.igRenderRectFilledWithHole(drawlist, outer_rect, inner_rect, bgcolu32, 3.0);
    }
}

// This is a simple side panel that will display information about the scene, your context, and settings.
fn inspectContext(ctx: *SampleApplication.Context) void {
    if (anim_autorun.running) return;
    // Basic toggle
    my_fonts.pushGuiFont(1);
    defer my_fonts.popGuiFont();
    var io = ig.igGetIO();
    if (io.*.KeysDownDuration[glfw.GLFW_KEY_GRAVE_ACCENT] == 0.0) {
        ctx.data.consoleOpen = !ctx.data.consoleOpen;
    }
    if (!ctx.data.consoleOpen) return;

    const flags = ig.ImGuiWindowFlags_NoResize | ig.ImGuiWindowFlags_NoSavedSettings;

    const height = 280;
    const width = 300;
    ig.igSetNextWindowPos(zt.math.vec2(40, 40), ig.ImGuiCond_Once, .{});
    ig.igSetNextWindowSize(zt.math.vec2(
        width,
        // height - 20,
        height,
    ), ig.ImGuiCond_Always);
    if (ig.igBegin("Settings", null, flags)) {
        // ig.igText("Settings");
        _ = zg.edit("Menu Bar", &ctx.data.showMenuBar);
        _ = zg.edit("Button Menu", &ctx.data.showButtonMenu);
        ig.igSeparator();
        _ = zg.edit("Energy Saving", &ctx.settings.energySaving);
        if (ig.igCheckbox("V Sync", &ctx.settings.vsync)) {
            // The vsync setting is only a getter, setting it does nothing.
            // So on change, we follow through with the real call that changes it.
            ctx.setVsync(ctx.settings.vsync);
        }
        ig.igSeparator();
        if (ig.igInputInt("Key repeat", &G.keyRepeat, 10, 30, ig.ImGuiInputTextFlags_None)) {
            if (G.keyRepeat <= 0) {
                G.keyRepeat = 0;
            }
        }

        ig.igSeparator();

        ig.igText("Information");
        zg.text("Frame rate: {d:6.1} fps", .{ctx.time.fps});
        zg.text("Frame time: {d:6.3} ms", .{1000.0 / ctx.time.fps});
        ig.igSeparator();
        ig.igPushStyleColor_Vec4(ig.ImGuiCol_Text, ig.ImVec4{ .x = 1, .y = 1, .z = 0.1, .w = 1 });
        zg.text("\nHide me with the [ ` ] key", .{});
        ig.igPopStyleColor(1);
    }
    ig.igEnd();
}

fn init() void {
    initEditorContent() catch {
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
    allocator: std.mem.Allocator = undefined,
    slideshow_arena: std.heap.ArenaAllocator = undefined,
    slideshow_allocator: std.mem.Allocator = undefined,
    app_state: AppState = .mainmenu,
    editor_memory: []u8 = undefined,
    loaded_content: []u8 = undefined, // we will check for dirty editor against this
    last_window_size: ImVec2 = .{},
    content_window_size: ImVec2 = .{},
    content_window_size_before_fullscreen: ImVec2 = .{},
    internal_render_size: ImVec2 = .{ .x = 1920.0, .y = 1080.0 }, // TODO: why was there 1064? Window title bar?
    slide_render_width: f32 = 1920.0,
    slide_render_height: f32 = 1080.0, // TODO: ditto: 1064
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
    did_post_init: bool = false,
    is_fullscreen: bool = false,
    context: *SampleApplication.Context = undefined,
    openfiledialog_context: ?*anyopaque = null,
    saveas_dialog_context: ?*anyopaque = null,
    keyRepeat: i32 = 0,
    slideshow_filp_to_load: ?[]const u8 = null,
    elementInspectorIndex: i32 = 0,
    showElementInspector: bool = false,
    autoRunTriggeredByPowerpointExport: bool = false,
    doZipIt: bool = false,
    showWindowBorder: bool = true,

    fn init(self: *AppData, alloc: std.mem.Allocator) !void {
        self.allocator = alloc;

        self.slideshow_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.slideshow_allocator = self.slideshow_arena.allocator();

        self.slideshow = try SlideShow.new(self.slideshow_allocator);
        self.slide_renderer = try render.SlideshowRenderer.new(self.slideshow_allocator);
    }

    fn setContext(self: *AppData, context: *SampleApplication.Context) void {
        self.context = context;
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
var anim_autorun = AutoRunAnim{};

const laserpointerZoomDefault = 0.1;

const posbufferSize: usize = 15;
const PosBuffer = struct {
    posArray: [posbufferSize]?imgui.ImVec2 = .{ null, null, null, null, null, null, null, null, null, null, null, null, null, null, null },

    fn getPositions(self: *PosBuffer) []?imgui.ImVec2 {
        return &self.posArray;
    }

    fn addPosition(self: *PosBuffer, pos: imgui.ImVec2) void {
        var i: usize = self.posArray.len - 1;
        while (i >= 1) : (i -= 1) {
            self.posArray[i] = self.posArray[i - 1];
        }
        self.posArray[0] = pos;
    }
};

const LaserpointerAnim = struct {
    frame_ticker: usize = 0,
    anim_ticker: f32 = 0,
    show_laserpointer: bool = false,
    show_laserpointer_prev: bool = false,
    laserpointer_size: f32 = 15,
    laserpointer_zoom: f32 = laserpointerZoomDefault,
    alpha_table: [6]f32 = [_]f32{ 0.875, 0.875, 0.85, 0.85, 0.825, 0.825 },
    alpha_index_step: i32 = 1,
    alpha_index: i32 = 0,
    size_jiggle_table: [6]f32 = [_]f32{ 1.5, 1.4, 1.30, 1.2, 1.1, 1.0 },
    size_jiggle_index_step: i32 = 1,
    size_jiggle_index: i32 = 0,
    posbuffer: PosBuffer = .{},
    drawVertices: ?std.ArrayList(imgui.ImVec2) = null,
    mousepos_prev: ImVec2 = .{},
    mousebutton_left_prev: bool = false,
    line_draw_thickness: f32 = 5,

    fn reinitDrawVertices(self: *LaserpointerAnim, alloc: std.mem.Allocator) !void {
        if (self.drawVertices) |*d| {
            if (d.items.len > 0)
                d.deinit();
        }
        self.drawVertices = std.ArrayList(imgui.ImVec2).init(alloc);
    }

    fn anim(self: *LaserpointerAnim, mousepos: ImVec2, alloc: std.mem.Allocator) !void {
        if (self.show_laserpointer and self.show_laserpointer_prev == false) {
            try self.reinitDrawVertices(alloc);
        }
        self.show_laserpointer_prev = self.show_laserpointer;

        const colu32 = imgui.igGetColorU32_Vec4(ImVec4{ .x = 1, .w = self.alpha_table[@intCast(usize, self.alpha_index)] });
        var drawlist = imgui.igGetForegroundDrawList_Nil();

        if (self.show_laserpointer) {
            // add vertex only if the mousepos has changed
            if (self.mousepos_prev.x != mousepos.x and self.mousepos_prev.y != mousepos.y) {
                if (self.drawVertices) |*vertices| {
                    const mouse_left_down = imgui.igIsMouseDown(imgui.ImGuiMouseButton_Left);
                    if (mouse_left_down) {
                        try vertices.append(mousepos);
                    }
                    if (self.mousebutton_left_prev == true and !mouse_left_down) {
                        try vertices.append(.{});
                    }
                    self.mousebutton_left_prev = mouse_left_down;
                }
            }
            // draw vertices
            if (self.drawVertices) |*vertices| {
                for (vertices.items) |vertex, i| {
                    if (i == 0) continue;

                    // draw a line
                    const prev_pos = vertices.items[i - 1];
                    if (vertex.x != 0 and vertex.y != 0 and prev_pos.x != 0 and prev_pos.y != 0) {
                        imgui.ImDrawList_AddLine(drawlist, vertex, prev_pos, colu32, self.line_draw_thickness);
                    }
                }
            }
            self.mousepos_prev = mousepos;

            imgui.igSetCursorPos(mousepos);
            self.posbuffer.addPosition(mousepos);
            // TODO: sapp_show_mouse(false);
            for (self.posbuffer.getPositions()) |pos, i| {
                if (pos) |p| {
                    var scale: f32 = 1.0;
                    if (i > 1) scale = 0.8;
                    const size = scale * (self.laserpointer_size * self.laserpointer_zoom + 10 * self.size_jiggle_table[@intCast(usize, self.size_jiggle_index)]);
                    imgui.ImDrawList_AddCircleFilled(drawlist, p, size, colu32, 256);
                }
            }

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
            // TODO: sapp_show_mouse(false);
            std.log.debug("Hiding mouse", .{});
        } else {
            //igSetMouseCursor(ImGuiMouseCursor_Arrow);
            std.log.debug("Showing mouse", .{});
            // TODO: sapp_show_mouse(true);
        }
    }
};

var anim_laser = LaserpointerAnim{};

const ElemInspectorFrameAnim = struct {
    frame_ticker: usize = 0,
    color: ImVec4 = .{ .x = 0, .y = 0, .z = 0, .w = 1 },
    speed: usize = 3,
    progress: f32 = 0.0,
    delta: f32 = 0.1,
    maxValue: f32 = 0.8,

    fn anim(self: *ElemInspectorFrameAnim) ImVec4 {
        if (G.showElementInspector) {
            self.frame_ticker += 1;
            if (self.frame_ticker >= self.speed) {
                self.frame_ticker = 0;
                self.progress += self.delta;

                var others = self.progress;
                if (others > self.maxValue) {
                    self.delta *= -1;
                    others = self.maxValue;
                    self.progress = self.maxValue;
                } else if (others < -0.8) {
                    self.delta *= -1;
                    if (others < 0) others = 0;
                    self.progress = 0;
                }
                if (others < 0) others = 0;
                self.color = .{ .x = 1, .y = others, .z = others, .w = 1 };
            }
        }
        return self.color;
    }
};

var anim_elementinspector = ElemInspectorFrameAnim{};

// .
// Main Update Frame Loop
// .

var time_prev: i64 = 0;
var time_now: i64 = 0;

fn post_init() void {
    // check if we have a cmd line arg
    var arg_it = std.process.args();
    _ = arg_it.skip(); // skip own exe

    if (arg_it.next(G.allocator)) |arg| {
        // we have an arg
        const slide_fn = arg catch "";
        const static = struct {
            var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        };
        const shit = std.fs.realpath(slide_fn, &static.buf) catch return;
        G.slideshow_filp_to_load = shit; // signal that we need to load
    }
}

// update will be called at every swap interval. with swap_interval = 1 above, we'll get 60 fps
fn update(context: *SampleApplication.Context) void {
    _ = context;
    if (!G.did_post_init) {
        G.did_post_init = true;
        post_init();
    }

    // debug update loop timing
    if (false) {
        time_now = std.time.milliTimestamp();
        const time_delta = time_now - time_prev;
        time_prev = time_now;
        std.log.debug("delta_t: {}", .{time_delta});
    }

    // push the gui font
    ig.igPushFont(my_fonts.gui_font);

    var mousepos: ImVec2 = undefined;
    imgui.igGetMousePos(&mousepos);
    const io = imgui.igGetIO();
    G.content_window_size = io.*.DisplaySize;
    if (G.content_window_size.x != G.last_window_size.x or G.content_window_size.y != G.last_window_size.y) {
        // window size changed
        std.log.debug("win size changed from {} to {}", .{ G.last_window_size, G.content_window_size });
        G.last_window_size = G.content_window_size;
    }

    var flags: c_int = 0;
    // flags = imgui.ImGuiWindowFlags_NoSavedSettings | imgui.ImGuiWindowFlags_NoMove | imgui.ImGuiWindowFlags_NoResize | imgui.ImGuiWindowFlags_NoDocking | imgui.ImGuiWindowFlags_NoTitleBar | imgui.ImGuiWindowFlags_NoScrollbar | imgui.ImGuiWindowFlags_NoDecoration;

    flags = 0 //
    | imgui.ImGuiWindowFlags_NoSavedSettings //
    | imgui.ImGuiWindowFlags_NoMove //
    | imgui.ImGuiWindowFlags_NoDocking //
    | imgui.ImGuiWindowFlags_NoTitleBar //
    | imgui.ImGuiWindowFlags_NoScrollbar //
    | imgui.ImGuiWindowFlags_NoBringToFrontOnFocus //
    | ig.ImGuiWindowFlags_NoBackground //
    | ig.ImGuiWindowFlags_NoScrollbar;

    // flags = ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoTitleBar;
    if (!(isFullScreen() or anim_autorun.running)) {
        if (context.data.showMenuBar) {
            flags |= imgui.ImGuiWindowFlags_MenuBar;
        }
    }

    const doHideBorder: bool = !G.showWindowBorder or anim_autorun.running;
    if (doHideBorder) {
        ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_WindowPadding, .{});
        ig.igPushStyleVar_Float(ig.ImGuiStyleVar_WindowBorderSize, 0.0);
    }
    if (imgui.igBegin("main", null, flags)) {
        // make the "window" fill the whole available area
        imgui.igSetWindowPos_Str("main", .{ .x = 0, .y = 0 }, imgui.ImGuiCond_Always);
        imgui.igSetWindowSize_Str("main", G.content_window_size, imgui.ImGuiCond_Always);

        if (!(isFullScreen() or anim_autorun.running)) {
            if (context.data.showMenuBar) {
                showMenu();
            }
        }

        handleKeyboard();

        // autorun logic
        anim_autorun.animate();
        if (anim_autorun.flag_switch_slide) {
            // inc slide
            var current_slide_index = G.current_slide;
            var new_slide_index = clampSlideIndex(G.current_slide + 1);
            if (current_slide_index == new_slide_index) {
                // stop, can't advance any further
                anim_autorun.stop();
                if (G.autoRunTriggeredByPowerpointExport) {
                    G.doZipIt = true;
                } else {
                    setStatusMsg("Screen-shotting to /tmp/slide_shots/ finished!");
                }
                G.autoRunTriggeredByPowerpointExport = false;
            } else {
                // OK, doit
                jumpToSlide(new_slide_index);
            }
        }
        if (G.slideshow_filp) |slideshow_filp| {
            if (anim_autorun.flag_start_screenshot) {
                // screenshot uses fopen, so relative paths are OK
                const pngname = std.fmt.allocPrintZ(G.allocator, "./slide_shots/{s}_{d:0>4}.png", .{ std.fs.path.basename(slideshow_filp), @intCast(u32, G.current_slide) }) catch null;
                if (pngname) |pngfn| {
                    screenshot.screenShotPngNoAlpha(pngfn) catch |err| {
                        std.log.err("screenshot error: {any}", .{err});
                        setStatusMsg("Screenshot failed - try debug build!");
                        anim_autorun.stop();
                    };
                }
            }
        } else {
            anim_autorun.stop();
        }

        const do_reload = checkAutoReload() catch false;
        if (do_reload) {
            G.slideshow_filp_to_load = G.slideshow_filp; // signal that we need to load
        }

        if (G.slideshow.slides.items.len > 0) {
            if (G.current_slide > G.slideshow.slides.items.len) {
                G.current_slide = @intCast(i32, G.slideshow.slides.items.len - 1);
            }
            showSlide2(G.current_slide, context) catch |err| {
                std.log.err("SlideShow Error: {any}", .{err});
            };
        } else {
            std.log.debug("slideshow empty", .{});
            // optionally show editor
            my_fonts.pushGuiFont(1);

            var start_y: f32 = 0; // FIXME: the 22 here is obsolete, isn't it?
            if (isFullScreen()) {
                start_y = 0;
            }
            ed_anim.desired_size.y = G.content_window_size.y - 37 - start_y;
            if (!anim_bottom_panel.visible) {
                ed_anim.desired_size.y += 20.0;
            }
            _ = animatedEditor(&ed_anim, start_y, G.content_window_size, G.internal_render_size) catch unreachable;

            my_fonts.popGuiFont();
            if (context.data.showButtonMenu and !anim_autorun.running) {
                showBottomPanel();
            }
            showStatusMsgV(G.status_msg);
            if (makeDefaultSlideshow()) {
                G.current_slide = 0;
                showSlide2(G.current_slide, context) catch |err| {
                    std.log.err("SlideShow Error: {any}", .{err});
                };
            } else |err| {
                std.log.err("SlideShow Error: {any}", .{err});
            }
        }

        // handle cmdLoad
        if (G.openfiledialog_context) |dlg| {
            const maxSize = ig.ImVec2{ .x = 1600, .y = 800 };
            const minSize = ig.ImVec2{ .x = 800, .y = 400 };

            // display dialog
            if (filedialog.IGFD_DisplayDialog(dlg, "loadsld", ig.ImGuiWindowFlags_NoCollapse, minSize, maxSize)) {
                // actually load the slideshow
                if (filedialog.IGFD_IsOk(dlg)) {
                    const cfilePathName = filedialog.IGFD_GetFilePathName(dlg);
                    std.log.debug("GetFilePathName : {s}\n", .{cfilePathName});
                    G.slideshow_filp_to_load = std.mem.sliceTo(cfilePathName, 0); // signal that we need to load

                    filedialog.IGFD_CloseDialog(dlg);
                    filedialog.IGFD_Destroy(dlg);
                    G.openfiledialog_context = null;
                } else {
                    filedialog.IGFD_CloseDialog(dlg);
                    filedialog.IGFD_Destroy(dlg);
                    G.openfiledialog_context = null;
                }
            }
        }
        if (G.saveas_dialog_context) |dlg| {
            const maxSize = ig.ImVec2{ .x = 1600, .y = 800 };
            const minSize = ig.ImVec2{ .x = 800, .y = 400 };
            if (filedialog.IGFD_DisplayDialog(dlg, "saveas", ig.ImGuiWindowFlags_NoCollapse, minSize, maxSize)) {
                // actually load the slideshow
                if (filedialog.IGFD_IsOk(dlg)) {
                    const cfilePathName = filedialog.IGFD_GetFilePathName(dlg);
                    std.log.debug("GetFilePathName : {s}\n", .{cfilePathName});
                    if (!saveSlideshow(std.mem.sliceTo(cfilePathName, 0), ed_anim.textbuf)) {
                        std.log.err("saveas error", .{});
                    }
                    filedialog.IGFD_CloseDialog(dlg);
                    filedialog.IGFD_Destroy(dlg);
                    G.saveas_dialog_context = null;
                } else {
                    filedialog.IGFD_CloseDialog(dlg);
                    filedialog.IGFD_Destroy(dlg);
                    G.saveas_dialog_context = null;
                }
            }
        }
        renderElementInspectorEffects();
        if (G.doZipIt) {
            ig.igSetCursorPos(.{ .x = 100, .y = 100 });
            my_fonts.pushStyledFontScaled(128, .bold);
            imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_Text, .{ .x = 1, .w = 1 });
            ig.igText("Exporting...");
            ig.igPopStyleColor(1);
            my_fonts.popFontScaled();
        }

        // laser pointer
        if (mousepos.x > 0 and mousepos.y > 0) {
            anim_laser.anim(mousepos, G.slideshow_allocator) catch {};
        }

        imgui.igEnd();

        if (G.show_saveas) {
            imgui.igOpenPopup_Str("Save slideshow?", imgui.ImGuiPopupFlags_MouseButtonDefault_);
        }

        if (savePopup(G.show_saveas_reason)) {
            G.show_saveas = false;
            G.show_saveas_reason = .none;
        }

        render.updateRenderDistortion();
        ig.igPopFont();
    }
    if (doHideBorder) {
        ig.igPopStyleVar(2);
    }
}

fn makeDefaultSlideshow() !void {
    const empty = try Slide.new(G.allocator);
    std.log.debug("empty slide created", .{});
    // make a grey background
    var bg = SlideItem{ .kind = .background, .color = .{ .x = 0.5, .y = 0.5, .z = 0.5, .w = 0.9 } };
    try empty.items.?.append(bg);
    try G.slideshow.slides.append(empty);
    try G.slide_renderer.preRender(G.slideshow, "");
    std.log.debug("created empty slideshow", .{});
}

fn jumpToSlide(slidenumber: i32) void {
    if (G.current_slide == slidenumber) {
        return;
    }
    anim_laser.reinitDrawVertices(G.allocator) catch {};
    G.current_slide = slidenumber;
    const pos_in_editor = G.slideshow.slides.items[@intCast(usize, slidenumber)].pos_in_editor;
    if (ed_anim.visible) {
        ed_anim.jumpToPosAndHighlightLine(pos_in_editor, false);
    }
    G.elementInspectorIndex = 0;
}

var lastPressed: [512]i32 = undefined;
fn handleKeyboardAutofire(key: usize) bool {
    const io = ig.igGetIO();
    const duration = io.*.KeysDownDuration[key];
    if (duration < 0.0) {
        lastPressed[key] = 0;
        return false;
    }
    var interval_ms = G.keyRepeat;
    if (interval_ms <= 0) {
        return duration == 0.0;
    }

    const duration_ms_f = duration * 1000.0;
    const duration_ms = @floatToInt(i32, duration_ms_f);
    const duration_ms_prev = lastPressed[key];
    const ret = (duration_ms - duration_ms_prev > interval_ms) or duration == 0.0;
    if (ret) {
        lastPressed[key] = duration_ms;
        std.log.debug("time: {}", .{duration_ms});
    }
    return ret;
}

fn keyPressed(key: usize) bool {
    const io = ig.igGetIO();
    return io.*.KeysDownDuration[key] == 0.0;
}

fn handleKeyboard() void {
    const io = ig.igGetIO();

    const ctrl = io.*.KeyCtrl;
    const shift = io.*.KeyShift;

    if (keyPressed(glfw.GLFW_KEY_Q) and ctrl) {
        cmdQuit();
        return;
    }
    if (keyPressed(glfw.GLFW_KEY_O) and ctrl) {
        cmdLoadSlideshow();
        return;
    }
    if (keyPressed(glfw.GLFW_KEY_N) and ctrl) {
        cmdNewSlideshow();
        return;
    }
    if (keyPressed(glfw.GLFW_KEY_S) and ctrl) {
        cmdSave();
        return;
    }

    if (keyPressed(glfw.GLFW_KEY_P) and ctrl) {
        cmdSaveScreen();
        return;
    }

    if (keyPressed(glfw.GLFW_KEY_I) and ctrl) {
        G.showElementInspector = !G.showElementInspector;
        return;
    }

    if (keyPressed(glfw.GLFW_KEY_T) and ctrl) {
        cmdExportPowerpoint();
    }

    // don't consume keys while the editor is visible
    if ((ig.igGetActiveID() == ig.igGetID_Str("editor")) or ed_anim.search_ed_active or ed_anim.search_ed_active or (ig.igGetActiveID() == ig.igGetID_Str("##search")) or G.saveas_dialog_context != null or G.openfiledialog_context != null) {
        return;
    }

    if (keyPressed(glfw.GLFW_KEY_A)) {
        cmdToggleAutoRun();
        return;
    }
    if (keyPressed(glfw.GLFW_KEY_D)) {
        anim_laser.reinitDrawVertices(G.allocator) catch {};
        return;
    }

    if (keyPressed(glfw.GLFW_KEY_L) and !shift) {
        anim_laser.toggle();
        return;
    }
    if (keyPressed(glfw.GLFW_KEY_L) and shift) {
        const zoom: f32 = if (anim_laser.laserpointer_zoom < laserpointerZoomDefault * 7.5) 7.5 else 1.5;
        anim_laser.laserpointer_zoom *= zoom;
        if (anim_laser.laserpointer_zoom > 10) {
            anim_laser.laserpointer_zoom = laserpointerZoomDefault;
        }
        return;
    }
    var deltaindex: i32 = 0;

    if (handleKeyboardAutofire(glfw.GLFW_KEY_SPACE)) {
        deltaindex = 1;
    }

    if (keyPressed(glfw.GLFW_KEY_LEFT)) {
        deltaindex = -1;
    }

    if (keyPressed(glfw.GLFW_KEY_RIGHT)) {
        deltaindex = 1;
    }

    if (handleKeyboardAutofire(glfw.GLFW_KEY_BACKSPACE)) {
        deltaindex = -1;
    }

    if (keyPressed(glfw.GLFW_KEY_PAGE_UP)) {
        deltaindex = -1;
    }

    if (keyPressed(glfw.GLFW_KEY_PAGE_DOWN)) {
        deltaindex = 1;
    }
    if (keyPressed(glfw.GLFW_KEY_UP)) {
        ed_anim.grow();
    }

    if (keyPressed(glfw.GLFW_KEY_DOWN)) {
        ed_anim.shrink();
    }

    if (keyPressed(glfw.GLFW_KEY_F)) {
        cmdToggleFullscreen();
    }

    if (keyPressed(glfw.GLFW_KEY_M)) {
        if (shift) {
            G.app_state = .mainmenu;
        } else {
            cmdToggleBottomPanel();
        }
    }

    var new_slide_index: i32 = G.current_slide + deltaindex;

    // special slide navigation: 1 and 0
    // needs to happen after applying deltaindex!!!!!
    if (keyPressed(glfw.GLFW_KEY_1) or (ig.igIsKeyReleased(glfw.GLFW_KEY_G) and !shift)) {
        new_slide_index = 0;
    }

    if (keyPressed(glfw.GLFW_KEY_0) or (ig.igIsKeyReleased(glfw.GLFW_KEY_G) and shift)) {
        new_slide_index = @intCast(i32, G.slideshow.slides.items.len - 1);
    }

    // clamp slide index
    new_slide_index = clampSlideIndex(new_slide_index);
    jumpToSlide(new_slide_index);
}

fn clampSlideIndex(new_slide_index: i32) i32 {
    var ret = new_slide_index;
    if (G.slideshow.slides.items.len > 0 and new_slide_index >= @intCast(i32, G.slideshow.slides.items.len)) {
        ret = @intCast(i32, G.slideshow.slides.items.len - 1);
    } else if (G.slideshow.slides.items.len == 0 and G.current_slide > 0) {
        ret = 0;
    }
    if (new_slide_index < 0) {
        ret = 0;
    }
    return ret;
}

fn showSlide2(slide_number: i32, context: *SampleApplication.Context) !void {
    // optionally show editor
    my_fonts.pushGuiFont(1.2);

    var start_y: f32 = 22;
    if (isFullScreen()) {
        start_y = 0;
    }
    ed_anim.desired_size.y = G.content_window_size.y - 46 - start_y;
    if (!anim_bottom_panel.visible) {
        ed_anim.desired_size.y += 40.0;
    }
    const editor_active = try animatedEditor(&ed_anim, start_y, G.content_window_size, G.internal_render_size);

    if (!editor_active and !ed_anim.search_ed_active) {
        if (ig.igIsKeyPressed(glfw.GLFW_KEY_E, false) and G.openfiledialog_context == null and G.saveas_dialog_context == null) {
            cmdToggleEditor();
        }
    }

    my_fonts.popGuiFont();

    // render slide
    G.slide_render_width = G.internal_render_size.x - ed_anim.current_size.x;
    try G.slide_renderer.render(slide_number, slideAreaTL(), slideSizeInWindow(), G.internal_render_size);
    // OK: std.log.debug("slideAreaTL: {any}, slideSizeInWindow: {any}, internal_render_size: {any}", .{ slideAreaTL(), slideSizeInWindow(), G.internal_render_size });

    // .
    // button row
    // .
    if (context.data.showButtonMenu and !anim_autorun.running) {
        showBottomPanel();
    }

    showStatusMsgV(G.status_msg);
}

const bottomPanelAnim = struct { visible: bool = false, visible_before_editor: bool = false };

fn showBottomPanel() void {
    my_fonts.pushGuiFont(1);
    imgui.igSetCursorPos(ImVec2{ .x = 0, .y = G.content_window_size.y - 42 });
    if (anim_bottom_panel.visible) {
        imgui.igColumns(6, null, false);
        bt_toggle_bottom_panel_anim.arrow_dir = 0;
        if (animatedButton("a", ImVec2{ .x = 20, .y = 20 }, &bt_toggle_bottom_panel_anim) == .released) {
            anim_bottom_panel.visible = false;
        }
        imgui.igNextColumn();
        imgui.igNextColumn();
        // TODO: using the button can cause crashes, whereas the shortcut and menu don't -- what's going on here?
        //       when button is removed, we also saw it with the shortcut
        if (animatedButton("[f]ullscreen", ImVec2{ .x = imgui.igGetColumnWidth(1), .y = 38 }, &bt_toggle_fullscreen_anim) == .released) {
            cmdToggleFullscreen();
        }
        imgui.igNextColumn();
        if (animatedButton("[o]verview", ImVec2{ .x = imgui.igGetColumnWidth(1), .y = 38 }, &bt_overview_anim) == .released) {
            setStatusMsg("Not implemented!");
        }
        imgui.igNextColumn();
        if (animatedButton("[e]ditor", ImVec2{ .x = imgui.igGetColumnWidth(2), .y = 38 }, &bt_toggle_ed_anim) == .released) {
            cmdToggleEditor();
        }
        imgui.igNextColumn();
        if (ed_anim.visible) {
            if (animatedButton("save", ImVec2{ .x = imgui.igGetColumnWidth(2), .y = 38 }, &bt_save_anim) == .released) {
                cmdSave();
            }
        }
        imgui.igEndColumns();
    } else {
        imgui.igColumns(5, null, false);
        bt_toggle_bottom_panel_anim.arrow_dir = 1;
        if (animatedButton("a", ImVec2{ .x = 20, .y = 20 }, &bt_toggle_bottom_panel_anim) == .released) {
            anim_bottom_panel.visible = true;
        }
        imgui.igNextColumn();
        imgui.igNextColumn();
        imgui.igNextColumn();
        imgui.igNextColumn();
        imgui.igEndColumns();
    }
    my_fonts.popGuiFont();
}

fn setStatusMsg(msg: [*c]const u8) void {
    G.status_msg = msg;
    anim_status_msg.anim_state = .fadein;
    anim_status_msg.ticker_ms = 0;
}

fn saveSlideshow(filp: ?[]const u8, contents: [*c]u8) bool {
    if (filp) |filepath| {
        std.log.debug("saving to: {s} ", .{filepath});
        const file = std.fs.cwd().createFile(filepath, .{}) catch {
            setStatusMsg("ERROR saving slideshow");
            return false;
        };
        defer file.close();

        const contents_slice: []u8 = std.mem.span(contents);
        file.writeAll(contents_slice) catch {
            setStatusMsg("ERROR saving slideshow");
            return false;
        };
        setStatusMsg("Saved!");
        return true;
    } else {
        std.log.err("no filename!", .{});
        setStatusMsg("Save as -> not implemented!");
        return false;
    }
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
    // TODO: still uses main font, which is dependent on the slideshow's fonts
    var tsize = ImVec2{};
    my_fonts.pushStyledFontScaled(64, .normal);
    imgui.igCalcTextSize(&tsize, msg, msg + std.mem.len(msg), false, 2000.0);
    const maxw = G.content_window_size.x * 0.9;
    if (tsize.x > maxw) {
        tsize.x = maxw;
    }

    const x = (G.content_window_size.x - tsize.x) / 2.0;
    const y = G.content_window_size.y / 4;

    const pos = ImVec2{ .x = x, .y = y };
    const flyin_pos = ImVec2{ .x = x, .y = G.content_window_size.y - tsize.y - 8 };
    const color = ImVec4{ .x = 1, .y = 1, .z = 0x80 / 255.0, .w = 1 };
    imgui.igPushTextWrapPos(maxw + x);
    showMsg(msg, pos, flyin_pos, color, &anim_status_msg);
    imgui.igPopTextWrapPos();
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
    G.hot_reload_ticker += 1;
    if (G.slideshow_filp) |filp| {
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
    }
    return false;
}

fn loadSlideshow(filp: []const u8) !void {
    std.log.debug("LOAD {s}", .{filp});
    defer G.slideshow_filp_to_load = null;
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
                    // now reload fonts
                    if (pcontext.custom_fonts_present) {
                        std.log.debug("reloading fonts", .{});
                        try fontbakery.loadCustomFonts(pcontext.fontConfig, G.slideshow_filp.?);
                        std.log.debug("reloaded fonts", .{});
                    }
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

fn isFullScreen() bool {
    const pm = glfw.glfwGetPrimaryMonitor();
    const mm = glfw.glfwGetVideoMode(pm);
    glfw.glfwWindowHint(glfw.GLFW_RED_BITS, mm.*.redBits);
    glfw.glfwWindowHint(glfw.GLFW_GREEN_BITS, mm.*.greenBits);
    glfw.glfwWindowHint(glfw.GLFW_BLUE_BITS, mm.*.blueBits);
    glfw.glfwWindowHint(glfw.GLFW_REFRESH_RATE, mm.*.refreshRate);

    const current = G.content_window_size;
    const result = mm.*.width == @floatToInt(i32, current.x) and mm.*.height == @floatToInt(i32, current.y);
    // std.log.debug("w={d:6.0}x{d:6.0} m={d:6.0}x{d:6.0} => {}", .{ current.x, current.y, mm.*.width, mm.*.height, result });
    return result;
}
// .
// COMMANDS
// .
fn cmdToggleFullscreen() void {
    // MAKE FULLSCREEN
    const pm = glfw.glfwGetPrimaryMonitor();
    std.log.info("Primary Monitor: {s}", .{pm});
    const mm = glfw.glfwGetVideoMode(pm);
    std.log.info("Video Mode : {any}", .{mm});
    glfw.glfwWindowHint(glfw.GLFW_RED_BITS, mm.*.redBits);
    glfw.glfwWindowHint(glfw.GLFW_GREEN_BITS, mm.*.greenBits);
    glfw.glfwWindowHint(glfw.GLFW_BLUE_BITS, mm.*.blueBits);
    glfw.glfwWindowHint(glfw.GLFW_REFRESH_RATE, mm.*.refreshRate);

    if (isFullScreen()) {
        const sz = G.content_window_size_before_fullscreen;
        glfw.glfwSetWindowMonitor(G.context.window, null, 0, 0, @floatToInt(i32, sz.x), @floatToInt(i32, sz.y), mm.*.refreshRate);
    } else {
        G.content_window_size_before_fullscreen = G.content_window_size;
        glfw.glfwSetWindowMonitor(G.context.window, pm, 0, 0, mm.*.width, mm.*.height, mm.*.refreshRate);
    }
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
        G.slideshow_filp_to_load = filp; // signal that we need to load
    }
}

fn cmdSaveScreen() void {
    screenshot_requested = true;
}

fn doSaveScreen() void {
    const t: i64 = std.time.milliTimestamp();
    const screenshot_fn = std.fmt.allocPrintZ(G.allocator, "screenshot_{}.png", .{t}) catch return; // ignore error
    screenshot.screenShotPngNoAlpha(screenshot_fn) catch {}; // ignore error
    setStatusMsg("Screenshot saved.");
}

fn saveSlideshowAs() void {
    if (G.saveas_dialog_context) |dlg| {
        const maxSize = ig.ImVec2{ .x = 1600, .y = 800 };
        const minSize = ig.ImVec2{ .x = 800, .y = 400 };
        if (filedialog.IGFD_DisplayDialog(dlg, "saveas", ig.ImGuiWindowFlags_NoCollapse, minSize, maxSize)) {
            // actually load the slideshow
            if (filedialog.IGFD_IsOk(dlg)) {
                const cfilePathName = filedialog.IGFD_GetFilePathName(dlg);
                std.log.debug("GetFilePathName : {s}\n", .{cfilePathName});
                if (!saveSlideshow(std.mem.sliceTo(cfilePathName, 0), ed_anim.textbuf)) {
                    std.log.err("saveas error", .{});
                }
                filedialog.IGFD_CloseDialog(dlg);
                filedialog.IGFD_Destroy(dlg);
                G.saveas_dialog_context = null;
            } else {
                filedialog.IGFD_CloseDialog(dlg);
                filedialog.IGFD_Destroy(dlg);
                G.saveas_dialog_context = null;
            }
        }
    } else {
        G.saveas_dialog_context = filedialog.IGFD_Create();
        filedialog.IGFD_OpenDialog(
            G.saveas_dialog_context.?,
            "saveas",
            "Save slideshow as...",
            "slide files(*.sld){.sld}",
            ".",
            "",
            0,
            @intToPtr(?*anyopaque, 0),
            @enumToInt(filedialog.ImGuiFileDialogFlags.ConfirmOverwrite),
        );
    }
    return;
}

fn cmdSaveAs() void {
    saveSlideshowAs();
}

fn doQuit() void {
    std.process.exit(0);
}

fn doLoadSlideshow() void {
    // just open the dialog and let update() do the rest
    std.log.debug("open file dialog", .{});
    if (G.openfiledialog_context == null) {
        G.openfiledialog_context = filedialog.IGFD_Create();
        filedialog.IGFD_OpenDialog(
            G.openfiledialog_context.?,
            "loadsld",
            "Load Slideshow",
            "slide files(*.sld){.sld}",
            ".",
            "",
            0,
            @intToPtr(?*anyopaque, 0),
            @enumToInt(filedialog.ImGuiFileDialogFlags.None),
        );
    }
    return;
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
    imgui.igSetNextWindowSize(.{ .x = 500, .y = -1 }, imgui.ImGuiCond_Always);
    var open: bool = true;
    var doit = false;
    if (imgui.igBeginPopupModal("Save slideshow?", &open, imgui.ImGuiWindowFlags_AlwaysAutoResize)) {
        defer imgui.igEndPopup();

        imgui.igText("The slideshow has unsaved changes.\nSave it?");
        imgui.igColumns(2, "id-x", true);

        var no = imgui.igButton("No", .{ .x = -1, .y = 30 });
        imgui.igNextColumn();
        var yes = imgui.igButton("YES", .{ .x = -1, .y = 30 });
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

fn cmdToggleAutoRun() void {
    if (anim_autorun.toggle()) {
        // started
        // goto 1st slide
        G.current_slide = 0;
        if (!isFullScreen()) {
            G.context.setWindowSize(1920, 1080);
            //     cmdToggleFullscreen();
        }

        // delete ./slide_shots/ if present, then (re-) create it
        var tmpdir = std.fs.cwd();
        if (tmpdir.deleteTree("slide_shots")) {} else |err| {
            std.log.err("Warning: Unable to delete ./slide_shots : {s}", .{err});
        }
        if (tmpdir.makeDir("slide_shots")) {} else |err| {
            std.log.err("Unable to create /tmp/slide_shots : {s}", .{err});
        }
    }
}

// .
// .
// MENU
// .
// .

fn showMenu() void {
    my_fonts.pushGuiFont(1);
    if (imgui.igBeginMenuBar()) {
        defer imgui.igEndMenuBar();

        if (imgui.igBeginMenu("File", true)) {
            if (imgui.igMenuItem_Bool("New", "Ctrl + N", false, true)) {
                cmdNewSlideshow();
            }
            // if (imgui.igMenuItemBool("New from template...", "", false, true)) {
            //     cmdNewFromTemplate();
            // }
            if (imgui.igMenuItem_Bool("Open...", "Ctrl + O", false, true)) {
                cmdLoadSlideshow();
            }
            if (imgui.igMenuItem_Bool("Save", "Ctrl + S", false, isEditorDirty())) {
                cmdSave();
            }
            if (imgui.igMenuItem_Bool("Save as...", "", false, true)) {
                cmdSaveAs();
            }
            if (imgui.igMenuItem_Bool("Export to Powerpoint...", "Ctrl + T", false, true)) {
                cmdExportPowerpoint();
            }
            if (imgui.igMenuItem_Bool("Quit", "Ctrl + Q", false, true)) {
                cmdQuit();
            }
            imgui.igEndMenu();
        }
        if (imgui.igBeginMenu("View", true)) {
            if (imgui.igMenuItem_Bool("Toggle editor", "E", false, true)) {
                cmdToggleEditor();
            }
            if (imgui.igMenuItem_Bool("Toggle full-screen", "F", false, true)) {
                cmdToggleFullscreen();
            }
            if (imgui.igMenuItem_Bool("Toggle Window Border", "F", false, true)) {
                G.showWindowBorder = !G.showWindowBorder;
            }
            if (imgui.igMenuItem_Bool("Overview", "O", false, true)) {}
            if (imgui.igMenuItem_Bool("Toggle Laserpointer", "L", false, true)) {
                anim_laser.toggle();
            }
            if (imgui.igMenuItem_Bool("Toggle on-screen menu buttons", "M", false, true)) {
                cmdToggleBottomPanel();
            }

            if (imgui.igMenuItem_Bool("Toggle inspector gadget", "Ctrl + I", false, true)) {
                G.showElementInspector = !G.showElementInspector;
            }
            if (imgui.igMenuItem_Bool("Toggle Distortion", null, false, true)) {
                render.renderDistortionAnimation.running = !render.renderDistortionAnimation.running;
            }
            imgui.igEndMenu();
        }
        if (imgui.igBeginMenu("Help", true)) {
            if (imgui.igMenuItem_Bool("About", "", false, true)) {
                setStatusMsg("Not implemented!");
            }
            imgui.igEndMenu();
        }
    }
    my_fonts.popGuiFont();
}

fn cmdExportPowerpoint() void {
    G.autoRunTriggeredByPowerpointExport = true;
    cmdToggleAutoRun();
}

fn doExportPowerpoint() void {
    if (G.slideshow_filp) |slideshow_filp_really| {
        pptx.copyFixedAssetsTo("export_pptx", G.allocator) catch |err| {
            std.log.debug("failed pptx : {}", .{err});
        };
        pptx.exportPptx("export_pptx", slideshow_filp_really, G.slideshow.slides.items.len, G.allocator) catch |err| {
            std.log.debug("failed pptx : {}", .{err});
        };
        std.log.debug("zipping it...", .{});
        const zipNameMaybe = std.fmt.allocPrintZ(G.allocator, "{s}.pptx", .{slideshow_filp_really}) catch null;
        if (zipNameMaybe) |zipName| {
            pptx.zipIt("export_pptx", zipName, G.allocator) catch |err| {
                std.log.debug("failed pptx : {}", .{err});
            };
            std.log.debug("zipped it!", .{});
            const msg = std.fmt.allocPrintZ(G.slideshow_allocator, "Zip created: {s}", .{zipName}) catch null;
            if (msg) |m| setStatusMsg(m);
        } else {
            std.log.debug("no memory for zipName creation", .{});
        }
    }
    G.doZipIt = false;
}
