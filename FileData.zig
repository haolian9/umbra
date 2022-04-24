const std = @import("std");
const fs = std.fs;
const print = std.debug.print;
const assert = std.debug.assert;
const mem = std.mem;

const FileEntry = struct {
    path: Range,
    // stem: []const u8,
    // ext: []const u8,
    // size: usize,
    // mtime: i64,
};

const Self = @This();
const FileData = Self;
const Context = Self;

const Range = struct {
    start: usize,
    // stop is exclusive
    stop: usize,
};

pub const Iterator = struct {
    context: *Context,
    range: Range,
    cursor: usize,

    pub fn next(self: *Iterator) ?[]const u8 {
        if (self.cursor >= self.range.stop) return null;

        defer self.cursor += 1;
        const entry = self.context.toc.items[self.cursor];
        return self.context.volume.items[entry.path.start..entry.path.stop];
    }
};


allocator: mem.Allocator,
root: []const u8,

toc: std.ArrayList(FileEntry),
volume: std.ArrayList(u8),

pub fn init(allocator: mem.Allocator, root: []const u8) !FileData {
    var fdata = FileData{
        .allocator = allocator,
        .root = root,
        .toc = std.ArrayList(FileEntry).init(allocator),
        .volume = std.ArrayList(u8).init(allocator),
    };

    try fdata.load();

    return fdata;
}

pub fn deinit(self: *Self) void {
    self.toc.deinit();
    self.volume.deinit();
}

pub fn reload(self: *Self) !void {
    self.toc.clearAndFree();
    self.volume.clearAndFree();
    try self.load();
}

fn load(self: *Self) !void {
    var root_dir = try fs.openDirAbsolute(self.root, .{ .iterate = true });
    defer root_dir.close();

    var walker = try root_dir.walk(self.allocator);
    defer walker.deinit();

    while (walker.next()) |maybe| {
        if (maybe) |entry| {
            if (entry.kind != .File) continue;
            if (!mem.endsWith(u8, entry.basename, ".mp4")) continue;

            const fe = try self.toc.addOne();
            {
                var path = try fs.path.join(self.allocator, &.{ self.root, entry.path });
                defer self.allocator.free(path);

                fe.path.start = self.volume.items.len;
                fe.path.stop = fe.path.start + path.len;
                try self.volume.appendSlice(path);
            }
        } else break;
    } else |err| switch (err) {
        error.AccessDenied => {},
        else => {
            print("Error: {s}", .{err});
        },
    }
}

pub fn iterate(self: *Self, start: ?usize, stop: ?usize) Iterator {
    const left = start orelse 0;
    const right = if (stop) |val| @minimum(val, self.toc.items.len) else self.toc.items.len;
    return .{
        .context = self,
        .range = .{
            .start = left,
            .stop = right,
        },
        .cursor = left,
    };
}


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == false);

    const a = gpa.allocator();

    var fdata = try FileData.init(a, "/oasis/deluge/completed");
    defer fdata.deinit();

    var it = fdata.iterate(null, null);

    while (it.next()) |path| {
        print("{s}\n", .{path});
    }
}

// # asyncrun: zig test
