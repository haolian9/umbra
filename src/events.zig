const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const fmt = std.fmt;
const testing = std.testing;

pub const Event = union(enum) {
    mouse: Mouse,
    symbol: KeySymbol,
    codes: KeyCodes,

    const Self = @This();

    pub fn fromString(input: []const u8) !Event {
        if (input[0] == '\x1B') {
            if (input.len == 1) {
                return Event{ .symbol = .{ .symbol = '\x1B' } };
            }

            if (input[1] == '[') {
                return switch (input[2]) {
                    '<' => Event{ .mouse = try Mouse.fromString(input) },
                    else => Event{ .codes = .{ .codes = input } },
                };
            } else {
                return Event{ .codes = .{ .codes = input } };
            }
        } else if (input.len == 1) {
            return Event{ .symbol = .{ .symbol = input[0] } };
        } else {
            unreachable;
        }
    }

    pub fn format(self: Self, comptime _: []const u8, options: fmt.FormatOptions, writer: anytype) !void {
        _ = options;

        switch (self) {
            .mouse => |mouse| {
                try fmt.format(writer, "ignored mouse: {any}", .{mouse});
            },
            .symbol => |symbol| {
                try fmt.format(writer, "ignored char: {c}", .{symbol.symbol});
            },
            .codes => |codes| {
                try fmt.format(writer, "ignored codes: {any}", .{codes.codes});
            },
        }
    }
};

pub const Mouse = struct {
    btn: Btn,
    // 0-based
    col: u16,
    // 0-based
    row: u16,
    press_state: PressState, // pressed on or off

    pub const Btn = enum(u8) {
        left = 0,
        mid = 1,
        right = 2,
        up = 64,
        down = 65,
        left_drag = 32, // 左键拖动
        right_drag = 34, // 右键拖动
    };

    pub const PressState = enum(u8) {
        down = 'M',
        up = 'm',
    };

    pub fn fromString(str: []const u8) !Mouse {
        // \x1b[<2;98;21m
        // \x1b[<0;2;3M
        assert(mem.startsWith(u8, str, "\x1B[<"));

        var it = mem.split(u8, str[3 .. str.len - 1], ";");

        const btn = if (it.next()) |code|
            @intToEnum(Btn, try fmt.parseInt(u8, code, 10))
        else
            return error.MissingButton;

        const col: u16 = blk: {
            if (it.next()) |code| {
                const orig = try fmt.parseInt(u8, code, 10);
                break :blk orig - 1;
            } else {
                return error.MissingColumn;
            }
        };

        const row: u16 = blk: {
            if (it.next()) |code| {
                const orig = try fmt.parseInt(u8, code, 10);
                break :blk orig - 1;
            } else {
                return error.MissingRow;
            }
        };

        assert(it.next() == null);

        const press_state = @intToEnum(PressState, str[str.len - 1]);

        return Mouse{
            .btn = btn,
            .col = col,
            .row = row,
            .press_state = press_state,
        };
    }
};

pub const KeySymbol = struct {
    symbol: u8,
};

pub const KeyCodes = struct {
    codes: []const u8,
};

test "parse Mouse event" {
    _ = try Mouse.fromString("\x1b[<2;98;21m");
    _ = try Mouse.fromString("\x1b[<0;2;3M");
}

test "parse Event" {
    _ = try Event.fromString("\x1b[<2;98;21m");
    _ = try Event.fromString("\x1b[<0;2;3M");
    _ = try Event.fromString("\x1b");
    _ = try Event.fromString("\x1b[123");
    _ = try Event.fromString("\x1b123");
    _ = try Event.fromString("1");
}
