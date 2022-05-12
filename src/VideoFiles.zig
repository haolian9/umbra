const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const rand = std.rand;
const assert = std.debug.assert;

allocator: mem.Allocator,
tape: []const u8,
items: []const []const u8,

const sentinel = '\x00';
const suffixes = [_][]const u8{".mp4", ".mkv"};

const Self = @This();
const VideoFiles = Self;

pub fn init(allocator: mem.Allocator, tape: []const u8, items: []const []const u8) VideoFiles{
    return VideoFiles {
        .allocator = allocator,
        .tape = tape,
        .items = items,
    };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.tape);
    self.allocator.free(self.items);
}

fn isVideoFile(basename: []const u8) bool {
    const ext = fs.path.extension(basename);
    inline for (suffixes) |suf| {
        if (mem.eql(u8, ext, suf)) return true;
    }
    return false;
}

/// VideoFiles.deinit() should be called eventually.
pub fn fromRoots(allocator: mem.Allocator, roots: []const []const u8, random: ?rand.Random) !VideoFiles {
    const tape = blk: {
        var list = std.ArrayList(u8).init(allocator);
        errdefer list.deinit();

        for (roots) |root| {
            var dir = try fs.openDirAbsolute(root, .{ .iterate = true });
            defer dir.close();

            var it = try dir.walk(allocator);
            defer it.deinit();

            while (try it.next()) |entry| {
                if (entry.kind != fs.File.Kind.File) continue;
                if (!isVideoFile(entry.basename)) continue;

                const path = try fs.path.join(allocator, &.{ root, entry.path });
                defer allocator.free(path);

                assert(!mem.containsAtLeast(u8, path, 1, &[1]u8{sentinel}));
                try list.appendSlice(path);
                try list.append(sentinel);
            }
        }

        break :blk list.toOwnedSlice();
    };
    errdefer allocator.free(tape);

    const toc = blk: {
        var list = std.ArrayList([]const u8).init(allocator);
        errdefer list.deinit();

        var start: usize = 0;
        for (tape) |char, stop| {
            if (char == sentinel) {
                try list.append(tape[start..stop]);
                start = stop + 1;
            }
        }

        const items = list.toOwnedSlice();

        if (random) |r| {
            r.shuffle([]const u8, items);
        }

        break :blk items;
    };
    errdefer allocator.free(toc);

    return VideoFiles.init(allocator, tape, toc);
}
