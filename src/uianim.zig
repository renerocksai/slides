const std = @import("std");
const imgui = @import("imgui");
const parser = @import("parser.zig");
const my_fonts = @import("fontbakery.zig");
usingnamespace imgui;

// .
// Animation
// .
pub const frame_dt: f32 = 0.016; // roughly 16ms per frame

pub const ButtonState = enum {
    none,
    hovered,
    pressed,
    released,
};

pub const ButtonAnim = struct {
    ticker_ms: u32 = 0,
    prevState: ButtonState = .none,
    currentState: ButtonState = .none,
    hover_duration: i32 = 200,
    press_duration: i32 = 100,
    release_duration: i32 = 100,
    current_color: imgui.ImVec4 = imgui.ImVec4{},
    arrow_dir: i32 = -1,
};

// pub const ImGuiInputTextCallback = ?fn ([*c]ImGuiInputTextCallbackData) callconv(.C) c_int;

pub fn my_callback(data: [*c]imgui.ImGuiInputTextCallbackData) callconv(.C) c_int {
    var x: *EditAnim = @ptrCast(*EditAnim, @alignCast(@alignOf(*EditAnim), data.*.UserData));

    if (x.editAction) |action| {
        data.*.CursorPos = @intCast(c_int, action.jump_to_cursor_pos);
        if (action.highlight_line) {
            data.*.SelectionStart = data.*.CursorPos;

            const buf = x.parser_context.?.input;
            if (std.mem.indexOfPos(u8, buf, action.jump_to_cursor_pos, "\n")) |eol_pos| {
                data.*.SelectionEnd = @intCast(c_int, eol_pos);
            } else {
                data.*.SelectionEnd = data.*.SelectionStart + 10;
            }
        } else if (action.selection_size > 0) {
            data.*.SelectionStart = data.*.CursorPos;
            data.*.SelectionEnd = data.*.SelectionStart + @intCast(c_int, action.selection_size);
        }
        x.editAction = null;
    } else {
        if (x.editActionPost) |action| {
            data.*.CursorPos = @intCast(c_int, action.jump_to_cursor_pos);
            if (action.highlight_line) {
                data.*.SelectionStart = data.*.CursorPos;

                const buf = x.parser_context.?.input;
                if (std.mem.indexOfPos(u8, buf, action.jump_to_cursor_pos, "\n")) |eol_pos| {
                    data.*.SelectionEnd = @intCast(c_int, eol_pos);
                } else {
                    data.*.SelectionEnd = data.*.SelectionStart + 10;
                }
            } else if (action.selection_size > 0) {
                data.*.SelectionStart = data.*.CursorPos;
                data.*.SelectionEnd = data.*.SelectionStart + @intCast(c_int, action.selection_size);
            }
            x.editActionPost = null;
        }

        x.current_cursor_pos = @intCast(usize, data.*.CursorPos);
    }
    return 0;
}

