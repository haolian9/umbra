const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const testing = std.testing;
const logger = std.log;

const escseq = @import("./escseq.zig");

const PathParts = struct {
    // no trailing slash
    dir: ?[]const u8,
    stem: []const u8,
    ext: []const u8,

    fn parse(path: []const u8) PathParts {
        // TODO@haoliang optimize
        const dir = fs.path.dirname(path);
        const base = fs.path.basename(path);
        const ext = fs.path.extension(base);
        const stem = base[0 .. base.len - ext.len];

        return .{ .dir = dir, .stem = stem, .ext = ext };
    }
};

data: [][]const u8,
data_high: usize,

// window = status + screen
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

pub fn init(data: [][]const u8, window_rows: u16, status_rows: u16, item_width: u16) Self {
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

fn relocateCursor(self: Self, wb: anytype) !void {
    try escseq.Cursor.goto(wb, 0, self.screen_cursor);
}

pub fn resizeScreen(self: *Self, window_rows: u16, wb: anytype) !void {
    // TODO@haoliang handles width/columns resize
    if (window_rows < self.window_rows) {
        // shorter
        self.resetGridsBound(window_rows);
        try self.resetScrollableRegion(wb);

        if (self.screen_cursor > self.screen_high) {
            const shrinked_rows = self.screen_cursor - self.screen_high;
            self.screen_cursor -= shrinked_rows;
            self.data_cursor -= shrinked_rows;
            try self.relocateCursor(wb);
        }

        try self.redraw(wb, true);
        try self.highlightCurrentLine(wb);
    } else if (window_rows > self.window_rows) {
        // longer
        self.resetGridsBound(window_rows);
        try self.resetScrollableRegion(wb);

        try self.redraw(wb, true);
        try self.highlightCurrentLine(wb);
    } else {
        // no change to the height
    }
}

fn resetGridsBound(self: *Self, window_rows: u16) void {
    const window_high = window_rows - 1;
    const screen_rows = window_high - self.status_rows + 1;

    self.screen_rows = screen_rows;
    self.screen_high = screen_rows - 1;
    self.window_rows = window_high + 1;
    self.window_high = window_high;
    self.status_low = window_high + 1;
}

/// cursor would move to the end of line
fn resetCurrentLine(self: Self, wb: anytype) !void {
    try escseq.Erase.line(wb);
    const item = self.data[self.data_cursor];
    try self.writeItem(wb, item);
}

/// no cursor moves
pub fn highlightCurrentLine(self: Self, wb: anytype) !void {
    try escseq.Cursor.save(wb);
    try escseq.Erase.line(wb);
    try self.writeHighlightedItem(wb, self.data[self.data_cursor]);
    try escseq.Cursor.restore(wb);
}

fn writeItem(self: Self, wb: anytype, item: []const u8) !void {
    try wb.print(" {s}", .{self.wrapItem(item)});
}

fn writeHighlightedItem(self: Self, wb: anytype, item: []const u8) !void {
    const parts = PathParts.parse(self.wrapItem(item));

    if (parts.dir) |dir| {
        try wb.print(" {s}/", .{dir});
    } else {
        try wb.print(" ", .{});
    }
    try escseq.SGR.rendition(wb, &.{ .fg_red, .bold });
    try wb.print("{s}", .{parts.stem});
    try escseq.SGR.rendition(wb, &.{.reset});
    try wb.print("{s}", .{parts.ext});
}

pub fn redraw(self: Self, wb: anytype, remember_cursor: bool) !void {
    // todo: redraw partial: cursor-{down,up}ward
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
        try self.writeItem(wb, item);
        data_cursor += 1;
    }
}

pub fn resetStatusLine(self: Self, writer: anytype, comptime fmt: []const u8, args: anytype) !void {
    try escseq.Cursor.save(writer);
    try escseq.Cursor.goto(writer, 0, self.status_low);
    try escseq.Erase.line(writer);
    try std.fmt.format(writer, fmt, args);
    try escseq.Cursor.restore(writer);
}

pub fn scrollUp(self: *Self, wb: anytype) !void {
    if (self.screen_cursor > self.screen_low) {
        try self.resetCurrentLine(wb);
        self.screen_cursor -= 1;
        self.data_cursor -= 1;
        try escseq.Cursor.prevLine(wb, 1);
        try self.writeHighlightedItem(wb, self.data[self.data_cursor]);
        try self.relocateCursor(wb);
    } else if (self.screen_cursor == self.screen_low) {
        // self.screen_cursor no move

        if (self.data_cursor == 0) {
            // begin of data
        } else if (self.data_cursor > self.screen_low) {
            try self.resetCurrentLine(wb);
            self.data_cursor -= 1;
            // need to update the first line
            try escseq.Cursor.scrollDown(wb, 1);
            try self.relocateCursor(wb);
            try self.writeHighlightedItem(wb, self.data[self.data_cursor]);
            try self.relocateCursor(wb);
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
            try self.resetCurrentLine(wb);
            self.screen_cursor += 1;
            self.data_cursor += 1;
            try escseq.Cursor.nextLine(wb, 1);
            try self.writeHighlightedItem(wb, self.data[self.data_cursor]);
            try self.relocateCursor(wb);
        } else {
            unreachable;
        }
    } else if (self.screen_cursor == self.screen_high) {
        // need to update the last line

        if (self.data_cursor == self.data_high) {
            // end of data
        } else if (self.data_cursor < self.data_high) {
            try self.resetCurrentLine(wb);
            self.data_cursor += 1;
            try escseq.Cursor.scrollUp(wb, 1);
            try self.relocateCursor(wb);
            try self.writeHighlightedItem(wb, self.data[self.data_cursor]);
            try self.relocateCursor(wb);
        } else {
            unreachable;
        }
    } else {
        unreachable;
    }
}

