const std = @import("std");
const io = std.io;
const os = std.os;
const print = std.debug.print;
const mem = std.mem;
const fs = std.fs;

pub fn main() !void {
    var flag_pipeline = false;

    {
        var args = std.process.ArgIteratorPosix.init();
        // skip the first arg, which is the program name
        _ = args.next();
        while (args.next()) |a| {
            if (mem.eql(u8, a, "-")) {
                flag_pipeline = true;
                break;
            }
        }
    }

    if (!flag_pipeline) return;

    var stdin = io.getStdIn();
    var reader = stdin.reader();

    var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
    while (true) {
        const line = reader.readUntilDelimiter(buffer[0..], '\n') catch |err| switch (err) {
            error.EndOfStream => break,
            else => unreachable,
        };
        print("* '{s}'\n", .{line});
    }
}
