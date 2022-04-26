const std = @import("std");
const fmt = std.fmt;

const escseq = @import("./escseq.zig");

pub fn Canvas(comptime T: type, comptime item_format: []const u8) type {
    return struct {
        data: []const T,
        screen_low: u16,
        screen_high: u16,
        status_low: u16,

        data_cursor: usize,
        screen_cursor: u16,

        const Self = @This();

        pub fn redraw(self: Self, wb: anytype, remember_cursor: bool) !void {
            if (remember_cursor) try escseq.Cursor.save(wb);
            defer if (remember_cursor) escseq.Cursor.restore(wb) catch unreachable;

            try escseq.Erase.display(wb);
            try escseq.Cursor.home(wb);

            const data_low = self.data_cursor - (self.screen_cursor - self.screen_low);
            const data_high = self.data_cursor + (self.screen_high - self.screen_cursor);
            var data_cursor: u16 = 0;
            for (self.data[data_low .. data_high + 1]) |item| {
                if (data_cursor != 0) {
                    try wb.writeAll("\n");
                }
                try wb.print(item_format, .{item});
                data_cursor += 1;
            }

            try escseq.Cursor.goto(wb, 0, self.status_low);
            try wb.print("total: {}; data.[low={d},high={d}]", .{ self.data.len, data_low, data_high });
        }

        pub fn resetStatusLine(self: Self, writer: anytype, comptime format: []const u8, args: anytype) !void {
            try escseq.Cursor.save(writer);
            try escseq.Cursor.goto(writer, 0, self.status_low);
            try escseq.Erase.line(writer);
            try fmt.format(writer, format, args);
            try escseq.Cursor.restore(writer);
        }

        pub fn scrollUp(self: *Self, wb: anytype) !void {
            if (self.screen_cursor > self.screen_low) {
                self.screen_cursor -= 1;
                self.data_cursor -= 1;

                try escseq.Cursor.prevLine(wb, 1);
            } else if (self.screen_cursor == self.screen_low) {
                // self.screen_cursor no move

                if (self.data_cursor == 0) {
                    // begin of data
                } else if (self.data_cursor > self.screen_low) {
                    self.data_cursor -= 1;
                    // need to update the first line
                    try escseq.Cursor.scrollDown(wb, 1);
                    try escseq.Cursor.goto(wb, 0, self.screen_cursor);
                    try fmt.format(wb, item_format, .{self.data[self.data_cursor]});
                    try escseq.Cursor.goto(wb, 0, self.screen_cursor);
                } else {
                    unreachable;
                }
            } else {
                unreachable;
            }
        }

        pub fn scrollDown(self: *Self, wb: anytype) !void {
            if (self.screen_cursor < self.screen_high) {
                self.screen_cursor += 1;
                self.data_cursor += 1;

                try escseq.Cursor.nextLine(wb, 1);
            } else if (self.screen_cursor == self.screen_high) {
                // need to update the last line

                // self.screen_cursor no move
                const data_high = self.data.len - 1;
                if (self.data_cursor == data_high) {
                    // end of data
                } else if (self.data_cursor < data_high) {
                    self.data_cursor += 1;
                    try escseq.Cursor.scrollUp(wb, 1);
                    try escseq.Cursor.goto(wb, 0, self.screen_cursor);
                    try fmt.format(wb, item_format, .{self.data[self.data_cursor]});
                    try escseq.Cursor.goto(wb, 0, self.screen_cursor);
                } else {
                    unreachable;
                }
            } else {
                unreachable;
            }
        }
    };
}
