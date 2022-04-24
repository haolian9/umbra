
const std = @import("std");
const print = std.debug.print;

const umbra = @import("./src/umbra.zig");
const escseq = umbra.escseq;
const TTY = umbra.TTY;


pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer gpa.deinit();
    // const allocator = gpa.allocator();

    var tty = try TTY.init();
    defer tty.deinit();

    // const winsize = try tty.getWinSize();

    {
        var buffer = tty.buffered_writer();
        defer buffer.flush() catch unreachable;

        const wb = buffer.writer();
        const Cap = escseq.Cap;

        try Cap.toStatusLine(.Alacritty, wb);
        try wb.writeAll("hello 1/10");
        try Cap.fromStatusLine(wb);
    }

    var input_buffer: [16]u8 = undefined;
    _ = try tty.getInput(&input_buffer);
}