pub const EditAnim = struct {
    visible: bool = false,
    visible_prev: bool = false,
    current_size: imgui.ImVec2 = imgui.ImVec2{},
    desired_size: imgui.ImVec2 = .{ .x = 600, .y = 0 },
    slide_button_width: f32 = 10,
    in_grow_shrink_animation: bool = false,
    in_flash_editor_animation: bool = false,
    grow_shrink_from_width: f32 = 0,
    ticker_ms: u32 = 0,
    fadein_duration: i32 = 200,
    fadeout_duration: i32 = 200,
    flash_editor_duration: i32 = 10,
    textbuf: [*c]u8 = null,
    textbuf_size: u32 = 128 * 1024,
    parser_context: ?*parser.ParserContext = null,
    selected_error: c_int = 1000,
    editAction: ?EditActionData = null,
    editActionPost: ?EditActionData = null,
    resize_button_anim: ButtonAnim = .{},
    resize_mouse_x: f32 = 0,
    in_resize_mode: bool = false,
    scroll_lines_after_autosel: i32 = 5, // scroll down this number of lines after auto selecting (jump to slide, find)
    current_cursor_pos: usize = 0,
    search_term: [*c]u8 = null,
    search_term_size: usize = 25,
    search_ed_active: bool = false,
    current_search_pos: usize = 0,

    pub fn shrink(self: *EditAnim) void {
        if (self.desired_size.x > 300) {
            self.grow_shrink_from_width = self.desired_size.x;
            self.desired_size.x /= 1.20;
            self.visible_prev = false;
            self.in_grow_shrink_animation = true;
        }
    }
    pub fn grow(self: *EditAnim) void {
        if (self.desired_size.x < 1920.0 / 1.20 - 200.0) {
            self.grow_shrink_from_width = self.desired_size.x;
            self.desired_size.x *= 1.20;
            self.visible_prev = false;
            self.in_grow_shrink_animation = true;
        }
    }
    pub fn jumpToPosAndHighlightLine(self: *EditAnim, pos: usize, activate_editor: bool) void {

        // now honor the scroll_lines_after_autosel
        var eol_pos: usize = pos;
        var linecount: i32 = 0;

        if (pos > self.current_cursor_pos) {
            // search forwards
            while (linecount < self.scroll_lines_after_autosel) {
                if (std.mem.indexOfPos(u8, self.parser_context.?.input, eol_pos, "\n")) |neweol| {
                    eol_pos = neweol + 1;
                }
                linecount += 1;
            }
        } else {
            // search backwards
            while (eol_pos > 0) {
                if (self.parser_context.?.input[eol_pos] == '\n') {
                    linecount += 1;
                    if (linecount >= self.scroll_lines_after_autosel) {
                        break;
                    }
                }
                eol_pos -= 1;
            }
        }

        // first, jump to fix scroll position
        self.editAction = .{
            .jump_to_cursor_pos = eol_pos,
            .highlight_line = false,
        };

        // then jump, sel, and highlight
        self.editActionPost = .{
            .jump_to_cursor_pos = pos,
            .highlight_line = true,
        };

        if (activate_editor) {
            self.activate();
        } else {
            self.startFlashAnimation();
        }
    }
    pub fn activate(self: *EditAnim) void {
        _ = self;
        imgui.igActivateItem(imgui.igGetID_Str("editor")); // TODO move ID str into struct
    }
    pub fn startFlashAnimation(self: *EditAnim) void {
        self.ticker_ms = 0;
        self.in_flash_editor_animation = true;
    }
};

const EditActionData = struct {
    jump_to_cursor_pos: usize = 0,
    selection_size: usize = 0,
    highlight_line: bool = false,
};

pub fn animateVec2(from: imgui.ImVec2, to: imgui.ImVec2, duration_ms: i32, ticker_ms: u32) imgui.ImVec2 {
    if (ticker_ms >= duration_ms) {
        return to;
    }
    if (ticker_ms <= 1) {
        return from;
    }

    var ret = from;
    var fduration_ms = @intToFloat(f32, duration_ms);
    var fticker_ms = @intToFloat(f32, ticker_ms);
    ret.x += (to.x - from.x) / fduration_ms * fticker_ms;
    ret.y += (to.y - from.y) / fduration_ms * fticker_ms;
    return ret;
}

pub fn animateX(from: imgui.ImVec2, to: imgui.ImVec2, duration_ms: i32, ticker_ms: u32) imgui.ImVec2 {
    if (ticker_ms >= duration_ms) {
        return to;
    }
    if (ticker_ms <= 1) {
        return from;
    }

    var ret = from;
    var fduration_ms = @intToFloat(f32, duration_ms);
    var fticker_ms = @intToFloat(f32, ticker_ms);
    ret.x += (to.x - from.x) / fduration_ms * fticker_ms;
    return ret;
}

var bt_save_anim = ButtonAnim{};
var bt_grow_anim = ButtonAnim{};
var bt_shrink_anim = ButtonAnim{};

