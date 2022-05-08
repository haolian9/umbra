const std = @import("std");
const fmt = std.fmt;

const umbra = @import("./src/umbra.zig");
const TTY = umbra.TTY;
const escseq = umbra.escseq;
const events = umbra.events;

pub fn main() !void {
    var tty = try TTY.init();
    defer tty.deinit();

    const w = tty.writer();

    try escseq.Private.enableMouseInput(w);
    defer escseq.Private.disableMouseInput(w) catch unreachable;

    try escseq.Cursor.home(w);

    {
        var buffer: [16]u8 = undefined;

        while (true) {
            const event = blk: {
                const n = try tty.getInput(&buffer);
                break :blk try events.Event.fromString(buffer[0..n]);
            };

            switch (event) {
                .Mouse => |mouse| {
                    try w.print("input:mouse: {s}\n", .{mouse});
                },
                .Char => |kb| {
                    switch (kb.char) {
                        'q', 'Q' => break,
                        '0' => try escseq.Cursor.home(w),
                        '\r', '\n' => try w.print("input:char enter\n", .{}),
                        '\t' => try w.print("input:char tab\n", .{}),
                        'h' => try escseq.Cursor.back(w, 1),
                        'j' => try escseq.Cursor.down(w, 1),
                        'k' => try escseq.Cursor.up(w, 1),
                        'l' => try escseq.Cursor.forward(w, 1),
                        else => |char| try w.print("input:char '{c}' ({d})\n", .{ char, char }),
                    }
                },
                .Rune => |kb| {
                    try w.print("input:rune: '{c}'\n", .{fmt.fmtSliceEscapeLower(kb.rune)});
                },
            }
        }
    }
}
