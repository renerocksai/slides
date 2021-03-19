const std = @import("std");
const upaya = @import("upaya");
usingnamespace upaya.imgui;

/// We aim at the following Markdown dialect:
///
/// Normal text.
/// Some **bold** text and some _italic_ text.
/// The combination is **_bold italic_** text or _**bold italic**_.
/// - a bulleted item
/// Some ~underlined~ text.
///
/// Colors <#rrggbbaa>this is colored</>
///
/// ~**_underlined bold italic text_**~.
///
pub const StyleFlags = struct {
    pub const none = 0;
    pub const bold = 1;
    pub const italic = 2;
    pub const underline = 4;
    pub const line_bulleted = 8;
    pub const colored = 16;
};

pub const MdTextSpan = struct {
    startpos: usize = 0,
    endpos: usize = 0,
    styleflags: u8 = 0,
    color_override: ?ImVec4 = null,
    text: ?[]const u8 = null,
};

pub const MdParsingError = error{color};

fn parseColorLiteral(colorstr: []const u8) !ImVec4 {
    var ret = ImVec4{};
    if (colorstr[0] != '#') {
        return MdParsingError.color;
    }
    var temp: ImVec4 = undefined;
    var coloru32 = std.fmt.parseInt(c_uint, colorstr[1..9], 16) catch |err| {
        return MdParsingError.color;
    };
    igColorConvertU32ToFloat4(&temp, coloru32);
    ret.x = temp.w;
    ret.y = temp.z;
    ret.z = temp.y;
    ret.w = temp.x;
    return ret;
}

