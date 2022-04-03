// ref:
// * https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
//
//
// naming:
// * hide/show, conceal/reveal
// * strike, strikethrough, cross-out

const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;

pub fn Cursor(comptime Writer: type) type {
    return struct {
        writer: Writer,

        const Self = @This();

        pub fn init(writer: Writer) Self {
            return .{ .writer = writer };
        }

        pub fn hide(self: Self) !void {
            try self.writer.writeAll("\x1B[?25l");
        }

        pub fn show(self: Self) !void {
            try self.writer.writeAll("\x1B[?25h");
        }

        pub fn up(self: Self, n: u16) !void {
            try fmt.format(self.writer, "\x1B[{d}A", .{n});
        }

        pub fn down(self: Self, n: u16) !void {
            try fmt.format(self.writer, "\x1B[{d}B", .{n});
        }

        pub fn forward(self: Self, n: u16) !void {
            try fmt.format(self.writer, "\x1B[{d}C", .{n});
        }

        pub fn back(self: Self, n: u16) !void {
            try fmt.format(self.writer, "\x1B[{d}D", .{n});
        }

        pub fn up1(self: Self) !void {
            try self.writer.writeAll("\x1BM");
        }

        pub fn goto(self: Self, col: u16, row: u16) !void {
            try fmt.format(self.writer, "\x1B[{d};{d}H", .{ row + 1, col + 1 });
        }

        pub fn save(self: Self) !void {
            try self.writer.writeAll("\x1B[s");
        }

        pub fn restore(self: Self) !void {
            try self.writer.writeAll("\x1B[u");
        }

        pub fn request(self: Self) !void {
            try self.writer.writeAll("\x1B[6n");
        }

        pub fn home(self: Self) !void {
            try self.writer.writeAll("\x1B[H");
        }

        pub fn scrollUp(self: Self, n: u16) !void {
            try fmt.format(self.writer, "\x1B[{d}S", .{n});
        }

        pub fn scrollDown(self: Self, n: u16) !void {
            try fmt.format(self.writer, "\x1B[{d}T", .{n});
        }

        pub fn nextLine(self: Self, n: u16) !void {
            try fmt.format(self.writer, "\x1B[{d}E", .{n});
        }

        pub fn prevLine(self: Self, n: u16) !void {
            try fmt.format(self.writer, "\x1B[{d}F", .{n});
        }
    };
}

pub fn Erase(comptime Writer: type) type {
    return struct {
        writer: Writer,

        const Self = @This();

        pub fn init(writer: Writer) Self {
            return .{ .writer = writer };
        }

        pub fn toLineEnd(self: Self) !void {
            try self.writer.writeAll("\x1B[0K");
        }

        pub fn toLineBegin(self: Self) !void {
            try self.writer.writeAll("\x1B[1K");
        }

        pub fn line(self: Self) !void {
            try self.writer.writeAll("\x1B[2K");
        }

        pub fn toDisplayEnd(self: Self) !void {
            try self.writer.writeAll("\x1B[0J");
        }

        pub fn toDisplayBegin(self: Self) !void {
            try self.writer.writeAll("\x1B[1J");
        }

        pub fn display(self: Self) !void {
            try self.writer.writeAll("\x1B[2J");
        }

        pub fn entire(self: Self) !void {
            // same as clear(1)
            try self.writer.writeAll("\x1B[3J");
        }
    };
}

pub fn Style(comptime Writer: type) type {
    return struct {
        writer: Writer,

        const Self = @This();

        pub fn init(writer: Writer) Self {
            return .{ .writer = writer };
        }

        pub fn reset(self: Self) !void {
            try self.writer.writeAll("\x1B[0m");
        }

        pub fn bold(self: Self) !void {
            try self.writer.writeAll("\x1B[1m");
        }

        pub fn dim(self: Self) !void {
            try self.writer.writeAll("\x1B[2m");
        }

        pub fn italic(self: Self) !void {
            try self.writer.writeAll("\x1B[3m");
        }

        pub fn underline(self: Self) !void {
            try self.writer.writeAll("\x1B[4m");
        }

        pub fn blink(self: Self) !void {
            try self.writer.writeAll("\x1B[5m");
        }

        pub fn reverse(self: Self) !void {
            try self.writer.writeAll("\x1B[7m");
        }

        pub fn hidden(self: Self) !void {
            try self.writer.writeAll("\x1B[8m");
        }

        pub fn strike(self: Self) !void {
            try self.writer.writeAll("\x1B[9m");
        }

        pub fn resetBold(self: Self) !void {
            try self.writer.writeAll("\x1B[22m");
        }

        pub fn resetDim(self: Self) !void {
            try self.writer.writeAll("\x1B[22m");
        }

        pub fn resetItalic(self: Self) !void {
            try self.writer.writeAll("\x1B[23m");
        }

        pub fn resetUnderline(self: Self) !void {
            try self.writer.writeAll("\x1B[24m");
        }

        pub fn resetBlink(self: Self) !void {
            try self.writer.writeAll("\x1B[25m");
        }

        pub fn resetReverse(self: Self) !void {
            try self.writer.writeAll("\x1B[27m");
        }

        pub fn resetHidden(self: Self) !void {
            try self.writer.writeAll("\x1B[28m");
        }

        pub fn resetStrikethrough(self: Self) !void {
            try self.writer.writeAll("\x1B[29m");
        }
    };
}

