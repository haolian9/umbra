//
// scroll
//

const std = @import("std");
const assert = std.debug.assert;
const fmt = std.fmt;

const umbra = @import("src/umbra.zig");
const Canvas = umbra.Canvas;
const TTY = umbra.TTY;
const escseq = umbra.escseq;
const events = umbra.events;

fn handleKeySymbol(wb: anytype, canvas: *Canvas, ev: events.KeySymbol) !void {
    switch (ev.symbol) {
        'q' => return error.Quit,
        'j' => try canvas.scrollDown(wb),
        'k' => try canvas.scrollUp(wb),

        'L' => try canvas.gotoLastLineOnScreen(wb),
        'H' => try canvas.gotoFirstLineOnScreen(wb),
        'g' => try canvas.gotoFirstLine(wb),
        'G' => try canvas.gotoLastLine(wb),

        else => |symbol| {
            try canvas.resetStatusLine(wb, "{c} {d}", .{ symbol, symbol });
        },
    }
}

fn handleMouse(wb: anytype, canvas: *Canvas, ev: events.Mouse) !void {
    switch (ev.btn) {
        .up => try canvas.scrollUp(wb),
        .down => try canvas.scrollDown(wb),
        .left => switch (ev.press_state) {
            .down => {},
            .up => try canvas.gotoLineOnScreen(wb, ev.row),
        },
        else => {
            try canvas.resetStatusLine(wb, "{any}", .{ev});
        },
    }
}

fn handleKeyCodes(wb: anytype, canvas: Canvas, ev: events.KeyCodes) !void {
    try canvas.resetStatusLine(wb, "{any}", .{ev});
}

pub fn main() !void {
    var tty = try TTY.init();
    defer tty.deinit();

    const winsize = try tty.getWinSize();

    var buffer = tty.buffered_writer();
    defer buffer.flush() catch unreachable;

    const w = tty.writer();
    const wb = buffer.writer();

    const data: [][]const u8 = blk: {
        var data: [126 - 33 + 1][]const u8 = undefined;
        var i: u8 = 33;
        while (i <= 126) : (i += 1) {
            data[i - 33] = &.{i};
        }
        break :blk &data;
    };

    var canvas = Canvas.init(data, winsize.row_total, 2, winsize.col_total - 1);

    // construct frames
    try escseq.Cap.changeScrollableRegion(w, 0, canvas.screen_high);
    try escseq.Private.enableMouseInput(w);
    defer escseq.Private.disableMouseInput(w) catch unreachable;

    // first draw
    try canvas.redraw(wb, true);
    try escseq.Cursor.home(wb);
    try canvas.resetStatusLine(wb, "data: {any}", .{@TypeOf(data)});
    try buffer.flush();

    // interact
    {
        defer buffer.flush() catch unreachable;

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
                .mouse => |mouse| {
                    try handleMouse(wb, &canvas, mouse);
                },
                .symbol => |symbol| {
                    handleKeySymbol(wb, &canvas, symbol) catch |err| switch (err) {
                        error.Quit => break,
                        else => return err,
                    };
                },
                .codes => |codes| {
                    try handleKeyCodes(wb, canvas, codes);
                },
            }
        }
    }
}
