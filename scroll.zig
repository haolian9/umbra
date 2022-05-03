//
// scroll
//

const std = @import("std");
const assert = std.debug.assert;
const fmt = std.fmt;

const umbra = @import("./src/umbra.zig");
const TTY = umbra.TTY;
const escseq = umbra.escseq;
const events = umbra.events;

const Canvas = umbra.Canvas(u16, " {d}");

fn handleCharKeyboardEvent(wb: anytype, canvas: *Canvas, ev: events.CharKeyboardEvent) !void {
    switch (ev.char) {
        'q' => return error.Quit,
        'j' => try canvas.scrollDown(wb),
        'k' => try canvas.scrollUp(wb),

        'L' => {
            // go to the last line of the screen
            const gap = canvas.screen_high - canvas.screen_cursor;
            if (gap == 0) {
                // stay
            } else if (gap > 0) {
                canvas.screen_cursor = canvas.screen_high;
                canvas.data_cursor += gap;
                try escseq.Cursor.goto(wb, 0, canvas.screen_cursor);
            } else {
                unreachable;
            }
        },
        'H' => {
            // go to the first line of the screen
            const gap = canvas.screen_cursor - canvas.screen_low;
            if (gap == 0) {
                // stay
            } else if (gap > 0) {
                canvas.screen_cursor = canvas.screen_low;
                canvas.data_cursor -= gap;
                try escseq.Cursor.goto(wb, 0, canvas.screen_cursor);
            } else {
                unreachable;
            }
        },
        'g' => {
            // go to the first line of the data
            canvas.screen_cursor = canvas.screen_low;
            canvas.data_cursor = 0;
            try canvas.redraw(wb, false);
            try escseq.Cursor.goto(wb, 0, canvas.screen_cursor);
        },
        'G' => {
            // go to the last line of the data
            canvas.screen_cursor = canvas.screen_high;
            canvas.data_cursor = canvas.data.len - 1;
            try canvas.redraw(wb, false);
            try escseq.Cursor.goto(wb, 0, canvas.screen_cursor);
        },

        'r' => {
            try canvas.redraw(wb, true);
        },

        else => {
            try escseq.Cursor.save(wb);
            try escseq.Cursor.goto(wb, 0, canvas.status_low);
            try escseq.Erase.line(wb);
            try fmt.format(wb, "{}", .{ev});
            try escseq.Cursor.restore(wb);
        },
    }
}

fn handleMouseEvent(wb: anytype, canvas: *Canvas, ev: events.MouseEvent) !void {
    switch (ev.btn) {
        .Up => try canvas.scrollUp(wb),
        .Down => try canvas.scrollDown(wb),
        .Left => switch (ev.press_state) {
            .Down => {},
            .Up => {
                canvas.screen_cursor = ev.row;
                try escseq.Cursor.goto(wb, 0, canvas.screen_cursor);
            },
        },
        else => {
            try canvas.resetStatusLine(wb, "{any}", .{ev});
        },
    }
}

fn handleRuneKeyboardEvent(wb: anytype, canvas: Canvas, ev: events.RuneKeyboardEvent) !void {
    try canvas.resetStatusLine(wb, "{any}", .{ev});
}

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

    var canvas: Canvas = blk: {
        const status_rows = 1;
        const screen_high = winsize.row_high - status_rows;
        const status_low = screen_high + 1;

        break :blk Canvas{
            .data = data,
            .screen_low = 0,
            .screen_high = screen_high,
            .status_low = status_low,

            .data_cursor = 0,
            .screen_cursor = 0,
        };
    };

    // construct frames
    try escseq.Cap.changeScrollableRegion(w, 0, canvas.screen_high);
    try escseq.Private.enableMouseInput(w);
    defer escseq.Private.disableMouseInput(w) catch unreachable;

    // first draw
    try canvas.redraw(wb, true);
    try buffer.flush();

    // interact
    {
        defer buffer.flush() catch unreachable;

        try escseq.Cursor.home(w);

        var input_buffer: [16]u8 = undefined;

        while (true) {
            defer buffer.flush() catch unreachable;

            const event: events.Event = blk: {
                const n = try tty.getInput(&input_buffer);
                const input = input_buffer[0..n];
                break :blk events.Event.fromString(input) catch |err| switch (err) {
                    // 连续滚动鼠标滚轮，有很大概率会出现这个错误
                    // 我们目前先忽略掉这个错误
                    error.InvalidCharacter => continue,
                    else => return err,
                };
            };

            switch (event) {
                .Mouse => |mouse| {
                    try handleMouseEvent(wb, &canvas, mouse);
                },
                .Char => |char| {
                    handleCharKeyboardEvent(wb, &canvas, char) catch |err| switch (err) {
                        error.Quit => break,
                        else => return err,
                    };
                },
                .Rune => |rune| {
                    try handleRuneKeyboardEvent(wb, canvas, rune);
                },
            }
        }
    }
}