pub const MdLineParser = struct {
    allocator: *std.mem.Allocator = undefined,
    currentSpan: MdTextSpan = .{},
    result_spans: ?std.ArrayList(MdTextSpan) = null,

    pub fn init(self: *MdLineParser, allocator: *std.mem.Allocator) void {
        if (self.result_spans) |spans| {
            self.result_spans.?.shrinkRetainingCapacity(0);
        } else {
            self.result_spans = std.ArrayList(MdTextSpan).init(allocator);
        }
        self.allocator = allocator;
    }

    fn makeCstr(self: *MdLineParser, t: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "{s}", .{t});
    }

    // bold, italic, underline starts must be preceded by one of " _*~"
    // bold, italic, underline ends must not be preceded by a space.
    pub fn parseLine(self: *MdLineParser, line: []const u8) !void {
        var pos: usize = 0;

        if (std.mem.startsWith(u8, std.mem.trimLeft(u8, line, " \t"), "-")) {
            self.currentSpan.styleflags |= StyleFlags.line_bulleted;
        }

        while (pos < line.len) {
            switch (line[pos]) {
                '*' => {
                    if (self.currentSpan.styleflags & StyleFlags.bold > 0) {
                        // try to terminate bold
                        if (peekAhead(line, pos, 1)) |ahead| {
                            if (ahead == '*') {
                                // make sure we weren't preceded by a space
                                if (peekBack(line, pos, 1)) |prev| {
                                    if (prev != ' ') {
                                        self.currentSpan.endpos = pos;
                                        try self.emitCurrentSpan(line);

                                        // clear bold
                                        self.currentSpan.styleflags &= 0xff - StyleFlags.bold;
                                        self.currentSpan.startpos = pos + 2;
                                        self.currentSpan.endpos = 0;
                                        pos += 1; // skip the 2nd terminator
                                    }
                                }
                            }
                        }
                    } else {
                        // try to start bold:
                        // must be followed by 2nd *
                        // must eventually be followed by ** in the future
                        // those ** must not be preceded by a space
                        // if started: switch on bold flag
                        if (peekAhead(line, pos, 1)) |next| {
                            if (next == '*') {
                                if (std.mem.indexOf(u8, line[pos + 1 ..], "**")) |term_pos_relative| {
                                    if (term_pos_relative > 1) {
                                        // check if terminator is preceded by space
                                        if (peekBack(line, pos + 1 + term_pos_relative, 1)) |nospace| {
                                            if (nospace != ' ') {
                                                self.currentSpan.endpos = pos;
                                                try self.emitCurrentSpan(line);

                                                // change style of new span
                                                self.currentSpan.styleflags |= StyleFlags.bold;
                                                self.currentSpan.startpos = pos + 2;
                                                self.currentSpan.endpos = 0;
                                                pos += 1;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                },
                '~' => {
                    if (self.currentSpan.styleflags & StyleFlags.underline > 0) {
                        // try to terminate underline
                        if (peekAhead(line, pos, 1)) |ahead| {
                            if (ahead == '~') {
                                // make sure we weren't preceded by a space
                                if (peekBack(line, pos, 1)) |prev| {
                                    if (prev != ' ') {
                                        self.currentSpan.endpos = pos;
                                        try self.emitCurrentSpan(line);

                                        // clear underline
                                        self.currentSpan.styleflags &= 0xff - StyleFlags.underline;
                                        self.currentSpan.startpos = pos + 2;
                                        self.currentSpan.endpos = 0;
                                        pos += 1; // skip the 2nd terminator
                                    }
                                }
                            }
                        }
                    } else {
                        // try to start underline:
                        if (peekAhead(line, pos, 1)) |next| {
                            if (next == '~') {
                                if (std.mem.indexOf(u8, line[pos + 1 ..], "~~")) |term_pos_relative| {
                                    if (term_pos_relative > 1) {
                                        // check if terminator is preceded by space
                                        if (peekBack(line, pos + 1 + term_pos_relative, 1)) |nospace| {
                                            if (nospace != ' ') {
                                                self.currentSpan.endpos = pos;
                                                try self.emitCurrentSpan(line);

                                                // change style of new span
                                                self.currentSpan.styleflags |= StyleFlags.underline;
                                                self.currentSpan.startpos = pos + 2;
                                                self.currentSpan.endpos = 0;
                                                pos += 1;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                },
                '_' => {
                    if (self.currentSpan.styleflags & StyleFlags.italic > 0) {
                        // try to terminate italic
                        // make sure we weren't preceded by a space
                        if (peekBack(line, pos, 1)) |prev| {
                            if (prev != ' ') {
                                self.currentSpan.endpos = pos;
                                try self.emitCurrentSpan(line);

                                // clear italic
                                self.currentSpan.styleflags &= 0xff - StyleFlags.italic;
                                self.currentSpan.startpos = pos + 2;
                                self.currentSpan.endpos = 0;
                                pos += 1; // skip the 2nd terminator
                            }
                        }
                    } else {
                        // try to start italic:
                        if (std.mem.indexOf(u8, line[pos + 1 ..], "~")) |term_pos_relative| {
                            if (term_pos_relative > 1) {
                                // check if terminator is preceded by space
                                if (peekBack(line, pos + 1 + term_pos_relative, 1)) |nospace| {
                                    if (nospace != ' ') {
                                        self.currentSpan.endpos = pos;
                                        try self.emitCurrentSpan(line);

                                        // change style of new span
                                        self.currentSpan.styleflags |= StyleFlags.italic;
                                        self.currentSpan.startpos = pos + 2;
                                        self.currentSpan.endpos = 0;
                                        pos += 1;
                                    }
                                }
                            }
                        }
                    }
                },

                '<' => {
                    if (self.currentSpan.styleflags & StyleFlags.colored > 0) {
                        // try to terminate color
                        if (std.mem.startsWith(u8, line[pos..], "</>")) {
                            // make sure we weren't preceded by a space
                            if (peekBack(line, pos, 1)) |prev| {
                                if (prev != ' ') {
                                    // emit current span
                                    self.currentSpan.endpos = pos;
                                    try self.emitCurrentSpan(line);

                                    // clear color
                                    self.currentSpan.styleflags &= 0xff - StyleFlags.colored;
                                    self.currentSpan.startpos = pos + 3;
                                    self.currentSpan.endpos = 0;
                                    self.currentSpan.color_override = null;
                                    pos += 2;
                                }
                            }
                        }
                    } else {
                        // try to start color:
                        if (peekAhead(line, pos, 1)) |next| {
                            if (next == '#') {
                                const color_opt: ?ImVec4 = parseColorLiteral(line[pos + 1 ..]) catch null;
                                if (color_opt) |color| {
                                    if (std.mem.indexOf(u8, line[pos + 1 ..], "</>")) |term_pos_relative| {
                                        // check if terminator is preceded by space
                                        if (peekBack(line, pos + 1 + term_pos_relative, 1)) |nospace| {
                                            if (nospace != ' ') {
                                                self.currentSpan.endpos = pos;
                                                try self.emitCurrentSpan(line);

                                                // change style of new span
                                                self.currentSpan.styleflags |= StyleFlags.colored;
                                                self.currentSpan.color_override = color;
                                                self.currentSpan.startpos = pos + 11;
                                                self.currentSpan.endpos = 0;
                                                pos += 10;
                                            }
                                        }
                                    }
                                } else {
                                    std.log.warn("no color `{s}`", .{line[pos + 1 ..]});
                                }
                            }
                        }
                    }
                },
                else => {},
            }
            pos += 1;
        }
        self.currentSpan.endpos = pos;
        try self.emitCurrentSpan(line);

        return;
    }

    fn emitCurrentSpan(self: *MdLineParser, line: []const u8) !void {
        if (self.currentSpan.endpos == 0 or self.currentSpan.startpos >= line.len or self.currentSpan.endpos - self.currentSpan.startpos < 1) {
            return;
        }

        const span = line[self.currentSpan.startpos..self.currentSpan.endpos];
        self.currentSpan.text = try self.makeCstr(span);
        if (self.result_spans) |spans| {
            try self.result_spans.?.append(self.currentSpan);
        } else {
            self.result_spans = std.ArrayList(MdTextSpan).init(self.allocator);
            try self.result_spans.?.append(self.currentSpan);
        }
    }

    pub fn logSpans(self: *MdLineParser) void {
        if (self.result_spans.?.items.len == 0) {
            return;
        }
        for (self.result_spans.?.items) |span| {
            var bold: []const u8 = "";
            if (span.styleflags & StyleFlags.bold > 0) {
                bold = "bold";
            }

            var italic: []const u8 = "";
            if (span.styleflags & StyleFlags.italic > 0) {
                italic = "italic";
            }

            var underline: []const u8 = "";
            if (span.styleflags & StyleFlags.underline > 0) {
                underline = "underlined";
            }

            var line_bulleted: []const u8 = "";
            if (span.styleflags & StyleFlags.line_bulleted > 0) {
                line_bulleted = "bulleted";
            }

            var colored: []const u8 = "";

            if (span.styleflags & StyleFlags.colored > 0) {
                colored = std.fmt.allocPrint(self.allocator, "color: {}", .{span.color_override}) catch "color";
            }

            std.log.debug("[{}:{}] `{s}` : {s} {s} {s} {s} {s}", .{ span.startpos, span.endpos, span.text, bold, italic, underline, line_bulleted, colored });
        }
    }
};

fn peekAhead(line: []const u8, pos: usize, howmany: usize) ?u8 {
    if (pos + howmany >= line.len) {
        return null;
    }
    return line[pos + howmany];
}

fn peekBack(line: []const u8, pos: usize, howmany: usize) ?u8 {
    if (howmany > pos) {
        return null;
    }
    return line[pos - howmany];
}
