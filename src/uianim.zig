const std = @import("std");
const upaya = @import("upaya");
const parser = @import("parser.zig");
const my_fonts = @import("myscalingfonts.zig");
usingnamespace upaya.imgui;

// .
// Animation
// .
pub const frame_dt: f32 = 0.016; // roughly 16ms per frame

pub const ButtonState = enum {
    none = 0,
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
    current_color: ImVec4 = ImVec4{},
    arrow_dir: i32 = -1,
};

// pub const ImGuiInputTextCallback = ?fn ([*c]ImGuiInputTextCallbackData) callconv(.C) c_int;

pub fn my_callback(data: [*c]ImGuiInputTextCallbackData) callconv(.C) c_int {
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
        }
        x.editAction = null;
    }

    return 0;
}

pub const EditAnim = struct {
    visible: bool = false,
    visible_prev: bool = false,
    current_size: ImVec2 = ImVec2{},
    desired_size: ImVec2 = .{ .x = 600, .y = 0 },
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
    resize_button_anim: ButtonAnim = .{},
    resize_mouse_x: f32 = 0,
    in_resize_mode: bool = false,

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
        self.editAction = .{
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
        igActivateItem(igGetIDStr("editor")); // TODO move ID str into struct
    }
    pub fn startFlashAnimation(self: *EditAnim) void {
        self.ticker_ms = 0;
        self.in_flash_editor_animation = true;
    }
};

const EditActionData = struct {
    jump_to_cursor_pos: usize = 0,
    highlight_line: bool = false,
};

