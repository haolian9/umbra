const std = @import("std");
const fs = std.fs;
const os = std.os;
const mem = std.mem;
const fmt = std.fmt;
const assert = std.debug.assert;

const umbra = @import("./src/umbra.zig");
const TTY = umbra.TTY;
const escseq = umbra.escseq;

const MouseEvent = struct {
    btn: Btn,
    col: u16,
    row: u16,
    state: State, // pressed on or off

    const Btn = enum(u8) {
        left = 0,
        mid = 1,
        right = 2,
        up = 64,
        down = 65,
    };

    const State = enum(u8) {
        on = 'M',
        off = 'm',
    };

    fn fromString(str: []const u8) !MouseEvent {
        // \x1b[<2;98;21m
        // \x1b[<0;2;3M
        assert(mem.startsWith(u8, str, "\x1B[<"));

        var it = mem.split(u8, str[3 .. str.len - 1], ";");

        const btn = if (it.next()) |code|
            @intToEnum(Btn, try fmt.parseInt(u8, code, 10))
        else
            return error.invalidButton;

        const col = if (it.next()) |code|
            try fmt.parseInt(u8, code, 10)
        else
            return error.invalidColumn;

        const row = if (it.next()) |code|
            try fmt.parseInt(u8, code, 10)
        else
            return error.invalidRow;

        assert(it.next() == null);

        const state = @intToEnum(State, str[str.len - 1]);

        return MouseEvent{
            .btn = btn,
            .col = col,
            .row = row,
            .state = state,
        };
    }
};

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
                        const event = try MouseEvent.fromString(input);
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
