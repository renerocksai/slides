const std = @import("std");
const ig = @import("imgui");

pub fn rene() void {
    std.log.info("hello, world", .{});
}

pub const IGFD_Selection_Pair = extern struct {
    fileName: [*c]u8,
    filePathName: [*c]u8,
};
pub const IGFD_Selection = extern struct {
    table: [*]IGFD_Selection_Pair,
    count: usize,
};

pub const ImGuiFileDialogFlags = enum(c_int) {
    None = 0, // define none default flag
    ConfirmOverwrite = (1 << 0), // show confirm to overwrite dialog
    DontShowHiddenFiles = (1 << 1), // dont show hidden file (file starting with a .)
    DisableCreateDirectoryButton = (1 << 2), // disable the create directory button
    HideColumnType = (1 << 3), // hide column file type
    HideColumnSize = (1 << 4), // hide column file size
    HideColumnDate = (1 << 5), // hide column file date
    NoDialog = (1 << 6), // let the dialog embedded in your own imgui begin / end scope
    ReadOnlyFileNameField = (1 << 7), // don't let user type in filename field for file open style dialogs
    CaseInsensitiveExtention = (1 << 8), // the file extentions treatments will not take into account the case
    DisableThumbnailMode = (1 << 9), // disable the thumbnail mode
    DisableBookmarkMode = (1 << 10), // disable the bookmark mode
};

pub extern fn IGFD_Selection_Pair_Get() IGFD_Selection_Pair;
pub extern fn IGFD_Create() *anyopaque;
pub extern fn IGFD_OpenDialog(
    vContext: *anyopaque,
    vKey: [*c]const u8,
    vTitle: [*c]const u8,
    vFilters: [*c]const u8,
    vPath: [*c]const u8,
    vFileName: [*c]const u8,
    vCountSelectionMax: c_int,
    vUserDatas: ?*anyopaque,
    vFlags: c_int,
) void;

pub extern fn IGFD_OpenDialog2(
    vContext: *anyopaque,
    vKey: [*c]const u8,
    vTitle: [*c]const u8,
    vFilters: [*c]const u8,
    vPath: [*c]const u8,
    vFileName: [*c]const u8,
    vCountSelectionMax: c_int,
    vUserDatas: *anyopaque,
    vFlags: c_int,
) void;

pub extern fn IGFD_OpenModal(
    vContext: *anyopaque,
    vKey: [*c]const u8,
    vTitle: [*c]const u8,
    vFilters: [*c]const u8,
    vPath: [*c]const u8,
    vFileName: [*c]const u8,
    vCountSelectionMax: c_int,
    vUserDatas: *anyopaque,
    vFlags: c_int,
) void;

pub extern fn IGFD_OpenModal2(
    vContext: *anyopaque,
    vKey: [*c]const u8,
    vTitle: [*c]const u8,
    vFilters: [*c]const u8,
    vPath: [*c]const u8,
    vFileName: [*c]const u8,
    vCountSelectionMax: c_int,
    vUserDatas: ?*anyopaque,
    vFlags: c_int,
) void;

pub extern fn IGFD_DisplayDialog(
    vContext: *anyopaque,
    vKey: [*c]const u8,
    vFlags: c_int, // ImGuiWindowFlags
    vMinSize: ig.ImVec2,
    vMaxSize: ig.ImVec2,
) bool;

pub extern fn IGFD_IsOk(vContext: *anyopaque) bool;
pub extern fn IGFD_GetFilePathName(vContext: *anyopaque) [*c]u8;
pub extern fn IGFD_GetCurrentPath(vContext: *anyopaque) [*c]u8;
pub extern fn IGFD_GetCurrentFilter(vContext: *anyopaque) [*c]u8;
pub extern fn IGFD_GetSelection(vContext: *anyopaque) IGFD_Selection;
pub extern fn IGFD_Selection_DestroyContent(selection: *const IGFD_Selection) void;
pub extern fn IGFD_CloseDialog(vContext: *anyopaque) void;
pub extern fn IGFD_Destroy(vContext: *const anyopaque) void;

fn castaway_const(ptr: *const anyopaque) *anyopaque {
    return (@intToPtr(*anyopaque, @ptrToInt(ptr)));
}

pub fn openDlg(cfiledialog: *anyopaque) void {
    IGFD_OpenDialog(cfiledialog, "filedlg", "Open a File", // dialog title
        "slide files(*.sld){.sld}", // dialog filter syntax : simple => .h,.c,.pp, etc and collections : text1{filter0,filter1,filter2}, text2{filter0,filter1,filter2}, etc..
        ".", // base directory for files scan
        "", // base filename
        0, // count selection : 0 infinite, 1 one file (default), n (n files)
        @intToPtr(?*anyopaque, 0), @enumToInt(ImGuiFileDialogFlags.ConfirmOverwrite)
    // | @enumToInt(ImGuiFileDialogFlags.ImGuiFileDialogFlags_NoDialog),
    );
}
pub fn displayDialog(cfiledialog: *anyopaque) bool {
    const maxSize = ig.ImVec2{ .x = 800, .y = 400 };
    const minSize = ig.ImVec2{ .x = 400, .y = 200 };

    // display dialog
    const bb = IGFD_DisplayDialog(cfiledialog, "filedlg", ig.ImGuiWindowFlags_NoCollapse, minSize, maxSize);
    if (bb) {
        const xx = IGFD_IsOk(cfiledialog); // result ok
        std.log.debug("ok dialog: {}", .{xx});
        {
            const cfilePathName = IGFD_GetFilePathName(cfiledialog);
            std.log.debug("GetFilePathName : {s}\n", .{cfilePathName});

            const cfilePath = IGFD_GetCurrentPath(cfiledialog);
            std.log.debug("GetCurrentPath : {s}\n", .{cfilePath});

            const cfilter = IGFD_GetCurrentFilter(cfiledialog);
            std.log.debug("GetCurrentFilter : {s}\n", .{cfilter});

            const csel = IGFD_GetSelection(cfiledialog); // multi selection
            std.log.debug("Selection:", .{});
            {
                var i: usize = 0;
                while (i < csel.count) : (i += 1) {
                    std.log.debug("({d}) FileName {s} => path {s}\n", .{ i, csel.table[i].fileName, csel.table[i].filePathName });
                }
            }
            // action

            // destroy
            // if (cfilePathName) free(cfilePathName);
            // if (cfilePath) free(cfilePath);
            // if (cfilter) free(cfilter);

            // IGFD_Selection_DestroyContent(&csel);
            IGFD_CloseDialog(cfiledialog);

            // destroy ImGuiFileDialog
            // IGFD_Destroy(cfiledialog);
        }
    }
    return bb;
}
