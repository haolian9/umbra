const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();
    const strip = mode != .Debug;

    {
        const exe = b.addExecutable("umbra", "main.zig");
        exe.setBuildMode(mode);
        exe.strip = strip;
        exe.addPackage(.{ .name = "config", .source = .{ .path = "config.zig" } });
        exe.single_threaded = true;
        exe.install();
    }

    inline for (.{ .{ "input", "input.zig" }, .{ "scroll", "scroll.zig" } }) |tuple| {
        const exe = b.addExecutable(tuple[0], tuple[1]);
        exe.setBuildMode(mode);
        exe.strip = strip;
        exe.single_threaded = true;
        exe.install();
    }
}
