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
        Black = 30,
        Red = 31,
        Green = 32,
        Yellow = 33,
        Blue = 34,
        Magenta = 35,
        Cyan = 36,
        White = 37,
        Default = 39,
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
        Black = 40,
        Red = 41,
        Green = 42,
        Yellow = 43,
        Blue = 44,
        Magenta = 45,
        Cyan = 46,
        White = 47,
        Default = 49,
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
        Reset = 0,
        Bold = 1,
        Dim = 2,
        Italic = 3,
        Underline = 4,
        Blink = 5,
        Reverse = 7,
        Hide = 8,
        Strike = 9,
        // reset
        ResetItalic = 23,
        ResetUnderline = 24,
        ResetBlink = 25,
        ResetReverse = 27,
        Show = 28,
        ResetStrike = 29,
        // fg color
        FgBlack = 30,
        FgRed = 31,
        FgGreen = 32,
        FgYellow = 33,
        FgBlue = 34,
        FgMagenta = 35,
        FgCyan = 36,
        FgWhite = 37,
        FgDefault = 39,
        // bg color
        BgBlack = 40,
        BgRed = 41,
        BgGreen = 42,
        BgYellow = 43,
        BgBlue = 44,
        BgMagenta = 45,
        BgCyan = 46,
        BgWhite = 47,
        BgDefault = 49,
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
    pub const Kind = enum { Tmux, Alacritty };

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
