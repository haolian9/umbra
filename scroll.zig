//
// scroll
//

const std = @import("std");
const assert = std.debug.assert;
const fmt = std.fmt;

const umbra = @import("./src/umbra.zig");
const TTY = umbra.TTY;
const escseq = umbra.escseq;
const Event = umbra.events.Event;

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

    const status_rows = 1;
    const screen_high = winsize.row_high - status_rows;
    const status_low = screen_high + 1;

    // construct frames
    try escseq.Cap.changeScrollableRegion(w, 0, winsize.row_high - status_rows);
    try escseq.Private.enableMouseInput(w);
    defer escseq.Private.disableMouseInput(w) catch unreachable;

    // first draw
    {
        defer buffer.flush() catch unreachable;

        try escseq.Cursor.home(wb);
        defer escseq.Cursor.home(wb) catch unreachable;

        for (data[0 .. screen_high + 1]) |i| {
            try escseq.Cursor.goto(wb, 0, i);
            try wb.print(" {}", .{i});
        }
        try escseq.Cursor.goto(wb, 0, status_low);
        try wb.print("total: {}", .{data.len});
    }

    // interact
    {
        defer buffer.flush() catch unreachable;

        var screen_cursor: u16 = 0;
        var data_cursor: usize = 0;
        var input_buffer: [16]u8 = undefined;

        try escseq.Cursor.home(w);

        while (true) {
            defer buffer.flush() catch unreachable;

            const input = blk: {
                const n = try tty.getInput(&input_buffer);
                break :blk input_buffer[0..n];
            };
            const event = try Event.fromString(input);

            if (input.len != 1) {
                try escseq.Cursor.save(wb);
                try escseq.Cursor.goto(wb, 0, status_low);
                try escseq.Erase.line(wb);
                switch (event) {
                    .Mouse => |mouse| {
                        try fmt.format(wb, "ignored chars: mouse {any}", .{mouse});
                    },
                    .Ascii => |ascii| {
                        try fmt.format(wb, "ignored chars: ascii {any}", .{ascii});
                    },
                    .Combo => |combo| {
                        try fmt.format(wb, "ignored chars: combo {any}", .{combo});
                    },
                }
                try escseq.Cursor.restore(wb);
                continue;
            }

            switch (input[0]) {
                'q' => break,
                'j' => {
                    if (screen_cursor < screen_high) {
                        screen_cursor += 1;
                        data_cursor += 1;

                        try escseq.Cursor.nextLine(wb, 1);
                    } else if (screen_cursor == screen_high) {
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
                            try escseq.Cursor.goto(wb, 0, screen_cursor);
                        } else {
                            unreachable;
                        }
                    } else {
                        unreachable;
                    }
                },
                'k' => {
                    const screen_low = 0;
                    if (screen_cursor > screen_low) {
                        screen_cursor -= 1;
                        data_cursor -= 1;

                        try escseq.Cursor.prevLine(wb, 1);
                    } else if (screen_cursor == screen_low) {
                        // screen_cursor no move

                        if (data_cursor == 0) {
                            // begin of data
                        } else if (data_cursor > screen_low) {
                            data_cursor -= 1;
                            // need to update the first line
                            try escseq.Cursor.scrollDown(wb, 1);
                            try escseq.Cursor.goto(wb, 0, screen_cursor);
                            try fmt.format(wb, " {d}", .{data[data_cursor]});
                            try escseq.Cursor.goto(wb, 0, screen_cursor);
                        } else {
                            unreachable;
                        }
                    } else {
                        unreachable;
                    }
                },

                'L' => {
                    // go to the last line of the screen
                    const gap = screen_high - screen_cursor;
                    if (gap == 0) {
                        // stay
                    } else if (gap > 0) {
                        screen_cursor = screen_high;
                        data_cursor += gap;
                        try escseq.Cursor.goto(wb, 0, screen_cursor);
                    } else {
                        unreachable;
                    }
                },
                'H' => {
                    // go to the first line of the screen
                    const screen_low = 0;
                    const gap = screen_cursor - screen_low;
                    if (gap == 0) {
                        // stay
                    } else if (gap > 0) {
                        screen_cursor = screen_low;
                        data_cursor -= gap;
                        try escseq.Cursor.goto(wb, 0, screen_cursor);
                    } else {
                        unreachable;
                    }
                },

                else => {
                    try escseq.Cursor.save(wb);
                    try escseq.Cursor.goto(wb, 0, status_low);
                    try escseq.Erase.line(wb);
                    switch (event) {
                        .Mouse => |mouse| {
                            try fmt.format(wb, "ignored chars: mouse {any}", .{mouse});
                        },
                        .Ascii => |ascii| {
                            try fmt.format(wb, "ignored chars: ascii {any}", .{ascii});
                        },
                        .Combo => |combo| {
                            try fmt.format(wb, "ignored chars: combo {any}", .{combo});
                        },
                    }
                    try escseq.Cursor.restore(wb);
                },
            }
        }
    }
}
