const std = @import("std");
const fs = std.fs;
const os = std.os;
const mem = std.mem;
const fmt = std.fmt;
const assert = std.debug.assert;

const umbra = @import("./src/umbra.zig");
const TTY = umbra.TTY;
const escseq = umbra.escseq;
const events = umbra.events;


pub fn inputLoop(tty: *umbra.TTY) !void {
    var buffer: [16]u8 = undefined;

    const w = tty.writer();

    while (true) {
        const input = blk: {
            const n = try tty.getInput(&buffer);
            break :blk buffer[0..n];
        };

        if (input[0] == '\x1B') {
            if (input.len == 0) {
                try w.print("input: esc\n", .{});
                continue;
            }

            if (input[1] == '[') {
                switch (input[2]) {
                    'A' => try escseq.Cursor.up(w, 1),
                    'B' => try escseq.Cursor.down(w, 1),
                    'C' => try escseq.Cursor.forward(w, 1),
                    'D' => try escseq.Cursor.back(w, 1),
                    '<' => {
                        const event = try events.MouseEvent.fromString(input);
                        try w.print("input: mouse: {s}\n", .{event});
                    },
                    else => {},
                }
                continue;
            }

            try w.print("input: esc-seq: {d} '{s}'\n", .{ input, fmt.fmtSliceEscapeLower(input) });
        } else if (input.len == 1) {
            switch (input[0]) {
                'q', 'Q' => break,
                '0' => try escseq.Cursor.home(w),
                '\r', '\n' => try w.print("input: enter\n", .{}),
                '\t' => try w.print("input: tab\n", .{}),
                'h' => try escseq.Cursor.back(w, 1),
                'j' => try escseq.Cursor.down(w, 1),
                'k' => try escseq.Cursor.up(w, 1),
                'l' => try escseq.Cursor.forward(w, 1),
                else => |char| try w.print("input: {d} '{u}'\n", .{ char, char }),
            }
        } else {
            unreachable;
        }
    }
}

pub fn main() !void {
    var tty = try TTY.init();
    defer tty.deinit();

    const w = tty.writer();

    try escseq.Private.enableMouseInput(w);
    defer escseq.Private.disableMouseInput(w) catch unreachable;

    try escseq.Cursor.home(w);

    try inputLoop(&tty);
}
