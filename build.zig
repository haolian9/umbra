const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();
    const strip = mode != .Debug;

    const exe = b.addExecutable("umbra", "main.zig");
    exe.setBuildMode(mode);
    exe.strip = strip;
    exe.single_threaded = true;
    exe.install();
}
