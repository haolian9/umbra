const std = @import("std");
const fmt = std.fmt;
const log = std.log;

const escseq = @import("./escseq.zig");

pub fn Canvas(comptime T: type, comptime item_format: []const u8) type {
    return struct {
        data: []const T,
        data_high: usize,

        // window
        window_rows: u16,
        window_high: u16,
        // status
        status_rows: u16,
        status_low: u16,
        // screen
        screen_rows: u16,
        screen_low: u16,
        screen_high: u16,

        /// ascii: 1, utf-8: 3
        item_width: u16,

        data_cursor: usize,
        screen_cursor: u16,

        const Self = @This();

        pub fn init(data: []const T, window_rows: u16, status_rows: u16, item_width: u16) Self {
            const window_high = window_rows - 1;
            const status_low = window_high - status_rows + 1;
            const screen_high = status_low - 1;
            const screen_rows = window_rows - status_rows;

            return .{
                .data = data,
                .data_high = data.len - 1,

                .window_rows = window_rows,
                .window_high = window_high,
                .status_rows = status_rows,
                .status_low = status_low,
                .screen_rows = screen_rows,
                .screen_low = 0,
                .screen_high = screen_high,

                .item_width = item_width,

                .data_cursor = 0,
                .screen_cursor = 0,
            };
        }

        pub fn resizeWindowHeight(self: *Self, window_rows: u16, wb: anytype) !void {
            if (window_rows < self.window_rows) {
                // shorter
                // todo@haoliang: keep cursor where it is or at the bottom of screen
                self.resetWindowHeight(window_rows);

                const screen_gap = self.screen_cursor;
                self.screen_cursor -= screen_gap;
                self.data_cursor -= screen_gap;
                try self.redraw(wb, false);
                try escseq.Cursor.goto(wb, 0, self.screen_cursor);
            } else if (window_rows > self.window_rows) {
                // longer
                self.resetWindowHeight(window_rows);

                try self.redraw(wb, true);
            } else {
                // no change to the height
            }
        }

        fn resetWindowHeight(self: *Self, window_rows: u16) void {
            const status_rows = self.status_rows;
            const window_high = window_rows - 1;
            const status_low = window_high - status_rows + 1;

            self.window_rows = window_rows;
            self.window_high = window_high;
            self.status_low = status_low;
            self.screen_rows = window_rows - status_rows;
            self.screen_high = status_low - 1;
        }

        pub fn redraw(self: Self, wb: anytype, remember_cursor: bool) !void {
            if (remember_cursor) try escseq.Cursor.save(wb);
            defer if (remember_cursor) escseq.Cursor.restore(wb) catch unreachable;

            try escseq.Erase.display(wb);
            try escseq.Cursor.home(wb);

            const data_low: usize = self.data_cursor - (self.screen_cursor - self.screen_low);
            const data_stop: usize = @minimum(self.data_cursor + (self.screen_high - self.screen_cursor) + 1, self.data.len);
            var data_cursor: u16 = 0;
            for (self.data[data_low..data_stop]) |item| {
                if (data_cursor != 0) {
                    try wb.writeAll("\n");
                }
                try wb.print(item_format, .{self.wrapItem(item)});
                data_cursor += 1;
            }
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
                    const item = self.data[self.data_cursor];
                    try fmt.format(wb, item_format, .{self.wrapItem(item)});
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
                if (self.data_cursor == self.data_high) {
                    // end of data, can not go further
                } else if (self.data_cursor < self.data_high) {
                    self.screen_cursor += 1;
                    self.data_cursor += 1;
                    try escseq.Cursor.nextLine(wb, 1);
                } else {
                    unreachable;
                }
            } else if (self.screen_cursor == self.screen_high) {
                // need to update the last line

                if (self.data_cursor == self.data_high) {
                    // end of data
                } else if (self.data_cursor < self.data_high) {
                    self.data_cursor += 1;
                    try escseq.Cursor.scrollUp(wb, 1);
                    try escseq.Cursor.goto(wb, 0, self.screen_cursor);
                    const item = self.data[self.data_cursor];
                    try fmt.format(wb, item_format, .{self.wrapItem(item)});
                    try escseq.Cursor.goto(wb, 0, self.screen_cursor);
                } else {
                    unreachable;
                }
            } else {
                unreachable;
            }
        }

        // should respect type of data's element
        fn wrapItem(self: Self, item: []const u8) []const u8 {
            const start = if (item.len < self.item_width) 0 else item.len - self.item_width;
            return item[start..];
        }
    };
}