pub fn Foreground(comptime Writer: type) type {
    return struct {
        writer: Writer,

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

        pub fn init(writer: Writer) Self {
            return .{ .writer = writer };
        }

        pub fn color(self: Self, code: Code) !void {
            try fmt.format(self.writer, "\x1B[{d}m", .{@enumToInt(code)});
        }

        pub fn default(self: Self) !void {
            try self.writer.writeAll("\x1B[39m");
        }
    };
}

pub fn Background(comptime Writer: type) type {
    return struct {
        writer: Writer,

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

        pub fn init(writer: Writer) Self {
            return .{ .writer = writer };
        }

        pub fn color(self: Self, code: Code) !void {
            try fmt.format(self.writer, "\x1B[{d}m", .{@enumToInt(code)});
        }

        pub fn default(self: Self) !void {
            try self.writer.writeAll("\x1B[49m");
        }
    };
}

pub fn Private(comptime Writer: type) type {
    return struct {
        writer: Writer,

        const Self = @This();

        pub fn init(writer: Writer) Self {
            return .{ .writer = writer };
        }

        pub fn hideCursor(self: Self) !void {
            try self.writer.writeAll("\x1B[?25l");
        }

        pub fn showCursor(self: Self) !void {
            try self.writer.writeAll("\x1B[?25h");
        }

        pub fn saveScreen(self: Self) !void {
            try self.writer.writeAll("\x1B[?47h");
        }

        pub fn restoreScreen(self: Self) !void {
            try self.writer.writeAll("\x1B[?47l");
        }

        pub fn enableAlternativeBuf(self: Self) !void {
            try self.writer.writeAll("\x1B[?1049h");
        }

        pub fn disableAlternativeBuf(self: Self) !void {
            try self.writer.writeAll("\x1B[?1049l");
        }

        pub fn enableMouseInput(self: Self) !void {
            try self.writer.writeAll("\x1B[?1000h\x1b[?1002h\x1b[?1015h\x1b[?1006h");
        }

        pub fn disableMouseInput(self: Self) !void {
            try self.writer.writeAll("\x1B[?1006l\x1b[?1015l\x1b[?1002l\x1b[?1000l");
        }
    };
}

/// select graphic rendition
pub fn SGR(comptime Writer: type) type {
    return struct {
        writer: Writer,

        const Self = @This();

        const Rendition = enum(u8) {
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
            resetItalic = 23,
            resetUnderline = 24,
            resetBlink = 25,
            resetReverse = 27,
            show = 28,
            resetStrike = 29,
            // fg color
            fgBlack = 30,
            fgRed = 31,
            fgGreen = 32,
            fgYellow = 33,
            fgBlue = 34,
            fgMagenta = 35,
            fgCyan = 36,
            fgWhite = 37,
            fgDefault = 39,
            // bg color
            bgBlack = 40,
            bgRed = 41,
            bgGreen = 42,
            bgYellow = 43,
            bgBlue = 44,
            bgMagenta = 45,
            bgCyan = 46,
            bgWhite = 47,
            bgDefault = 49,
        };

        pub fn init(writer: Writer) Self {
            return .{ .writer = writer };
        }

        pub fn rendition(self: Self, attrs: []const Rendition) !void {
            if (attrs.len == 0) return;

            try fmt.format(self.writer, "\x1B[{d}", .{@enumToInt(attrs[0])});
            for (attrs[1..]) |attr| {
                try fmt.format(self.writer, ";{d}", .{@enumToInt(attr)});
            }
            try self.writer.writeAll("m");
        }
    };
}

// ref `$ infocmp tmux-256color`
pub fn Cap(comptime Writer: type) type {
    return struct {
        writer: Writer,
        kind: Kind,

        const Self = @This();
        pub const Kind = enum { Tmux, Alacritty };

        pub fn init(writer: Writer, kind: Kind) Self {
            return .{ .writer = writer, .kind = kind };
        }

        pub fn toStatusLine(self: Self) !void {
            try self.writer.writeAll(switch (self.kind) {
                .Tmux => "\x1B]0;",
                .Alacritty => "\x1B]2;",
            });
        }

        pub fn fromStatusLine(self: Self) !void {
            try self.writer.writeAll("^G");
        }

        pub fn disableStatusLine(self: Self) !void {
            try self.writer.writeAll(switch (self.kind) {
                .Tmux => "\x1B]0;\x0007",
                .Alacritty => "\x1B]2;\x0007",
            });
        }

        pub fn insertLine(self: Self) !void {
            try self.writer.writeAll("\x1B[L");
        }

        pub fn deleteLine(self: Self) !void {
            try self.writer.writeAll("\x1B[M");
        }

        /// inclusive range of row, (low, high), 0-based
        pub fn changeScrollableRegion(self: Self, low: u16, high: u16) !void {
            try fmt.format(self.writer, "\x1B[{d};{d}r", .{ low + 1, high + 1 });
        }
    };
}
