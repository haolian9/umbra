const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const rand = std.rand;
const assert = std.debug.assert;
const log = std.log;

allocator: std.heap.ArenaAllocator,
items: [][]const u8,

const suffixes = [_][]const u8{ ".mp4", ".mkv" };

const Self = @This();
const VideoFiles = Self;

pub fn deinit(self: *Self) void {
    self.allocator.deinit();
}

fn isVideoFile(basename: []const u8) bool {
    const ext = fs.path.extension(basename);
    return inline for (suffixes) |suf| {
        if (mem.eql(u8, ext, suf)) break true;
    } else false;
}

/// VideoFiles.deinit() should be called eventually.
pub fn init(base_allocator: mem.Allocator, roots: []const []const u8) !VideoFiles {
    var arena_alloc = std.heap.ArenaAllocator.init(base_allocator);
    errdefer arena_alloc.deinit();

    const allocator = arena_alloc.allocator();

    var list = std.ArrayList([]const u8).init(allocator);

    for (roots) |root| {
        var dir = fs.openDirAbsolute(root, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => {
                log.info("{s} not exists, skipped", .{root});
                continue;
            },
            error.AccessDenied => {
                log.info("{s} is not accessible, skipped", .{root});
                continue;
            },
            else => {
                log.err("open dir error: {s} {}", .{ root, err });
                unreachable;
            },
        };
        defer dir.close();

        var it = try dir.walk(base_allocator);
        defer it.deinit();

        while (try it.next()) |entry| {
            if (entry.kind != fs.File.Kind.file) continue;
            if (!isVideoFile(entry.basename)) continue;

            const path = try fs.path.join(allocator, &.{ root, entry.path });
            errdefer allocator.free(path);

            try list.append(path);
        }
    }

    const items = try list.toOwnedSlice();

    return VideoFiles{
        .allocator = arena_alloc,
        .items = items,
    };
}
