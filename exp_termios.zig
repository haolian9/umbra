
const std = @import("std");
const print = std.debug.print;

const umbra = @import("./src/umbra.zig");
const TTY = umbra.TTY;


pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer gpa.deinit();
    // const allocator = gpa.allocator();

    var tty = try TTY.init();
    // defer tty.deinit();

    // const winsize = try tty.getWinSize();

    const w = tty.writer();

    try w.print("{any}", .{tty.term});
}

