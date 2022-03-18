// man 4 tty

const std = @import("std");
const fmt = std.fmt;
const fs = std.fs;
const mem = std.mem;
const os = std.os;
const system = std.os.linux;

const EscSeq = @import("./EscapeSequence.zig");

const TTY = @This();
const Self = TTY;

f: fs.File,
r: fs.File.Reader,
w: fs.File.Writer,
cmd: EscSeq,

origin: system.termios,
term: system.termios,

pub fn init() !TTY {
    const f = try fs.openFileAbsolute("/dev/tty", .{ .read = true, .write = true });
    errdefer f.close();

    const r = f.reader();

    const w = f.writer();
    const cmd = EscSeq.init(w);

    const origin = try os.tcgetattr(f.handle);
    const term = origin;

    var tty = TTY{ .f = f, .r = r, .w = w, .cmd = cmd, .origin = origin, .term = term };

    try tty.setupTerm();
    errdefer tty.resetTerm() catch unreachable;

    try tty.setupCanvas();
    errdefer tty.cleanCanvas() catch unreachable;

    return tty;
}

pub fn deinit(self: Self) void {
    self.cleanCanvas() catch unreachable;
    self.resetTerm() catch unreachable;
    self.f.close();
}

fn setupTerm(self: *Self) !void {
    // see: man 3 termios
    // see: https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm
    self.term.lflag &= ~@as(
        system.tcflag_t,
        system.ECHO | system.ICANON | system.ISIG | system.IEXTEN,
    );
    self.term.iflag &= ~@as(
        system.tcflag_t,
        system.IXON | system.ICRNL | system.BRKINT | system.INPCK | system.ISTRIP,
    );

    // read() return delays time when got something
    self.term.cc[system.V.TIME] = 0;
    // read() return when min bytes read
    self.term.cc[system.V.MIN] = 1;

    try self.applyTermiosChanges(self.term);
}

fn resetTerm(self: Self) !void {
    try self.applyTermiosChanges(self.origin);
}

fn setupCanvas(self: Self) !void {
    try self.cmd.cursor.save();
    try self.cmd.private.saveScreen();
    try self.cmd.private.enableAlternativeBuf();
}

fn cleanCanvas(self: Self) !void {
    try self.cmd.private.disableAlternativeBuf();
    try self.cmd.private.restoreScreen();
    try self.cmd.cursor.restore();
}

fn applyTermiosChanges(self: Self, term: system.termios) !void {
    try os.tcsetattr(self.f.handle, .FLUSH, term);
}

fn applyTermiosChangesNow(self: Self, term: system.termios) !void {
    try os.tcsetattr(self.f.handle, .NOW, term);
}

pub fn enableMultibytesInput(self: *Self) !void {
    self.term.cc[system.V.TIME] = 1;
    self.term.cc[system.V.MIN] = 0;
    try self.applyTermiosChangesNow(self.term);
}

pub fn disableMultibytesInput(self: *Self) !void {
    self.term.cc[system.V.TIME] = 0;
    self.term.cc[system.V.MIN] = 1;
    try self.applyTermiosChangesNow(self.term);
}


// single-char key
// multi-char key: F10, alt-a, arrow-up
// multi-char mouse
pub fn getInput(self: *Self) ![]const u8 {
    {
        var buffer: [1]u8 = undefined;

        const n = try self.r.read(&buffer);
        if (n != 1) unreachable;

        if (buffer[0] != '\x1B') {
            return &buffer;
        }
    }

    {
        try self.enableMultibytesInput();
        defer self.disableMultibytesInput() catch unreachable;

        var buffer: [16]u8 = undefined;
        buffer[0] = '\x1B';
        const n = try self.r.read(buffer[1..]);

        return buffer[0..n+1];
    }
}
