const std = @import("std");
const mem = std.mem;
const os = std.os;
const fs = std.fs;
const process = std.process;
const assert = std.debug.assert;


pub const ArgRoots = struct {
    allocator: mem.Allocator,
    // allocated by self.allocator
    tape: []const u8,
    // allocated by self.allocator
    items: []const []const u8,

    const Self = @This();

    pub fn deinit(self: Self) void {
        self.allocator.free(self.items);
        self.allocator.free(self.tape);
    }
};

// ArgRoots.deinit() must be honored.
pub fn gatherArgRoots(allocator: mem.Allocator) !?ArgRoots {
    if (os.argv.len < 2) return null;

    const list = blk: {
        var list = std.ArrayList(u8).init(allocator);
        errdefer list.deinit();

        var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
        var it = process.ArgIteratorPosix.init();
        _ = it.skip(); // skip the program name itself.
        while (it.next()) |path| {
            const real = try os.realpath(path, &buffer);
            assert(!mem.containsAtLeast(u8, real, 1, "\x00"));
            try list.appendSlice(real);
            try list.append('\x00');
        }
        break :blk list.toOwnedSlice();
    };
    errdefer allocator.free(list);

    const roots = blk: {
        var roots = std.ArrayList([]const u8).init(allocator);
        errdefer roots.deinit();

        var start: usize = 0;
        for (list) |char, stop| {
            if (char == '\x00') {
                try roots.append(list[start..stop]);
                start = stop + 1;
            }
        }

        break :blk roots.toOwnedSlice();
    };

    return ArgRoots{
        .allocator = allocator,
        .tape = list,
        .items = roots,
    };
}