// should respect type of data's element
pub fn wrapItem(self: Self, item: []const u8) []const u8 {
    const start = if (item.len < self.item_width) 0 else item.len - self.item_width;
    return item[start..];
}

pub fn gotoLastLineOnScreen(self: *Self, wb: anytype) !void {
    const screen_gap: u16 = self.screen_high - self.screen_cursor;

    if (screen_gap == 0) return;

    try self.resetCurrentLine(wb);
    // it's possible that data_gap < screen_gap
    const expected = self.data_cursor + screen_gap;
    const data_gap: usize = if (self.data_high < expected)
        self.data_high - self.data_cursor
    else
        screen_gap;
    self.screen_cursor += @intCast(u16, data_gap);
    self.data_cursor += data_gap;
    try self.relocateCursor(wb);
    try self.highlightCurrentLine(wb);
}

pub fn gotoFirstLineOnScreen(self: *Self, wb: anytype) !void {
    const gap: u16 = self.screen_cursor - self.screen_low;

    if (gap == 0) return;

    try self.resetCurrentLine(wb);
    self.screen_cursor = self.screen_low;
    self.data_cursor -= gap;
    try self.relocateCursor(wb);
    try self.highlightCurrentLine(wb);
}

pub fn gotoFirstLine(self: *Self, wb: anytype) !void {
    if (self.data_cursor == 0) return;

    self.screen_cursor = self.screen_low;
    self.data_cursor = 0;
    try self.redraw(wb, false);
    try self.relocateCursor(wb);
    try self.highlightCurrentLine(wb);
}

pub fn gotoLastLine(self: *Self, wb: anytype) !void {
    // data.len could be less than one screen
    if (self.data_high >= self.screen_high) {
        self.screen_cursor = self.screen_high;
        self.data_cursor = self.data_high;
    } else {
        const data_short = self.screen_high - @intCast(u16, self.data_high);
        self.screen_cursor = self.screen_high - data_short;
        self.data_cursor = self.data_high;
    }
    try self.redraw(wb, false);
    try self.relocateCursor(wb);
    try self.highlightCurrentLine(wb);
}

/// row: 0-based
pub fn gotoLineOnScreen(self: *Self, wb: anytype, row: u16) !void {
    if (row < self.screen_cursor) {
        try self.resetCurrentLine(wb);
        const gap = self.screen_cursor - row;
        self.screen_cursor -= gap;
        self.data_cursor -= gap;
        try self.relocateCursor(wb);
        try self.highlightCurrentLine(wb);
    } else if (row > self.screen_cursor) {
        const gap = row - self.screen_cursor;
        if (gap <= self.data_high - self.data_cursor) {
            try self.resetCurrentLine(wb);
            self.screen_cursor += gap;
            self.data_cursor += gap;
            try self.relocateCursor(wb);
            try self.highlightCurrentLine(wb);
        } else {
            // stay
            try self.resetStatusLine(wb, "click outside of data", .{});
        }
    } else {
        // stay
    }
}

pub fn resetScrollableRegion(self: Self, wb: anytype) !void {
    try escseq.Cap.changeScrollableRegion(wb, 0, self.screen_high);
    try self.relocateCursor(wb);
}

pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;
    try std.fmt.format(writer, "<Canvas: data_cursor={}, screen_cursor={}, data_high={}, windows_rows={}, windows_high={}, status_rows={}, status_low={}, screen_rows={}, screen_low={}, screen_high={}, item_width={}>", .{
        self.data_cursor,
        self.screen_cursor,
        self.data_high,
        self.window_rows,
        self.window_high,
        self.status_rows,
        self.status_low,
        self.screen_rows,
        self.screen_low,
        self.screen_high,
        self.item_width,
    });
}

test "path parts" {
    {
        const parts = PathParts.parse("/tmp/a.mp4");
        const expected = PathParts{ .dir = "/tmp", .stem = "a", .ext = ".mp4" };
        try testing.expect(mem.eql(u8, expected.dir.?, parts.dir.?));
        try testing.expect(mem.eql(u8, expected.stem, parts.stem));
        try testing.expect(mem.eql(u8, expected.ext, parts.ext));
    }
}

// # asyncrun: zig test