pub fn animateVec2(from: ImVec2, to: ImVec2, duration_ms: i32, ticker_ms: u32) ImVec2 {
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

pub fn animateX(from: ImVec2, to: ImVec2, duration_ms: i32, ticker_ms: u32) ImVec2 {
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
pub fn animatedEditor(anim: *EditAnim, content_window_size: ImVec2, internal_render_size: ImVec2) !bool {
    var fromSize = ImVec2{};
    var toSize = ImVec2{};
    var anim_duration: i32 = 0;
    var show: bool = true;

    var size = anim.desired_size;

    var editor_pos = ImVec2{};
    var pos = ImVec2{};
    pos.x = internal_render_size.x - anim.current_size.x;
    pos.x *= internal_render_size.x / content_window_size.x;
    editor_pos = pos;
    editor_pos.x += anim.slide_button_width;

    if (anim.textbuf == null) {
        var allocator = std.heap.page_allocator;
        const memory = try allocator.alloc(u8, anim.textbuf_size);
        anim.textbuf = memory.ptr;
        anim.textbuf[0] = 0;
    }
    // only animate when transitioning
    if (anim.visible != anim.visible_prev) {
        if (anim.visible) {
            // fading in
            if (!anim.in_grow_shrink_animation) {
                fromSize = ImVec2{};
            } else {
                fromSize.x = anim.grow_shrink_from_width;
            }
            fromSize.y = size.y;
            toSize = size;
            anim_duration = anim.fadein_duration;
        } else {
            fromSize = size;
            if (!anim.in_grow_shrink_animation) {
                toSize = ImVec2{};
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
            anim.activate();
            //std.log.debug("flashing editor {}", .{anim.ticker_ms});
            if (anim.ticker_ms > anim.flash_editor_duration) {
                anim.in_flash_editor_animation = false;
                igActivateItem(igGetIDStr("dummy"));
                //std.log.debug("un-flashing editor {}", .{anim.ticker_ms});
            }
        } else {
            anim.ticker_ms = 0;
            if (!anim.visible) {
                show = false;
            }
        }
    }

    if (show) {
        igSetCursorPos(editor_pos);
        var s: ImVec2 = trxy(anim.current_size, content_window_size, internal_render_size);
        const grow_shrink_button_panel_height = 0; // 22;
        s.y = size.y - grow_shrink_button_panel_height;
        var error_panel_height = s.y * 0.15; // reserve the last quarter for shit
        const error_panel_fontsize: i32 = 14;

        var show_error_panel = false;
        var parser_errors: *std.ArrayList(parser.ParserErrorContext) = undefined;
        var num_visible_error_lines: c_int = 0;
        var text_line_height = igGetTextLineHeightWithSpacing();
        if (anim.parser_context) |ctx| {
            parser_errors = &ctx.parser_errors;
            if (parser_errors.items.len > 0) {
                show_error_panel = true;
                my_fonts.pushFontScaled(error_panel_fontsize);
                // .
                my_fonts.popFontScaled();
                num_visible_error_lines = @floatToInt(c_int, error_panel_height / text_line_height);
                // std.log.info("Text line height is {d} --> {d} of {d} lines will fit in {d:.0}", .{ text_line_height, num_visible_error_lines, parser_errors.items.len, error_panel_height });
                if (num_visible_error_lines > parser_errors.items.len) {
                    num_visible_error_lines = @intCast(c_int, parser_errors.items.len);
                }
                s.y -= text_line_height * @intToFloat(f32, num_visible_error_lines) + 2;
            }
        }

        // show the editor
        var flags = ImGuiInputTextFlags_Multiline | ImGuiInputTextFlags_AllowTabInput | ImGuiInputTextFlags_CallbackAlways;
        var x_anim: *EditAnim = anim;
        igPushStyleColorVec4(ImGuiCol_TextSelectedBg, .{ .x = 1, .w = 0.9 });
        const ret = igInputTextMultiline("editor", anim.textbuf, anim.textbuf_size, ImVec2{ .x = s.x, .y = s.y }, flags, my_callback, @ptrCast(*c_void, x_anim));
        igPopStyleColor(1);

        // show the resize button
        //
        const resize_bt_height = content_window_size.y / 10;
        const resize_bt_pos = ImVec2{ .x = pos.x, .y = (content_window_size.y - resize_bt_height) / 2 };
        igSetCursorPos(resize_bt_pos);
        const resize_ret = animatedButton("     resize", .{ .x = anim.slide_button_width, .y = resize_bt_height }, &anim.resize_button_anim);
        if (resize_ret == .pressed or anim.in_resize_mode) {
            var mouse_pos: ImVec2 = undefined;
            igGetMousePos(&mouse_pos);
            std.log.debug("mouse_pos: {d:.0}", .{mouse_pos.x});
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
        if (resize_ret == .released or igIsAnyMouseDown() == false) {
            anim.in_resize_mode = false;
            anim.resize_mouse_x = 0;
        }

        if (show_error_panel) {
            igSetCursorPos(ImVec2{ .x = editor_pos.x, .y = s.y + 2 });
            igPushStyleColorVec4(ImGuiCol_Text, .{ .x = 0.95, .y = 0.95, .w = 0.99 });
            igPushStyleColorVec4(ImGuiCol_FrameBg, .{ .x = 0, .y = 0.1, .z = 0.2, .w = 0.5 });
            var selected: c_int = 0;
            const item_array = try anim.parser_context.?.allErrorsToCstrArray(anim.parser_context.?.allocator);

            my_fonts.pushFontScaled(error_panel_fontsize);
            if (igListBoxStr_arr("Errors", &anim.selected_error, item_array, @intCast(c_int, parser_errors.items.len), num_visible_error_lines + 1)) {
                // TODO: an error was selected
                anim.jumpToPosAndHighlightLine(parser_errors.items[@intCast(usize, anim.selected_error)].line_offset, true);
            }
            my_fonts.popFontScaled();
            igPopStyleColor(2);
            // igSetCursorPos(ImVec2{ .x = pos.x, .y = s.y + 2 });
            // _ = igButton("CHECK", .{ .x = 100, .y = @intToFloat(f32, num_visible_error_lines) * text_line_height });
        }

        // maybe do sth below: buttons or stuff
        // get real editor size
        if (false) {
            s = trxy(ImVec2{ .x = anim.current_size.x, .y = 0 }, content_window_size, internal_render_size);
            const real_ed_w = s.x;
            const bt_width = s.x / 2; //50;
            s.x = content_window_size.x - real_ed_w;
            s.y = size.y - grow_shrink_button_panel_height;
            igSetCursorPos(s);
            if (animatedButton("<", .{ .x = bt_width, .y = 20 }, &bt_grow_anim) == .released) {
                anim.grow();
            }
            s.x += bt_width;
            igSetCursorPos(s);
            if (animatedButton(">", .{ .x = bt_width, .y = 20 }, &bt_shrink_anim) == .released) {
                anim.shrink();
            }
        }
        _ = igButton("dummy", .{ .x = 1, .y = 1 });
        return ret;
    }
    return false;
}

fn trxy(pos: ImVec2, content_window_size: ImVec2, internal_render_size: ImVec2) ImVec2 {
    return ImVec2{ .x = pos.x * content_window_size.x / internal_render_size.x, .y = pos.y * content_window_size.y / internal_render_size.y };
}

pub fn animateColor(from: ImVec4, to: ImVec4, duration_ms: i32, ticker_ms: u32) ImVec4 {
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

pub fn doButton(label: [*c]const u8, size: ImVec2, dir: i32) ButtonState {
    var released: bool = false;

    if (dir == -1) {
        // normal button
        released = igButton(label, size);
    } else {
        // arrow button
        released = igArrowButton(label, dir);
    }

    if (released) return .released;
    if (igIsItemActive() and igIsItemHovered(ImGuiHoveredFlags_RectOnly)) return .pressed;
    if (igIsItemHovered(ImGuiHoveredFlags_RectOnly)) return .hovered;
    return .none;
}

pub fn animatedButton(label: [*c]const u8, size: ImVec2, anim: *ButtonAnim) ButtonState {
    var fromColor = ImVec4{};
    var toColor = ImVec4{};
    switch (anim.prevState) {
        .none => fromColor = igGetStyleColorVec4(ImGuiCol_Button).*,
        .hovered => fromColor = igGetStyleColorVec4(ImGuiCol_ButtonHovered).*,
        .pressed => fromColor = igGetStyleColorVec4(ImGuiCol_ButtonActive).*,
        .released => fromColor = igGetStyleColorVec4(ImGuiCol_ButtonActive).*,
    }

    switch (anim.currentState) {
        .none => toColor = igGetStyleColorVec4(ImGuiCol_Button).*,
        .hovered => toColor = igGetStyleColorVec4(ImGuiCol_ButtonHovered).*,
        .pressed => toColor = igGetStyleColorVec4(ImGuiCol_ButtonActive).*,
        .released => toColor = igGetStyleColorVec4(ImGuiCol_ButtonActive).*,
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
    igPushStyleColorVec4(ImGuiCol_Button, currentColor);
    igPushStyleColorVec4(ImGuiCol_ButtonHovered, currentColor);
    igPushStyleColorVec4(ImGuiCol_ButtonActive, currentColor);
    var state = doButton(label, size, anim.arrow_dir);
    igPopStyleColor(3);

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
    current_color: ImVec4 = ImVec4{},
    anim_state: MsgAnimState = .none,
};

pub fn showMsg(msg: [*c]const u8, pos: ImVec2, flyin_pos: ImVec2, color: ImVec4, anim: *MsgAnim) void {
    var from_color = ImVec4{};
    var to_color = ImVec4{};
    const hide_color = ImVec4{};
    var duration: i32 = 0;
    var the_pos = pos;

    const backdrop_color = ImVec4{ .x = 0x80 / 255.0, .y = 0x80 / 255.0, .z = 0x80 / 255.0, .w = 1 };
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
    igSetCursorPos(offset_1);
    igPushStyleColorVec4(ImGuiCol_Text, current_backdrop_color);
    igText(msg);
    igPopStyleColor(1);

    // the actual msg
    igSetCursorPos(the_pos);
    igPushStyleColorVec4(ImGuiCol_Text, anim.current_color);
    igText(msg);
    igPopStyleColor(1);
}