// returns true if editor is active
pub fn animatedEditor(anim: *EditAnim, start_y: f32, content_window_size: imgui.ImVec2, internal_render_size: imgui.ImVec2) !bool {
    var fromSize = imgui.ImVec2{};
    var toSize = imgui.ImVec2{};
    var anim_duration: i32 = 0;
    var show: bool = true;

    var size = anim.desired_size;

    var editor_pos = imgui.ImVec2{ .y = start_y };
    var pos = imgui.ImVec2{ .y = start_y };
    pos.x = internal_render_size.x - anim.current_size.x;
    pos.x *= content_window_size.x / internal_render_size.x;
    editor_pos = pos;
    editor_pos.x += anim.slide_button_width;

    if (!anim.visible) {
        anim.current_size.x = 0;
    }

    if (anim.textbuf == null) {
        var allocator = std.heap.page_allocator;
        const memory = try allocator.alloc(u8, anim.textbuf_size);
        anim.textbuf = memory.ptr;
        anim.textbuf[0] = 0;
    }
    if (anim.search_term == null) {
        var allocator = std.heap.page_allocator;
        const search_mem = try allocator.alloc(u8, anim.search_term_size);
        anim.search_term = search_mem.ptr;
        anim.search_term[0] = 0;
    }
    // only animate when transitioning
    if (anim.visible != anim.visible_prev) {
        if (anim.visible) {
            // fading in
            if (!anim.in_grow_shrink_animation) {
                fromSize = imgui.ImVec2{};
            } else {
                fromSize.x = anim.grow_shrink_from_width;
            }
            fromSize.y = size.y;
            toSize = size;
            anim_duration = anim.fadein_duration;
        } else {
            fromSize = size;
            if (!anim.in_grow_shrink_animation) {
                toSize = imgui.ImVec2{};
            } else {
                toSize.x = anim.grow_shrink_from_width;
            }
            toSize.y = size.y;
            anim_duration = anim.fadeout_duration;
        }
        anim.current_size = animateX(fromSize, toSize, anim_duration, anim.ticker_ms);
        anim.ticker_ms += @floatToInt(u32, frame_dt * 1000);
        if (anim.ticker_ms >= anim_duration) {
            anim.visible_prev = anim.visible;
            anim.in_grow_shrink_animation = false;
        }
    } else {
        if (anim.in_flash_editor_animation) {
            anim.ticker_ms += 1;
            if (anim.ticker_ms < anim.flash_editor_duration) {
                anim.activate();
            } else {
                anim.in_flash_editor_animation = false;
                imgui.igActivateItem(imgui.igGetID_Str("dummy"));
            }
        } else {
            anim.ticker_ms = 0;
            if (!anim.visible) {
                show = false;
            }
        }
    }

    if (show) {
        editor_pos.y += 12;
        imgui.igSetCursorPos(editor_pos);
        var s: imgui.ImVec2 = trxy(anim.current_size, content_window_size, internal_render_size);

        // (optional) extra stuff
        const grow_shrink_button_panel_height = 0; // 22;
        const find_area_height = 50;
        const find_area_button_size = 120;
        const find_area_min_width = 70 + 70;

        // show the find panel
        const required_size: f32 = s.x - find_area_min_width;
        if (required_size > 0) {
            const gap = 5;
            const textfield_width = s.x - find_area_button_size - gap * 2;
            imgui.igPushItemWidth(textfield_width);
            anim.search_ed_active = imgui.igInputTextWithHint("##search", "search term...", anim.search_term, anim.search_term_size, 0, null, null);
            imgui.igSetCursorPos(.{ .x = editor_pos.x + textfield_width + gap, .y = editor_pos.y });
            if (imgui.igButton("Search!", .{ .x = find_area_button_size - gap, .y = 35 })) {
                // TODO: replaced lenZ
                if (std.mem.len(anim.search_term) > 0) {
                    // DO SEARCH
                    std.log.debug("Search term is: {s}", .{anim.search_term});
                    const shit: []u8 = std.mem.span(anim.textbuf);
                    const fuck: []u8 = std.mem.span(anim.search_term);
                    if (std.mem.indexOfPos(u8, shit, anim.current_search_pos, fuck)) |foundindex| {
                        // found, now highlight the search result and jump cursor there
                        anim.jumpToPosAndHighlightLine(foundindex, true);
                        anim.current_search_pos = foundindex + 1;
                    } else {
                        // no (more) finds
                        // if we have to wrap:
                        if (anim.current_search_pos > 0) { // we hadn't started from the beginning
                            anim.current_search_pos = 0;
                            if (std.mem.indexOfPos(u8, shit, anim.current_search_pos, fuck)) |foundindex| {
                                // found, now highlight the search result and jump cursor there
                                anim.jumpToPosAndHighlightLine(foundindex, true);
                                anim.current_search_pos = foundindex + 1;
                            } else {
                                anim.current_search_pos = 0;
                            }
                        }
                    }
                }
            }
        }

        // on with the editor, shift it down by find_area_height
        imgui.igSetCursorPos(.{ .x = editor_pos.x, .y = find_area_height + pos.y });

        s.y = size.y - grow_shrink_button_panel_height - find_area_height;
        var error_panel_height = s.y * 0.15; // reserve the last quarter for shit
        var show_error_panel = false;
        var parser_errors: *std.ArrayList(parser.ParserErrorContext) = undefined;
        var num_visible_error_lines: c_int = 0;
        var text_line_height = imgui.igGetTextLineHeightWithSpacing();
        if (anim.parser_context) |ctx| {
            parser_errors = &ctx.parser_errors;
            if (parser_errors.items.len > 0) {
                show_error_panel = true;
                my_fonts.pushGuiFont(1);
                // .
                my_fonts.popGuiFont();
                num_visible_error_lines = @floatToInt(c_int, error_panel_height / text_line_height);
                if (num_visible_error_lines > parser_errors.items.len) {
                    num_visible_error_lines = @intCast(c_int, parser_errors.items.len);
                }
                s.y -= text_line_height * @intToFloat(f32, num_visible_error_lines + 1) + 2;
            }
        }

        // show the editor
        var flags = imgui.ImGuiInputTextFlags_Multiline | imgui.ImGuiInputTextFlags_AllowTabInput | imgui.ImGuiInputTextFlags_CallbackAlways;
        var x_anim: *EditAnim = anim;
        imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_TextSelectedBg, .{ .x = 1, .w = 0.9 });
        imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_Text, .{ .x = 1, .y = 1, .z = 1, .w = 1 });
        const ret = imgui.igInputTextMultiline("editor", anim.textbuf, anim.textbuf_size, imgui.ImVec2{ .x = s.x, .y = s.y }, flags, my_callback, @ptrCast(*anyopaque, x_anim));
        imgui.igPopStyleColor(2);

        // show the resize button
        //
        const resize_bt_height = content_window_size.y / 10;
        const resize_bt_pos = imgui.ImVec2{ .x = pos.x, .y = (content_window_size.y - resize_bt_height) / 2 };
        imgui.igSetCursorPos(resize_bt_pos);
        const resize_ret = animatedButton("     resize", .{ .x = anim.slide_button_width, .y = resize_bt_height }, &anim.resize_button_anim);
        if (resize_ret == .pressed or anim.in_resize_mode) {
            var mouse_pos: imgui.ImVec2 = undefined;
            imgui.igGetMousePos(&mouse_pos);
            if (anim.resize_mouse_x > 0) {
                anim.current_size.x -= mouse_pos.x - anim.resize_mouse_x;
                if (anim.current_size.x > internal_render_size.x - 300) {
                    anim.current_size.x = internal_render_size.x - 300;
                }
                if (anim.current_size.x < 50) {
                    anim.current_size.x = 50;
                }
            }
            anim.resize_mouse_x = mouse_pos.x;
            anim.in_resize_mode = true;
        }
        if (resize_ret == .released or imgui.igIsAnyMouseDown() == false) {
            anim.in_resize_mode = false;
            anim.resize_mouse_x = 0;
        }

        if (show_error_panel) {
            imgui.igSetCursorPos(imgui.ImVec2{ .x = editor_pos.x, .y = s.y + 2 + find_area_height + pos.y });
            imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_Text, .{ .x = 0.95, .y = 0.95, .w = 0.99 });
            imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_FrameBg, .{ .x = 0, .y = 0.1, .z = 0.2, .w = 0.5 });
            const item_array = try anim.parser_context.?.allErrorsToCstrArray(anim.parser_context.?.allocator);

            my_fonts.pushGuiFont(1);
            imgui.igPushItemWidth(-1);
            if (imgui.igListBox_Str_arr("Errors", &anim.selected_error, item_array, @intCast(c_int, parser_errors.items.len), num_visible_error_lines + 1)) {
                // an error was selected
                anim.jumpToPosAndHighlightLine(parser_errors.items[@intCast(usize, anim.selected_error)].line_offset, true);
            }
            imgui.igPopItemWidth();
            my_fonts.popGuiFont();
            imgui.igPopStyleColor(2);
        }

        // the dummy button is necessary so we have something to activate after flashing the editor
        // to get out of the editor - or else it would suddenly start consuming keystrokes
        imgui.igSetCursorPos(.{ .x = pos.x, .y = 20 }); // below menu bar
        imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_Button, .{ .w = 0 });
        _ = imgui.igButton("dummy", .{ .x = 2, .y = 2 });
        imgui.igPopStyleColor(1);
        return ret;
    }
    return false;
}

