const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;
const system = std.os.linux;
const os = std.os;

const umbra = @import("./src/umbra.zig");
const TTY = umbra.TTY;

const types = @import("./types.zig");

const log = std.log;
const assert = std.debug.assert;

const CursorMove = struct {
    row: ?Change,

    const Change = struct {
        from: u16,
        to: u16,
    };

    fn rowChange(row: Change) CursorMove {
        return .{
            .row = row,
        };
    }
};

const Cursor = struct {
    // 0-based
    col: u16,
    row: u16,
};

const State = struct {
    ttyfd: system.fd_t,
    winsize: TTY.WinSize,

    // things will change cursor
    // * cursor.{up,down,goto,home, ...}
    // * tty.writer.{write,print}
    // * winch
    cursor: Cursor,

    data_range: types.Data.Range,

    const Self = @This();

    fn reactWinch(self: *Self) void {
        const native = TTY.getNativeWinSize(self.ttyfd) catch unreachable;
        const resized = state.winsize.sync(native);
        if (resized.row) |_| {
            // todo move cursor
        }
    }
};

var state: State = undefined;

fn handleSigWinch(_: c_int) callconv(.C) void {
    state.reactWinch();
}

fn changeFocus(buffer: *TTY.BufferedWriter, move: CursorMove, data: types.Data) !void {
    if (move.row == null) {
        return;
    }

    defer buffer.flush() catch unreachable;

    const wb = buffer.writer();
    const curcmd = umbra.escseq.Cursor(TTY.BufferedWriter.Writer).init(wb);
    const stycmd = TTY.EscSeq.Style.init(wb);
    const fgcmd = TTY.EscSeq.Foreground.init(wb);
    const eracmd = umbra.escseq.Erase(TTY.BufferedWriter.Writer).init(wb);

    const from = move.row.?.from;
    const to = move.row.?.to;

    // reset the style of prev line
    {
        // try curcmd.goto(0, from);
        try eracmd.line();

        const ix: usize = state.data_range.start + @as(usize, from);
        const range: types.Data.Range = data.toc.items[ix];
        const line: []u8 = data.data.items[range.start..range.stop];
        // path\n
        const path_max: usize = @minimum(state.winsize.col_high - 1, line.len);

        try wb.writeAll(line[0..path_max]);
        try wb.writeAll("\n");
    }

    {
        try curcmd.goto(0, to);
        try eracmd.line();

        const ix = state.data_range.start + @as(usize, to);
        const range = data.toc.items[ix];
        const line = data.data.items[range.start..range.stop];
        // path\n
        const path_max: usize = @minimum(state.winsize.col_high - 1, line.len);

        try stycmd.bold();
        try fgcmd.color(.green);
        try wb.writeAll(line[0..path_max]);
        try fgcmd.default();
        try stycmd.resetBold();
        try wb.writeAll("\n");
    }

    state.cursor.row = to;
    try curcmd.goto(state.cursor.col, state.cursor.row);
}

pub fn main() !void {
    var tty = try TTY.init();
    defer tty.deinit();

    const curcmd = TTY.EscSeq.Cursor.init(tty.writer());

    {
        state.ttyfd = tty.file.handle;
        state.winsize = try tty.getWinSize();
        state.data_range = .{ .start = 0, .stop = 0 };

        try curcmd.home();
        state.cursor = .{ .col = 0, .row = 0 };

        _ = system.sigaction(system.SIG.WINCH, &system.Sigaction{
            .handler = .{ .handler = handleSigWinch },
            .mask = system.empty_sigset,
            .flags = 0,
        }, null);
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var data = try types.Data.init(allocator, 1 << 20);
    defer data.deinit();

    var buffer = tty.buffered_writer();
    defer buffer.flush() catch unreachable;
    const wb = buffer.writer();

    {
        const root = "/mnt/molduga/av/named";

        var dir = try fs.openDirAbsolute(root, .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(allocator);
        defer walker.deinit();

        while (true) {
            const maybe = walker.next() catch |err| switch (err) {
                error.AccessDenied => continue,
                else => unreachable,
            };
            if (maybe) |entry| {
                if (entry.kind == .File) {
                    try data.appendSlices(&.{entry.path});
                }
            } else {
                break;
            }
        }

        {
            defer curcmd.home() catch unreachable;
            defer buffer.flush() catch unreachable;

            defer {
                state.data_range.start = 0;
                state.data_range.stop = state.winsize.row_high - 1;
            }
            var it = data.iterate(0, state.winsize.row_high - 1);
            while (it.next()) |path| {
                try wb.print("{s}\n", .{path});
            }
            try wb.print("{}/{}", .{ state.winsize.row_high, data.len });
        }
    }

    {
        state.cursor.col = 0;
        state.cursor.row = 0;

        var input: [16]u8 = undefined;

        while (tty.getInput(&input)) |n| {
            defer buffer.flush() catch unreachable;

            const key = input[0..n];
            if (key[0] != '\x1B') {
                switch (key[0]) {
                    'j' => {
                        if (state.cursor.row >= state.winsize.row_high) {
                            continue;
                        }
                    },
                    'k' => {
                        if (state.cursor.row <= 0) {
                            continue;
                        }
                    },
                    // 'g' => try curcmd.home(),
                    // 'G' => try curcmd.goto(0, state.winsize.row_high),
                    'q' => break,
                    else => {},
                }
            } else {
                if (key.len == 1) return;
            }
        } else |err| {
            return err;
        }
    }
}
