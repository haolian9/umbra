const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;

pub const Cursor = struct {
    pub fn hide(writer: anytype) !void {
        try writer.writeAll("\x1B[?25l");
    }

    pub fn show(writer: anytype) !void {
        try writer.writeAll("\x1B[?25h");
    }

    pub fn up(writer: anytype, n: u16) !void {
        try fmt.format(writer, "\x1B[{d}A", .{n});
    }

    pub fn down(writer: anytype, n: u16) !void {
        try fmt.format(writer, "\x1B[{d}B", .{n});
    }

    pub fn forward(writer: anytype, n: u16) !void {
        try fmt.format(writer, "\x1B[{d}C", .{n});
    }

    pub fn back(writer: anytype, n: u16) !void {
        try fmt.format(writer, "\x1B[{d}D", .{n});
    }

    pub fn up1(writer: anytype) !void {
        try writer.writeAll("\x1BM");
    }

    pub fn goto(writer: anytype, col: u16, row: u16) !void {
        try fmt.format(writer, "\x1B[{d};{d}H", .{ row + 1, col + 1 });
    }

    pub fn save(writer: anytype) !void {
        try writer.writeAll("\x1B[s");
    }

    pub fn restore(writer: anytype) !void {
        try writer.writeAll("\x1B[u");
    }

    pub fn request(writer: anytype) !void {
        try writer.writeAll("\x1B[6n");
    }

    pub fn home(writer: anytype) !void {
        try writer.writeAll("\x1B[H");
    }

    pub fn scrollUp(writer: anytype, n: u16) !void {
        try fmt.format(writer, "\x1B[{d}S", .{n});
    }

    pub fn scrollDown(writer: anytype, n: u16) !void {
        try fmt.format(writer, "\x1B[{d}T", .{n});
    }

    pub fn nextLine(writer: anytype, n: u16) !void {
        try fmt.format(writer, "\x1B[{d}E", .{n});
    }

    pub fn prevLine(writer: anytype, n: u16) !void {
        try fmt.format(writer, "\x1B[{d}F", .{n});
    }
};

pub const Erase = struct {
    pub fn toLineEnd(writer: anytype) !void {
        try writer.writeAll("\x1B[0K");
    }

    pub fn toLineBegin(writer: anytype) !void {
        try writer.writeAll("\x1B[1K");
    }

    pub fn line(writer: anytype) !void {
        try writer.writeAll("\x1B[2K");
    }

    pub fn toDisplayEnd(writer: anytype) !void {
        try writer.writeAll("\x1B[0J");
    }

    pub fn toDisplayBegin(writer: anytype) !void {
        try writer.writeAll("\x1B[1J");
    }

    pub fn display(writer: anytype) !void {
        try writer.writeAll("\x1B[2J");
    }

    pub fn entire(writer: anytype) !void {
        // same as clear(1)
        try writer.writeAll("\x1B[3J");
    }
};

pub const Style = struct {
    pub fn reset(writer: anytype) !void {
        try writer.writeAll("\x1B[0m");
    }

    pub fn bold(writer: anytype) !void {
        try writer.writeAll("\x1B[1m");
    }

    pub fn dim(writer: anytype) !void {
        try writer.writeAll("\x1B[2m");
    }

    pub fn italic(writer: anytype) !void {
        try writer.writeAll("\x1B[3m");
    }

    pub fn underline(writer: anytype) !void {
        try writer.writeAll("\x1B[4m");
    }

    pub fn blink(writer: anytype) !void {
        try writer.writeAll("\x1B[5m");
    }

    pub fn reverse(writer: anytype) !void {
        try writer.writeAll("\x1B[7m");
    }

    pub fn hidden(writer: anytype) !void {
        try writer.writeAll("\x1B[8m");
    }

    pub fn strike(writer: anytype) !void {
        try writer.writeAll("\x1B[9m");
    }

    pub fn resetBold(writer: anytype) !void {
        try writer.writeAll("\x1B[22m");
    }

    pub fn resetDim(writer: anytype) !void {
        try writer.writeAll("\x1B[22m");
    }

    pub fn resetItalic(writer: anytype) !void {
        try writer.writeAll("\x1B[23m");
    }

    pub fn resetUnderline(writer: anytype) !void {
        try writer.writeAll("\x1B[24m");
    }

    pub fn resetBlink(writer: anytype) !void {
        try writer.writeAll("\x1B[25m");
    }

    pub fn resetReverse(writer: anytype) !void {
        try writer.writeAll("\x1B[27m");
    }

    pub fn resetHidden(writer: anytype) !void {
        try writer.writeAll("\x1B[28m");
    }

    pub fn resetStrikethrough(writer: anytype) !void {
        try writer.writeAll("\x1B[29m");
    }
};