fn trxy(pos: imgui.ImVec2, content_window_size: imgui.ImVec2, internal_render_size: imgui.ImVec2) imgui.ImVec2 {
    return imgui.ImVec2{ .x = pos.x * content_window_size.x / internal_render_size.x, .y = pos.y * content_window_size.y / internal_render_size.y };
}

pub fn animateColor(from: imgui.ImVec4, to: imgui.ImVec4, duration_ms: i32, ticker_ms: u32) imgui.ImVec4 {
    if (ticker_ms >= duration_ms) {
        return to;
    }
    if (ticker_ms <= 1) {
        return from;
    }

    var ret = from;
    var fduration_ms = @intToFloat(f32, duration_ms);
    var fticker_ms = @intToFloat(f32, ticker_ms);
    ret.x += (to.x - from.x) / fduration_ms * fticker_ms;
    ret.y += (to.y - from.y) / fduration_ms * fticker_ms;
    ret.z += (to.z - from.z) / fduration_ms * fticker_ms;
    ret.w += (to.w - from.w) / fduration_ms * fticker_ms;
    return ret;
}

pub fn doButton(label: [*c]const u8, size: imgui.ImVec2, dir: i32) ButtonState {
    var released: bool = false;

    if (dir == -1) {
        // normal button
        released = imgui.igButton(label, size);
    } else {
        // arrow button
        released = imgui.igArrowButton(label, dir);
    }

    if (released) return .released;
    if (imgui.igIsItemActive() and imgui.igIsItemHovered(imgui.ImGuiHoveredFlags_RectOnly)) return .pressed;
    if (imgui.igIsItemHovered(imgui.ImGuiHoveredFlags_RectOnly)) return .hovered;
    return .none;
}

