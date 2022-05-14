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
                .mouse => |mouse| {
                    try w.print("input:mouse: {s}\n", .{mouse});
                },
                .symbol => |symbol| {
                    switch (symbol.symbol) {
                        'q', 'Q' => break,
                        '0' => try escseq.Cursor.home(w),
                        '\r', '\n' => try w.print("input:symbol enter\n", .{}),
                        '\t' => try w.print("input:symbol tab\n", .{}),
                        'h' => try escseq.Cursor.back(w, 1),
                        'j' => try escseq.Cursor.down(w, 1),
                        'k' => try escseq.Cursor.up(w, 1),
                        'l' => try escseq.Cursor.forward(w, 1),
                        else => |sym| try w.print("input:symbol '{c}' ({d})\n", .{ sym, sym }),
                    }
                },
                .codes => |codes| {
                    try w.print("input:codes: '{c}'\n", .{fmt.fmtSliceEscapeLower(codes.codes)});
                },
            }
        }
    }
}
