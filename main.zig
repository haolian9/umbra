const std = @import("std");
const print = std.debug.print;
const fs = std.fs;
const io = std.io;
const fmt = std.fmt;

const umbra = @import("../src/umbra.zig");
const TTY = umbra.TTY;
const EscSeq = TTY.EscSeq;

pub fn main() !void {
    print("hello and welcome\n", .{});
}

fn isatty() !void {
    var file = fs.openFileAbsolute("/dev/tty", .{ .read = true, .write = true }) catch |err| {
        print("open /dev/tty failed: {}\n", .{err});
        print("/dev/tty isatty: {}\n", .{false});
        return;
    };
    defer file.close();
    print("/dev/tty isatty: {}\n", .{std.os.isatty(file.handle)});
}

fn buffered() !void {
    var tty = try TTY.init();
    defer tty.deinit();

    var input: [16]u8 = undefined;
    var bufw = tty.buffered_writer();
    const wb = bufw.writer();

    try wb.writeAll("hello and welcome");
    print("w1: #{} >>{s}<<\n", .{ bufw.fifo.buf.len, fmt.fmtSliceEscapeLower(bufw.fifo.buf[0..32]) });

    try wb.writeAll("django unchained\n");
    print("w2: #{} >>{s}<<\n", .{ bufw.fifo.buf.len, fmt.fmtSliceEscapeLower(bufw.fifo.buf[0..32]) });

    {
        _ = try tty.getInput(&input);
        try bufw.flush();
        print("flush: #{} >>{s}<<\n", .{ bufw.fifo.buf.len, fmt.fmtSliceEscapeLower(bufw.fifo.buf[0..32]) });
        _ = try tty.getInput(&input);
    }
}