pub fn animatedButton(label: [*c]const u8, size: imgui.ImVec2, anim: *ButtonAnim) ButtonState {
    var fromColor = imgui.ImVec4{};
    var toColor = imgui.ImVec4{};
    switch (anim.prevState) {
        .none => fromColor = imgui.igGetStyleColorVec4(imgui.ImGuiCol_Button).*,
        .hovered => fromColor = imgui.igGetStyleColorVec4(imgui.ImGuiCol_ButtonHovered).*,
        .pressed => fromColor = imgui.igGetStyleColorVec4(imgui.ImGuiCol_ButtonActive).*,
        .released => fromColor = imgui.igGetStyleColorVec4(imgui.ImGuiCol_ButtonActive).*,
    }

    switch (anim.currentState) {
        .none => toColor = imgui.igGetStyleColorVec4(imgui.ImGuiCol_Button).*,
        .hovered => toColor = imgui.igGetStyleColorVec4(imgui.ImGuiCol_ButtonHovered).*,
        .pressed => toColor = imgui.igGetStyleColorVec4(imgui.ImGuiCol_ButtonActive).*,
        .released => toColor = imgui.igGetStyleColorVec4(imgui.ImGuiCol_ButtonActive).*,
    }

    var anim_duration: i32 = 0;
    switch (anim.currentState) {
        .hovered => anim_duration = anim.hover_duration,
        .pressed => anim_duration = anim.press_duration,
        .released => anim_duration = anim.release_duration,
        else => anim_duration = anim.hover_duration,
    }
    if (anim.prevState == .released) anim_duration = anim.release_duration;

    var currentColor = animateColor(fromColor, toColor, anim_duration, anim.ticker_ms);
    imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_Button, currentColor);
    imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_ButtonHovered, currentColor);
    imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_ButtonActive, currentColor);
    var state = doButton(label, size, anim.arrow_dir);
    imgui.igPopStyleColor(3);

    anim.ticker_ms += @floatToInt(u32, frame_dt * 1000);
    if (state != anim.currentState) {
        anim.prevState = anim.currentState;
        anim.currentState = state;
        anim.ticker_ms = 0;
    }
    anim.current_color = currentColor;
    return state;
}

pub const MsgAnimState = enum {
    none,
    fadein,
    keep,
    fadeout,
};

pub const MsgAnim = struct {
    ticker_ms: u32 = 0,
    fadein_duration: i32 = 300,
    fadeout_duration: i32 = 300,
    keep_duration: i32 = 800,
    current_color: imgui.ImVec4 = imgui.ImVec4{},
    anim_state: MsgAnimState = .none,
};

