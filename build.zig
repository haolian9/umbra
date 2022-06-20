const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const output_dir = b.pathJoin(&.{ b.env_map.get("HOME").?, "bin" });

    {
        const exe = b.addExecutable("umbra", "main.zig");
        exe.setBuildMode(mode);
        exe.setOutputDir(output_dir);
        exe.strip = true;
        exe.single_threaded = true;
        exe.install();
    }

    {
        const exe = b.addExecutable("lsmnts", "src/Mnts.zig");
        exe.setBuildMode(mode);
        exe.setOutputDir(output_dir);
        exe.strip = false;
        exe.single_threaded = true;
        exe.install();
    }

}
