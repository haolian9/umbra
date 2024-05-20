// man 4 tty

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const linux = std.os.linux;
const posix = std.posix;

const tc_lflag_t = std.c.tc_lflag_t;

const escseq = @import("./escseq.zig");

const TTY = @This();
const Self = TTY;

// shortcuts
pub const Reader = fs.File.Reader;
pub const Writer = fs.File.Writer;
pub const BufferedWriter = std.io.BufferedWriter(16 << 10, Writer);

file: fs.File = undefined,
origin: linux.termios = undefined,
term: linux.termios = undefined,

pub fn init() !TTY {
    var file = try fs.openFileAbsolute("/dev/tty", .{ .mode = .read_write });
    errdefer file.close();

    const origin = try posix.tcgetattr(file.handle);
    const term = origin;

    var tty = TTY{
        .file = file,
        .origin = origin,
        .term = term,
    };

    try tty.setupTerm();
    errdefer tty.resetTerm() catch unreachable;

    try tty.setupCanvas();
    errdefer tty.cleanCanvas() catch unreachable;

    return tty;
}

pub fn deinit(self: *Self) void {
    defer self.file.close();

    self.cleanCanvas() catch unreachable;
    self.resetTerm() catch unreachable;
}

fn setupTerm(self: *Self) !void {
    // see: man 3 termios
    // see: https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm
    self.term.lflag.ECHO = false;
    self.term.lflag.ICANON = false;
    self.term.lflag.ISIG = false;
    self.term.lflag.IEXTEN = false;

    self.term.iflag.IXON = false;
    self.term.iflag.ICRNL = false;
    self.term.iflag.BRKINT = false;
    self.term.iflag.INPCK = false;
    self.term.iflag.ISTRIP = false;
    self.term.iflag.IUTF8 = false;

    // read() return delays time when got something
    self.term.cc[@intFromEnum(linux.V.TIME)] = 0;

    // read() return when min bytes read
    self.term.cc[@intFromEnum(linux.V.MIN)] = 1;

    try self.applyTermiosChanges(self.term);
}

fn resetTerm(self: Self) !void {
    try self.applyTermiosChanges(self.origin);
}

fn setupCanvas(self: Self) !void {
    const w = self.writer();

    try escseq.Cursor.save(w);
    try escseq.Private.saveScreen(w);
    try escseq.Private.enableAlternativeBuf(w);
}

fn cleanCanvas(self: Self) !void {
    const w = self.writer();

    try escseq.Private.disableAlternativeBuf(w);
    try escseq.Private.restoreScreen(w);
    try escseq.Cursor.restore(w);
}

fn applyTermiosChanges(self: Self, term: linux.termios) !void {
    try posix.tcsetattr(self.file.handle, .FLUSH, term);
}

fn applyTermiosChangesNow(self: Self, term: linux.termios) !void {
    try posix.tcsetattr(self.file.handle, .NOW, term);
}

pub fn enableMultibytesInput(self: *Self) !void {
    self.term.cc[@intFromEnum(linux.V.TIME)] = 1;
    self.term.cc[@intFromEnum(linux.V.MIN)] = 0;
    try self.applyTermiosChangesNow(self.term);
}

pub fn disableMultibytesInput(self: *Self) !void {
    self.term.cc[@intFromEnum(linux.V.TIME)] = 0;
    self.term.cc[@intFromEnum(linux.V.MIN)] = 1;
    try self.applyTermiosChangesNow(self.term);
}

// single-char key
// multi-char key: F10, alt-a, arrow-up
// multi-char mouse
pub fn getInput(self: *Self, buffer: *[16]u8) !usize {
    const r = self.reader();

    {
        const n = try r.read(buffer[0..1]);
        if (n != 1) unreachable;

        if (buffer[0] != '\x1B') return 1;
    }

    {
        try self.enableMultibytesInput();
        defer self.disableMultibytesInput() catch unreachable;

        const n = try r.read(buffer[1..]);
        return n + 1;
    }
}

pub const WinSize = struct {
    col_total: u16,
    // col_high = col_total - 1; 0-based
    col_high: u16,
    row_total: u16,
    row_high: u16,

    pub const Resized = struct {
        col: ?Change = null,
        row: ?Change = null,

        pub const Change = struct {
            from: u16,
            to: u16,
        };
    };

    pub fn fromNative(native: linux.winsize) WinSize {
        return .{
            .col_total = native.ws_col,
            .col_high = native.ws_col - 1,
            .row_total = native.ws_row,
            .row_high = native.ws_row - 1,
        };
    }

    pub fn sync(self: *WinSize, native: linux.winsize) Resized {
        var resized = Resized{};

        if (self.col_total != native.ws_col) {
            resized.col = .{ .from = self.col_high, .to = native.ws_col - 1 };
            self.col_total = native.ws_col;
            self.col_high = native.ws_col - 1;
        }

        if (self.row_total != native.ws_row) {
            resized.row = .{ .from = self.row_high, .to = native.ws_row - 1 };
            self.row_total = native.ws_row;
            self.row_high = native.ws_row - 1;
        }

        return resized;
    }
};

pub fn getWinSize(self: Self) !WinSize {
    return WinSize.fromNative(try getNativeWinSize(self.file.handle));
}

pub fn getNativeWinSize(fd: linux.fd_t) !linux.winsize {
    var native = mem.zeroes(linux.winsize);
    const rc = linux.ioctl(fd, linux.T.IOCGWINSZ, @intFromPtr(&native));

    if (posix.errno(rc) != .SUCCESS) {
        return posix.unexpectedErrno(@enumFromInt(rc));
    }

    return native;
}

pub fn reader(self: Self) Reader {
    return self.file.reader();
}

pub fn writer(self: Self) Writer {
    return self.file.writer();
}

pub fn buffered_writer(self: Self) BufferedWriter {
    return .{ .unbuffered_writer = self.writer() };
}