pub fn showMsg(msg: [*c]const u8, pos: imgui.ImVec2, flyin_pos: imgui.ImVec2, color: imgui.ImVec4, anim: *MsgAnim) void {
    var from_color = imgui.ImVec4{};
    var to_color = imgui.ImVec4{};
    const hide_color = imgui.ImVec4{};
    var duration: i32 = 0;
    var the_pos = pos;

    const backdrop_color = imgui.ImVec4{ .x = 0x80 / 255.0, .y = 0x80 / 255.0, .z = 0x80 / 255.0, .w = 1 };
    var current_backdrop_color = backdrop_color;

    switch (anim.anim_state) {
        .none => return,
        .fadein => {
            from_color = hide_color;
            to_color = color;
            duration = anim.fadein_duration;
            anim.current_color = animateColor(from_color, to_color, duration, anim.ticker_ms);
            current_backdrop_color = animateColor(hide_color, backdrop_color, duration, anim.ticker_ms);
            the_pos = animateVec2(flyin_pos, pos, duration, anim.ticker_ms);
            anim.ticker_ms += @floatToInt(u32, frame_dt * 1000);
            if (anim.ticker_ms > anim.fadein_duration) {
                anim.anim_state = .keep;
                anim.ticker_ms = 0;
            }
        },
        .fadeout => {
            from_color = color;
            to_color = hide_color;
            duration = anim.fadeout_duration;
            anim.current_color = animateColor(from_color, to_color, duration, anim.ticker_ms);
            current_backdrop_color = animateColor(backdrop_color, hide_color, @divTrunc(duration, 2), anim.ticker_ms);
            anim.ticker_ms += @floatToInt(u32, frame_dt * 1000);
            if (anim.ticker_ms > anim.fadeout_duration) {
                anim.anim_state = .none;
                anim.ticker_ms = 0;
            }
        },
        .keep => {
            anim.current_color = color;
            current_backdrop_color = backdrop_color;
            anim.ticker_ms += @floatToInt(u32, frame_dt * 1000);
            if (anim.ticker_ms > anim.keep_duration) {
                anim.anim_state = .fadeout;
                anim.ticker_ms = 0;
            }
        },
    }

    // backdrop text
    var offset_1 = the_pos;
    the_pos.x -= 1;
    the_pos.y -= 1;
    imgui.igSetCursorPos(offset_1);
    imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_Text, current_backdrop_color);
    imgui.igText(msg);
    imgui.igPopStyleColor(1);

    // the actual msg
    imgui.igSetCursorPos(the_pos);
    imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_Text, anim.current_color);
    imgui.igText(msg);
    imgui.igPopStyleColor(1);
}

// auto run through the presentation
pub const AutoRunAnim = struct {
    running: bool = false,
    ticker_ms: u32 = 0,
    slide_duration: i32 = 200,
    screenshot_duration: i32 = 200,
    flag_switch_slide: bool = false,
    flag_in_screenshot: bool = false,
    flag_start_screenshot: bool = false,

    pub fn animate(self: *AutoRunAnim) void {
        if (!self.running)
            return;

        self.flag_switch_slide = false;
        self.flag_start_screenshot = false;

        self.ticker_ms += @floatToInt(u32, frame_dt * 1000);
        if (self.flag_in_screenshot) {
            self.flag_start_screenshot = false;
            if (self.ticker_ms >= self.screenshot_duration) {
                self.ticker_ms = 0;
                self.flag_switch_slide = true;
                self.flag_in_screenshot = false;
            }
        } else if (self.ticker_ms >= self.slide_duration) {
            self.ticker_ms = 0;
            self.flag_in_screenshot = true;
            self.flag_start_screenshot = true;
        }
    }

    pub fn toggle(self: *AutoRunAnim) bool {
        self.running = !self.running;
        if (!self.running) {
            self.stop();
        }
        return self.running;
    }

    pub fn start(self: *AutoRunAnim) void {
        self.running = true;
    }

    pub fn stop(self: *AutoRunAnim) void {
        self.running = false;
        self.flag_start_screenshot = false;
        self.flag_in_screenshot = false;
        self.flag_switch_slide = false;
    }

    pub fn is_running(self: *AutoRunAnim) bool {
        return self.running;
    }
};
