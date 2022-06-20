/// mntpoints come from /proc/mounts
/// format spec comes from mntent.h, fstab.h
const std = @import("std");
const mem = std.mem;
const linux = std.os.linux;
const assert = std.debug.assert;
const os = std.os;
const fs = std.fs;
const testing = std.testing;

allocator: mem.Allocator,
lookup: Lookup,

const Self = @This();
pub const Lookup = std.AutoHashMap(linux.dev_t, []const u8);

fn deinitLookup(allocator: mem.Allocator, l: *Lookup) void {
    var iter = l.iterator();
    while (iter.next()) |ent| {
        allocator.free(ent.value_ptr.*);
    }
    l.deinit();
}

pub fn deinit(self: *Self) void {
    deinitLookup(self.allocator, &self.lookup);
}

/// self.deinit() must be honored.
pub fn init(allocator: mem.Allocator) !Self {
    var lookup = Lookup.init(allocator);
    errdefer deinitLookup(allocator, &lookup);

    var file = try std.fs.openFileAbsolute("/proc/mounts", .{ .read = true });
    defer file.close();

    const reader = file.reader();
    var buf: [4 << 10]u8 = undefined;
    while (true) {
        const line = reader.readUntilDelimiter(buf[0..], '\n') catch |err| switch (err) {
            error.StreamTooLong => unreachable,
            error.EndOfStream => break,
            else => return err,
        };
        assert(line.len > 0);

        {
            // according to fstab, mntent, the format should be:
            // fsname, dir, type, opts, freq, passno
            var iter = mem.split(u8, line, " ");
            _ = iter.next() orelse unreachable;
            const path = iter.next() orelse unreachable;

            var stat: linux.Stat = undefined;
            switch (linux.getErrno(linux.stat(&try os.toPosixPath(path), &stat))) {
                .SUCCESS => {},
                else => unreachable,
            }

            try lookup.put(stat.dev, try allocator.dupe(u8, path));
        }
    }

    return Self{
        .allocator = allocator,
        .lookup = lookup,
    };
}

pub fn mntpoint(self: Self, file: []const u8) !?[]const u8 {
    const path = try os.toPosixPath(file);
    var stat: linux.Stat = undefined;
    switch (linux.getErrno(linux.stat(&path, &stat))) {
        .SUCCESS => {},
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.FileNotFound,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        else => unreachable,
    }

    if (self.lookup.get(stat.dev)) |point| {
        assert(mem.startsWith(u8, file, point));
        return point;
    } else return null;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(!gpa.deinit());

    const allocator = gpa.allocator();

    var mnts = try Self.init(allocator);
    defer mnts.deinit();

    std.debug.print("mntpoints:\n", .{});
    var iter = mnts.lookup.iterator();
    while (iter.next()) |ent| {
        std.debug.print("* {d}: {s}\n", .{ ent.key_ptr.*, ent.value_ptr.* });
    }
}

test "stat errors" {
    var mnts = try Self.init(testing.allocator);
    defer mnts.deinit();

    try testing.expectError(error.FileNotFound, mnts.mntpoint("/path/not/exists"));
    try testing.expectError(error.AccessDenied, mnts.mntpoint("/root/non-exist"));
}
