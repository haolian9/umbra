//
// todo:
// * path may contains utf-8 chars, char width
// * status line
//

const std = @import("std");
const assert = std.debug.assert;
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;

const escseq = @import("./src/escseq.zig");
const TTY = @import("./src/TTY.zig");
const WinSize = TTY.WinSize;
const BufferedWriter = TTY.BufferedWriter;

pub const Range = struct {
    start: usize,
    stop: usize,
};

pub const Canvas = struct {
    buffer: *BufferedWriter,
    winsize: WinSize,
    data: *const Data,
    // partial view of data
    range: Range,
    // split scoped data into vertical windows
    split: u8,

    const Self = @This();

    pub fn init(buffer: *BufferedWriter, winsize: WinSize, data: *const Data, split: u8) Canvas {
        assert(split > 0 and split < 10);

        return .{
            .buffer = buffer,
            .winsize = winsize,
            .data = data,
            .range = .{
                .start = 0,
                .stop = @minimum(winsize.row_total, data.len),
            },
            .split = split,
        };
    }

    // range+n
    pub fn scrollUp(self: *Self, n: usize) !void {
        const data_tail: usize = self.data.len - self.range.stop;

        if (data_tail == 0) return;

        const m = @minimum(n, data_tail);

        defer {
            self.range.start += m;
            self.range.stop += m;
        }

        defer self.buffer.flush() catch unreachable;

        const writer = self.buffer.writer();
        const curcmd = escseq.Cursor(BufferedWriter.Writer).init(writer);
        const eracmd = escseq.Erase(BufferedWriter.Writer).init(writer);

        // rm head:n
        try curcmd.scrollUp(@intCast(u16, m));

        // append tail:n
        {
            const data_start = self.range.stop;
            const row_start = self.winsize.row_high - m;
            var i: usize = 0;
            while (i < m) : (i += 1) {
                try curcmd.goto(0, @intCast(u16, row_start + i));
                try eracmd.line();
                const entry: Data.Entry = self.data.toc.items[data_start + i];
                try entry.write(writer);
            }
        }
    }

    // range-n
    pub fn scrollDown(self: *Self, n: usize) !void {
        const head: usize = self.range.start - 0;

        if (head == 0) return;

        const m = @minimum(n, head);

        defer {
            self.range.start -= m;
            self.range.stop -= m;
        }

        defer self.buffer.flush() catch unreachable;

        const writer = self.buffer.writer();
        const curcmd = escseq.Cursor(BufferedWriter.Writer).init(writer);
        const eracmd = escseq.Erase(BufferedWriter.Writer).init(writer);

        // rm tail:n
        try curcmd.scrollDown(@intCast(u16, m));

        // insert head:n
        {
            const data_start = self.range.start - m;
            const row_start: usize = 0;
            var i: usize = 0;
            while (i < m) : (i += 1) {
                try curcmd.goto(0, @intCast(u16, row_start + i));
                try eracmd.line();
                const entry = self.data.toc.items[data_start + i];
                try entry.write(writer);
            }
        }
    }

    // when first rendering or resizes or self.{data,split} changes
    pub fn fullRender(self: *Self) !void {
        const writer = self.buffer.writer();
        const curcmd = escseq.Cursor(BufferedWriter.Writer).init(writer);
        const eracmd = escseq.Erase(BufferedWriter.Writer).init(writer);

        defer self.buffer.flush() catch unreachable;

        try eracmd.display();
        try curcmd.home();

        var it = self.data.iterate(self.range.start, self.range.stop);
        while (it.next()) |entry|  {
            try fmt.format(writer, "{s}{c}{s}", .{entry.dir, fs.path.sep, entry.base});
        }

        try curcmd.home();
    }

    // things that will change range:
    // * scroll up
    // * scroll down
    // * resize window
};

pub const Data = struct {
    toc: std.ArrayList(Entry),
    cap: usize,
    len: usize,

    pub const Entry = struct {
        dir: []const u8,
        base: []const u8,
        // stem: []const u8,
        // ext: []const u8,
        size: u64,
        mtime: i64,

        pub fn write(self: Entry, writer: anytype) !void {
            try fmt.format(writer, "{s}{c}{s}", .{self.dir, fs.path.sep, self.base});
        }
    };

    pub const Self = @This();

    pub const Iterator = struct {
        context: Data,
        range: Range,
        cursor: usize,

        pub fn next(self: *Iterator) ?Entry {
            if (self.cursor >= self.range.stop) return null;

            defer self.cursor += 1;

            return self.context.toc.items[self.cursor];
        }
    };

    pub fn init(allocator: mem.Allocator, cap: usize) !Data {
        return Data{
            .cap = cap,
            .toc = try std.ArrayList(Entry).initCapacity(allocator, cap),
            .len = 0,
        };
    }

    pub fn iterate(self: Self, start: ?usize, stop: ?usize) Iterator {
        const left = start orelse 0;
        const right = if (stop) |val| @minimum(val, self.len) else self.len;
        return .{
            .context = self,
            .range = .{
                .start = left,
                .stop = right,
            },
            .cursor = left,
        };
    }

    pub fn appendSlice(self: *Self, entries: []const Entry) !void {
        if (self.cap < self.len + entries.len) {
            return error.tooManyEntries;
        }

        self.toc.appendSliceAssumeCapacity(entries);
        self.len += entries.len;
    }

    pub fn append(self: *Self, entry: Entry) !void {
        if (self.cap < self.len + 1) {
            return error.tooManyEntries;
        }

        self.toc.appendAssumeCapacity(entry);
        self.len += 1;
    }

    pub fn deinit(self: Self) void {
        self.toc.deinit();
    }
};
