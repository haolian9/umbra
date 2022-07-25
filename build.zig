const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();
    const output_dir = if (b.env_map.get("HOME")) |home| b.pathJoin(&.{ home, "bin" }) else null;

    const strip = switch (mode) {
        .Debug => false,
        else => true,
    };

    const targets = [_]struct {
        suffix: ?[]const u8,
        target: std.zig.CrossTarget,
    }{
        .{
            .suffix = "x86_64-linux-gnu",
            .target = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
        },
        .{
            .suffix = "x86_64-linux-musl",
            .target = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
        },
        .{
            // default
            .suffix = null,
            .target = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
        },
    };

    {
        inline for (targets) |ent| {
            const name = if (ent.suffix) |suffix| "umbra-" ++ suffix else "umbra";
            const exe = b.addExecutable(name, "main.zig");
            exe.setBuildMode(mode);
            exe.setTarget(ent.target);
            if (output_dir) |dir| {
                exe.setOutputDir(dir);
            }
            exe.strip = strip;
            exe.single_threaded = true;
            exe.install();
        }
    }
}
