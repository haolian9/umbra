/// mntpoints come from fstab
const std = @import("std");
const mem = std.mem;
const linux = std.os.linux;
const assert = std.debug.assert;
const os = std.os;

const c_fstab = @cImport(@cInclude("fstab.h"));

allocator: mem.Allocator,
lookup: Lookup,

const Self = @This();
pub const Lookup = std.AutoHashMap(linux.dev_t, []const u8);

const FstabEnt = extern struct {
    spec: [*:0]u8,
    file: [*:0]u8,
    vfstype: [*:0]u8,
    mntops: [*:0]u8,
    type: [*:0]const u8,
    req: c_int,
    passno: c_int,
};

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

    {
        errdefer c_fstab.endfsent();

        while (c_fstab.getfsent()) |raw| {
            const ent = @ptrCast(*FstabEnt, raw);
            var stat: linux.Stat = undefined;
            switch (linux.getErrno(linux.stat(ent.file, &stat))) {
                .SUCCESS => {},
                else => unreachable,
            }

            const path = try allocator.dupe(u8, std.mem.sliceTo(ent.file, 0));
            try lookup.put(stat.dev, path);
        } else {
            c_fstab.endfsent();
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
