const std = @import("std");
const print = std.debug.print;

const umbra = @import("./src/umbra.zig");

pub fn main() !void {

    const stdout = std.io.getStdOut();

    const w = stdout.writer();
    const sgr = umbra.escseq.SGR(std.fs.File.Writer).init(w);

    try sgr.rendition(&.{.bold, .italic, .underline, .strike});
    try w.writeAll("hello and welcome");
    try sgr.rendition(&.{.reset});
    try sgr.rendition(&.{.hide});
}