pub const Foreground = struct {
    const Code = enum(u8) {
        black = 30,
        red = 31,
        green = 32,
        yellow = 33,
        blue = 34,
        magenta = 35,
        cyan = 36,
        white = 37,
        default = 39,
    };

    pub fn color(writer: anytype, code: Code) !void {
        try fmt.format(writer, "\x1B[{d}m", .{@enumToInt(code)});
    }

    pub fn default(writer: anytype) !void {
        try writer.writeAll("\x1B[39m");
    }
};

pub const Background = struct {
    const Code = enum(u8) {
        black = 40,
        red = 41,
        green = 42,
        yellow = 43,
        blue = 44,
        magenta = 45,
        cyan = 46,
        white = 47,
        default = 49,
    };

    pub fn color(writer: anytype, code: Code) !void {
        try fmt.format(writer, "\x1B[{d}m", .{@enumToInt(code)});
    }

    pub fn default(writer: anytype) !void {
        try writer.writeAll("\x1B[49m");
    }
};

pub const Private = struct {
    pub fn hideCursor(writer: anytype) !void {
        try writer.writeAll("\x1B[?25l");
    }

    pub fn showCursor(writer: anytype) !void {
        try writer.writeAll("\x1B[?25h");
    }

    pub fn saveScreen(writer: anytype) !void {
        try writer.writeAll("\x1B[?47h");
    }

    pub fn restoreScreen(writer: anytype) !void {
        try writer.writeAll("\x1B[?47l");
    }

    pub fn enableAlternativeBuf(writer: anytype) !void {
        try writer.writeAll("\x1B[?1049h");
    }

    pub fn disableAlternativeBuf(writer: anytype) !void {
        try writer.writeAll("\x1B[?1049l");
    }

    pub fn enableMouseInput(writer: anytype) !void {
        try writer.writeAll("\x1B[?1000h\x1b[?1002h\x1b[?1015h\x1b[?1006h");
    }

    pub fn disableMouseInput(writer: anytype) !void {
        try writer.writeAll("\x1B[?1006l\x1b[?1015l\x1b[?1002l\x1b[?1000l");
    }
};

/// select graphic rendition
pub const SGR = struct {
    pub const Rendition = enum(u8) {
        reset = 0,
        bold = 1,
        dim = 2,
        italic = 3,
        underline = 4,
        blink = 5,
        reverse = 7,
        hide = 8,
        strike = 9,
        // reset
        reset_italic = 23,
        reset_underline = 24,
        reset_blink = 25,
        reset_reverse = 27,
        show = 28,
        reset_strike = 29,
        // fg color
        fg_black = 30,
        fg_red = 31,
        fg_green = 32,
        fg_yellow = 33,
        fg_blue = 34,
        fg_magenta = 35,
        fg_cyan = 36,
        fg_white = 37,
        fg_default = 39,
        // bg color
        bg_black = 40,
        bg_red = 41,
        bg_green = 42,
        bg_yellow = 43,
        bg_blue = 44,
        bg_magenta = 45,
        bg_cyan = 46,
        bg_white = 47,
        bg_default = 49,
    };

    pub fn rendition(writer: anytype, attrs: []const Rendition) !void {
        if (attrs.len == 0) return;

        try fmt.format(writer, "\x1B[{d}", .{@enumToInt(attrs[0])});
        for (attrs[1..]) |attr| {
            try fmt.format(writer, ";{d}", .{@enumToInt(attr)});
        }
        try writer.writeAll("m");
    }
};

// ref `$ infocmp tmux-256color`
pub const Cap = struct {
    pub const Kind = enum { tmux, alacritty };

    pub fn toStatusLine(kind: Kind, writer: anytype) !void {
        try writer.writeAll(switch (kind) {
            .Tmux => "\x1B]0;",
            .Alacritty => "\x1B]2;",
        });
    }

    pub fn fromStatusLine(writer: anytype) !void {
        try writer.writeAll("^G");
    }

    pub fn disableStatusLine(kind: Kind, writer: anytype) !void {
        try writer.writeAll(switch (kind) {
            .Tmux => "\x1B]0;\x0007",
            .Alacritty => "\x1B]2;\x0007",
        });
    }

    pub fn insertLine(writer: anytype) !void {
        try writer.writeAll("\x1B[L");
    }

    pub fn deleteLine(writer: anytype) !void {
        try writer.writeAll("\x1B[M");
    }

    /// inclusive range of row, (low, high), 0-based
    pub fn changeScrollableRegion(writer: anytype, low: u16, high: u16) !void {
        try fmt.format(writer, "\x1B[{d};{d}r", .{ low + 1, high + 1 });
    }
};
