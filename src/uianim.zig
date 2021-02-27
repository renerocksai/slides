const std = @import("std");
const upaya = @import("upaya");
usingnamespace upaya.imgui;

// .
// Animation
// .
pub const frame_dt: f32 = 0.016; // roughly 16ms per frame
var ui_key_count: u32 = 0;
pub fn nextUiKey() u32 {
    ui_key_count += 1;
    return ui_key_count;
}

pub const ButtonState = enum {
    none = 0,
    hovered,
    pressed,
    released,
};

// doButton(label, size)
// see https://github.com/ocornut/imgui/issues/777
// you could use it like this:
//        currentColor = ... depending on current button state
//        ImGui::PushStyleColor(ImGuiCol_Button, currentColor);
//        ImGui::PushStyleColor(ImGuiCol_ButtonActive, currentColor);
//        ImGui::PushStyleColor(ImGuiCol_ButtonHovered, currentColor);
//        auto state = doButton("Press Me", size);
//        ImGui::PopStyleColor(3);
pub fn doButton(label: [*c]const u8, size: ImVec2) ButtonState {
    var released = igButton(label, size);

    if (released) return .released;
    if (igIsItemActive() and igIsItemHovered(ImGuiHoveredFlags_RectOnly)) return .pressed;
    if (igIsItemHovered(ImGuiHoveredFlags_RectOnly)) return .hovered;
    return .none;
}

pub const ButtonAnim = struct {
    ticker_ms: u32 = 0,
    prevState: ButtonState = .none,
    currentState: ButtonState = .none,
    hover_duration: i32 = 200,
    press_duration: i32 = 100,
    release_duration: i32 = 100,
    current_color: ImVec4 = ImVec4{},
};

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
    var state = doButton(label, size);
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
