const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const optimize = b.standardOptimizeOption(.{});

    {
        const bin = b.addExecutable(.{
            .name = "umbra",
            .root_source_file = .{ .path = "main.zig" },
            .optimize = optimize,
            .single_threaded = true,
        });
        bin.addModule("config", b.createModule(.{
            .source_file = .{ .path = "config.zig" },
        }));
        b.installArtifact(bin);
    }

    inline for (.{ .{ "input", "input.zig" }, .{ "scroll", "scroll.zig" } }) |tuple| {
        const bin = b.addExecutable(.{
            .name = tuple[0],
            .root_source_file = .{ .path = tuple[1] },
            .optimize = optimize,
            .single_threaded = true,
        });
        b.installArtifact(bin);
    }
}
