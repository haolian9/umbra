const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    {
        const bin = b.addExecutable(.{
            .name = "umbra",
            .root_source_file = .{ .path = "main.zig" },
            .target = target,
            .optimize = optimize,
            .single_threaded = true,
        });
        bin.root_module.addImport("config", b.createModule(.{
            .root_source_file = .{ .path = "config.zig" },
        }));
        b.installArtifact(bin);
    }

    inline for (.{ .{ "input", "input.zig" }, .{ "scroll", "scroll.zig" } }) |tuple| {
        const bin = b.addExecutable(.{
            .name = tuple[0],
            .root_source_file = .{ .path = tuple[1] },
            .target = target,
            .optimize = optimize,
            .single_threaded = true,
        });
        b.installArtifact(bin);
    }
}
