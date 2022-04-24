const std = @import("std");
const log = std.log;
const print = std.debug.print;
const assert = std.debug.assert;
const fmt = std.fmt;

const umbra = @import("./src/umbra.zig");
const TTY = umbra.TTY;
const escseq = umbra.escseq;

const FileData = @import("./FileData.zig");

pub fn main() !void {
    var tty = try TTY.init();
    defer tty.deinit();

    var bufw = tty.buffered_writer();
    _ = bufw;
    const winsize = try tty.getWinSize();
    _ = winsize;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == false);
    const allocator = gpa.allocator();

    var data = try FileData.init(allocator, "/oasis/deluge/sync");
    defer data.deinit();

    {
        defer bufw.flush() catch unreachable;

        var it = data.iterate(0, winsize.row_total);
        const wb = bufw.writer();

        while (it.next()) |path| {
            try fmt.format(wb, "* {s}\n", .{path});
        }
    }

    var input_buf: [16]u8 = undefined;
    _ = try tty.getInput(&input_buf);
}
