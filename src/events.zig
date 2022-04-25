const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const fmt = std.fmt;

pub const Event = union(enum) {
    Mouse: MouseEvent,
    Ascii: AsciiKeyboardEvent,
    Combo: ComboKeyboardEvent,

    pub fn fromString(input: []const u8) !Event {
        if (input[0] == '\x1B') {
            if (input.len == 1) {
                return Event{ .Ascii = .{ .char = '\x1B' } };
            }

            if (input[1] == '[') {
                return switch (input[2]) {
                    '<' => Event{ .Mouse = try MouseEvent.fromString(input) },
                    else => Event{ .Combo = .{ .chars = input } },
                };
            } else {
                return Event{ .Combo = .{ .chars = input } };
            }
        } else if (input.len == 1) {
            return Event{ .Ascii = .{ .char = input[0] } };
        } else {
            unreachable;
        }
    }
};

pub const MouseEvent = struct {
    btn: Btn,
    col: u16,
    row: u16,
    state: State, // pressed on or off

    pub const Btn = enum(u8) {
        left = 0,
        mid = 1,
        right = 2,
        up = 64,
        down = 65,
    };

    pub const State = enum(u8) {
        on = 'M',
        off = 'm',
    };

    pub fn fromString(str: []const u8) !MouseEvent {
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

pub const AsciiKeyboardEvent = struct {
    char: u8,
};

pub const ComboKeyboardEvent = struct {
    chars: []const u8,
};
