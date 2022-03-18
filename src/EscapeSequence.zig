// ref:
// * https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797

const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;

const EscSeq = @This();

cursor: Cursor,
erase: Erase,
style: Style,
fg:  Foreground,
bg: Background,
private: Private,


pub fn init(w: fs.File.Writer) EscSeq {
    // # TODO@haoliang any need to turn w into ptr?
    return .{
        .cursor = .{.w = w},
        .erase = .{.w = w},
        .style = .{.w = w},
        .fg = .{.w = w},
        .bg = .{.w = w},
        .private = .{.w = w},
    };
}


pub const Cursor = struct {
    w: fs.File.Writer,

    const Self = @This();

    pub fn hide(self: Self) !void {
        try self.w.writeAll("\x1B[?25l");
    }

    pub fn show(self: Self) !void {
        try self.w.writeAll("\x1B[?25h");
    }

    pub fn up(self: Self, n: u16) !void {
        try fmt.format(self.w, "\x1B[{d}A", .{n});
    }

    pub fn down(self: Self, n: u16) !void {
        try fmt.format(self.w, "\x1B[{d}B", .{n});
    }

    pub fn forward(self: Self, n: u16) !void {
        try fmt.format(self.w, "\x1B[{d}C", .{n});
    }

    pub fn back(self: Self, n: u16) !void {
        try fmt.format(self.w, "\x1B[{d}D", .{n});
    }

    pub fn up1(self: Self) !void {
        try self.w.writeAll("\x1BM");
    }

    pub fn goto(self: Self, x: u16, y: u16) !void {
        const col = y + 1;
        const row = x + 1;
        try fmt.format(self.w, "\x1B[{d};{d}H", .{ row, col });
    }

    pub fn save(self: Self) !void {
        try self.w.writeAll("\x1B[s");
    }

    pub fn restore(self: Self) !void {
        try self.w.writeAll("\x1B[u");
    }

    pub fn request(self: Self) !void {
        try self.w.writeAll("\x1B[6n");
    }

    pub fn home(self: Self) !void {
        try self.w.writeAll("\x1B[H");
    }
};

pub const Erase = struct {
    w: fs.File.Writer,

    const Self = @This();

    pub fn toLineEnd(self: Self) !void {
        try self.w.writeAll("\x1B[0K");
    }

    pub fn toLineBegin(self: Self) !void {
        try self.w.writeAll("\x1B[1K");
    }

    pub fn line(self: Self) !void {
        try self.w.writeAll("\x1B[2K");
    }

    pub fn toDisplayEnd(self: Self) !void {
        try self.w.writeAll("\x1B[0J");
    }

    pub fn toDisplayBegin(self: Self) !void {
        try self.w.writeAll("\x1B[1J");
    }

    pub fn display(self: Self) !void {
        try self.w.writeAll("\x1B[2J");
    }

    pub fn entire(self: Self) !void {
        // same as clear(1)
        try self.w.writeAll("\x1B[3J");
    }
};

pub const Style = struct {
    w: fs.File.Writer,

    const Self = @This();

    pub fn reset(self: Self) !void {
        try self.w.writeAll("\x1B[0m");
    }

    pub fn bold(self: Self) !void {
        try self.w.writeAll("\x1B[1m");
    }

    pub fn dim(self: Self) !void {
        try self.w.writeAll("\x1B[2m");
    }

    pub fn italic(self: Self) !void {
        try self.w.writeAll("\x1B[3m");
    }

    pub fn underline(self: Self) !void {
        try self.w.writeAll("\x1B[4m");
    }

    pub fn blink(self: Self) !void {
        try self.w.writeAll("\x1B[5m");
    }

    pub fn reverse(self: Self) !void {
        try self.w.writeAll("\x1B[7m");
    }

    pub fn hidden(self: Self) !void {
        try self.w.writeAll("\x1B[8m");
    }

    pub fn strikethrough(self: Self) !void {
        try self.w.writeAll("\x1B[9m");
    }

    pub fn resetBold(self: Self) !void {
        try self.w.writeAll("\x1B[22m");
    }

    pub fn resetDim(self: Self) !void {
        try self.w.writeAll("\x1B[22m");
    }

    pub fn resetItalic(self: Self) !void {
        try self.w.writeAll("\x1B[23m");
    }

    pub fn resetUnderline(self: Self) !void {
        try self.w.writeAll("\x1B[24m");
    }

    pub fn resetBlink(self: Self) !void {
        try self.w.writeAll("\x1B[25m");
    }

    pub fn resetReverse(self: Self) !void {
        try self.w.writeAll("\x1B[27m");
    }

    pub fn resetHidden(self: Self) !void {
        try self.w.writeAll("\x1B[28m");
    }

    pub fn resetStrikethrough(self: Self) !void {
        try self.w.writeAll("\x1B[29m");
    }
};

pub const Foreground = struct {
    w: fs.File.Writer,

    const Self = @This();

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

    pub fn color(self: Self, code: Code) !void {
        try fmt.format(self.w, "\x1B[{d}m", .{@enumToInt(code)});
    }

    pub fn default(self: Self) !void {
        try self.w.writeAll("\x1B[39m");
    }
};

pub const Background = struct {
    w: fs.File.Writer,

    const Self = @This();

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

    pub fn color(self: Self, code: Code) !void {
        try fmt.format(self.w, "\x1B[{d}m", .{@enumToInt(code)});
    }

    pub fn default(self: Self) !void {
        try self.w.writeAll("\x1B[49m");
    }
};


pub const Private = struct {
    w: fs.File.Writer,

    const Self = @This();

    pub fn hideCursor(self: Self) !void {
        try self.w.writeAll("\x1B[?25l");
    }

    pub fn showCursor(self: Self) !void {
        try self.w.writeAll("\x1B[?25h");
    }

    pub fn saveScreen(self: Self) !void {
        try self.w.writeAll("\x1B[?47h");
    }

    pub fn restoreScreen(self: Self) !void {
        try self.w.writeAll("\x1B[?47l");
    }

    pub fn enableAlternativeBuf(self: Self) !void {
        try self.w.writeAll("\x1B[?1049h");
    }

    pub fn disableAlternativeBuf(self: Self) !void {
        try self.w.writeAll("\x1B[?1049l");
    }

    pub fn enableMouseInput(self: Self) !void {
        try self.w.writeAll("\x1B[?1000h\x1b[?1002h\x1b[?1015h\x1b[?1006h");
    }

    pub fn disableMouseInput(self: Self) !void {
        try self.w.writeAll("\x1B[?1006l\x1b[?1015l\x1b[?1002l\x1b[?1000l");
    }

};
