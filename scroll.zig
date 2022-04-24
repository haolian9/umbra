//
// scroll
//

const std = @import("std");
const assert = std.debug.assert;
const fmt = std.fmt;

const umbra = @import("./src/umbra.zig");
const TTY = umbra.TTY;
const escseq = umbra.escseq;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == false);

    const allocator = gpa.allocator();

    var tty = try TTY.init();
    defer tty.deinit();

    const winsize = try tty.getWinSize();

    var buffer = tty.buffered_writer();
    defer buffer.flush() catch unreachable;

    const w = tty.writer();
    const wb = buffer.writer();

    const data: []const u16 = blk: {
        var data = std.ArrayList(u16).init(allocator);

        var i: u16 = 0;
        while (i < winsize.row_total * 3) : (i += 1) {
            try data.append(i);
        }

        break :blk data.toOwnedSlice();
    };
    defer allocator.free(data);

    // first draw
    {
        defer buffer.flush() catch unreachable;

        try escseq.Cursor.home(wb);
        defer escseq.Cursor.home(wb) catch unreachable;

        for (data[0..winsize.row_total]) |i| {
            try escseq.Cursor.goto(wb, 0, i);
            try wb.print(" {}", .{i});
        }
    }

    // interact
    {
        defer buffer.flush() catch unreachable;

        var screen_cursor: u16 = 0;
        var data_cursor: usize = 0;
        _ = data_cursor;
        var input_buffer: [16]u8 = undefined;

        try escseq.Cursor.home(w);
        try escseq.Cap.changeScrollableRegion(w, 0, winsize.row_high - 1);

        while (true) {
            defer buffer.flush() catch unreachable;

            const n = try tty.getInput(&input_buffer);

            const input = input_buffer[0..n];
            if (input.len != 1) continue;

            switch (input[0]) {
                'q' => break,
                'j' => {
                    if (screen_cursor < winsize.row_high) {
                        screen_cursor += 1;
                        data_cursor += 1;

                        try escseq.Cursor.down(wb, 1);
                    } else if (screen_cursor == winsize.row_high) {
                        // need to update the last line

                        // screen_cursor no move
                        const data_high = data.len - 1;
                        if (data_cursor == data_high) {
                            // end of data
                        } else if (data_cursor < data_high) {
                            data_cursor += 1;
                            try escseq.Cursor.scrollUp(wb, 1);
                            try escseq.Cursor.goto(wb, 0, screen_cursor);
                            try fmt.format(wb, " {d}", .{data[data_cursor]});
                        } else {
                            unreachable;
                        }
                    } else {
                        unreachable;
                    }
                },
                'k' => {
                    if (screen_cursor > 0) {
                        screen_cursor -= 1;
                        data_cursor -= 1;

                        try escseq.Cursor.up(wb, 1);
                    } else if (screen_cursor == 0) {
                        // screen_cursor no move

                        if (data_cursor == 0) {
                            // begin of data
                        } else if (data_cursor > 0) {
                            data_cursor -= 1;
                            // need to update the first line
                            try escseq.Cursor.scrollDown(wb, 1);
                            try escseq.Cursor.goto(wb, 0, screen_cursor);
                            try fmt.format(wb, " {d}", .{data[data_cursor]});
                        } else {
                            unreachable;
                        }
                    } else {
                        unreachable;
                    }
                },

                's' => {
                    try wb.writeAll("~status");
                    try escseq.Cursor.save(wb);
                    try escseq.Cap.toStatusLine(.Tmux, wb);
                    try wb.writeAll("hello 1/100");
                    try escseq.Cap.fromStatusLine(wb);
                    try escseq.Cursor.restore(wb);
                },

                'o' => {
                    // vim O
                    try escseq.Cap.insertLine(wb);
                    try escseq.Cursor.goto(wb, 0, screen_cursor);
                },
                'd' => {
                    // vim dd
                    try escseq.Cap.deleteLine(wb);
                    try escseq.Cursor.goto(wb, 0, screen_cursor);
                },

                'J' => {
                    if (screen_cursor < 10 or screen_cursor > 20) continue;

                    try escseq.Cursor.save(wb);
                    try escseq.Cap.changeScrollableRegion(wb, 10, 20);
                    try escseq.Cursor.scrollUp(wb, 1);
                    try escseq.Cursor.goto(wb, 0, 20);
                    try wb.writeAll("new line in bottom");
                    try escseq.Cap.changeScrollableRegion(wb, 0, winsize.row_total);
                    try escseq.Cursor.restore(wb);
                },
                'K' => {
                    if (screen_cursor < 10 or screen_cursor > 20) continue;

                    try escseq.Cursor.save(wb);
                    try escseq.Cap.changeScrollableRegion(wb, 10, 20);
                    try escseq.Cursor.scrollDown(wb, 1);
                    try escseq.Cursor.goto(wb, 0, 10);
                    try wb.writeAll("new line in top");
                    try escseq.Cap.changeScrollableRegion(wb, 0, winsize.row_total);
                    try escseq.Cursor.restore(wb);
                },

                else => {},
            }
        }
    }
}
