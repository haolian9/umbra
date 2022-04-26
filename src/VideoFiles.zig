const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const rand = std.rand;

toc: Toc,
names: Names,
items: []const []const u8,

const sentinel = '\x00';

const Self = @This();
const VideoFiles = Self;

pub const Toc = std.ArrayList([]const u8);
pub const Names = std.ArrayList(u8);

pub fn init(toc: Toc, names: Names) VideoFiles{
    return VideoFiles {
        .toc = toc,
        .names = names,
        .items = toc.items[0..],
    };
}

pub fn deinit(self: Self) void {
    self.toc.deinit();
    self.names.deinit();
}

/// VideoFiles.deinit() should be called eventually.
pub fn fromRoots(allocator: mem.Allocator, roots: []const []const u8, random: ?rand.Random) !VideoFiles {
    var names = Names.init(allocator);
    errdefer names.deinit();

    for (roots) |root| {
        var dir = try fs.openDirAbsolute(root, .{ .iterate = true });
        defer dir.close();

        var it = try dir.walk(allocator);
        defer it.deinit();

        while (try it.next()) |entry| {
            if (entry.kind != fs.File.Kind.File) continue;
            if (!mem.endsWith(u8, entry.basename, ".mp4")) continue;

            const path = try fs.path.join(allocator, &.{ root, entry.path });
            defer allocator.free(path);

            try names.appendSlice(path);
            try names.append(sentinel);
        }
    }

    var toc = Toc.init(allocator);
    errdefer toc.deinit();

    var start: usize = 0;
    for (names.items) |char, index| {
        if (char == sentinel) {
            const stop = index;
            try toc.append(names.items[start..stop]);
            start = stop + 1;
        }
    }

    if (random) |r| {
        r.shuffle([]const u8, toc.items);
    }

    return VideoFiles.init(toc, names);
}
