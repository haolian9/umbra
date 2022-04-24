const std = @import("std");
const BufferedWriter = std.io.BufferedWriter;

pub fn Canvas(comptime buff_size: usize) type {
    return struct {
        buffer: BufferedWriter(buff_size)
    };
}
