const std = @import("std");
const print = std.debug.print;
const fmt = std.fmt;
const meta = std.meta;

const umbra = @import("./src/umbra.zig");
const escseq = umbra.escseq;
const TTY = umbra.TTY;

pub const State = struct {
    data: []Entry,
    window: TTY.WinSize,
    // scope of data
    scope: Range,
    // cursor in window
    cursor: Cursor,

    const Self = @This();

    pub fn init(data: []Entry, window: TTY.WinSize) !State {
        if (window.row_total < 10) {
            return error.tooNarrowWindow;
        }

        return State{
            .data = data,
            .window = window,
            .scope = .{
                .start = 0,
                .stop = @minimum(window.row_total, data.len),
            },
            .cursor = .{
                .row = 0,
                .col = 0,
            },
        };
    }

    pub fn resize(self: *Self, window: TTY.WinSize) !bool {
        if (meta.eql(self.window, window)) {
            return false;
        }

        self.window = window;
        // scope
    }

    pub const Entry = struct {
        val: i32,
    };

    pub const Range = struct {
        start: usize,
        stop: usize,
    };

    pub const Cursor = struct {
        row: u16,
        col: u16,
    };
};

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer gpa.deinit();
    // const allocator = gpa.allocator();

    var tty = try TTY.init();
    defer tty.deinit();

    const winsize = try tty.getWinSize();
    const main_high = winsize.row_high - 1;
    const status_high = main_high + 1;

    const curcmd = escseq.Cursor;
    const eracmd = escseq.Erase;

    // panorama->scope: scroll up/down
    // window/pane->cursor: up/down

    {
        var buffer = tty.buffered_writer();
        defer buffer.flush() catch unreachable;

        const wb = buffer.writer();

        try escseq.Cap.changeScrollableRegion(wb, 0, main_high);

        // main window
        {
            try curcmd.home(wb);
            var i: usize = 0;
            while (i <= main_high) : (i += 1) {
                try fmt.format(wb, "* {d}", .{i});
                try curcmd.nextLine(wb, 1);
            }
        }

        // status line
        {
            try curcmd.goto(wb, 0, status_high);
            try wb.writeAll("files 1/10");
        }
    }

    {
        var buffer = tty.buffered_writer();
        defer buffer.flush() catch unreachable;

        const wb = buffer.writer();

        // main window's high row
        const mid = (winsize.row_high - 1) / 2;
        var row: u16 = mid;
        var input_buffer: [16]u8 = undefined;

        try curcmd.goto(wb, 0, mid);
        try buffer.flush();

        while (true) {
            const n = try tty.getInput(&input_buffer);
            if (n != 1) continue;

            defer buffer.flush() catch unreachable;

            switch (input_buffer[0]) {
                'q' => break,
                'j' => {
                    if (row > main_high) {
                        try curcmd.down(wb, 1);
                    } else if (row == main_high) {
                        continue;
                    } else {
                        defer row += 1;
                        try curcmd.save(wb);
                        try curcmd.scrollUp(wb, 1);
                        try curcmd.goto(wb, 0, main_high);
                        try eracmd.toLineEnd(wb);
                        try fmt.format(wb, "* {d}", .{row + mid + 1});
                        try curcmd.restore(wb);
                    }
                },
                'k' => {
                    if (row < mid) {
                        try curcmd.up(wb, 1);
                    } else if (row == mid) {
                        continue;
                    } else {
                        defer row -= 1;
                        try curcmd.save(wb);
                        try curcmd.scrollDown(wb, 1);
                        try curcmd.goto(wb, 0, 0);
                        try eracmd.toLineEnd(wb);
                        try fmt.format(wb, "* {d}", .{row - mid - 1});
                        try curcmd.restore(wb);
                    }
                },
                else => {},
            }
        }
    }
}
