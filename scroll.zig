//
// scroll
//
//

const std = @import("std");
const log = std.log;
const print = std.debug.print;

const umbra = @import("./src/umbra.zig");
const TTY = umbra.TTY;

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer gpa.deinit();
    // const allocator = gpa.allocator();

    var tty = try TTY.init();
    defer tty.deinit();

    const winsize = try tty.getWinSize();

    var buffer = tty.buffered_writer();
    defer buffer.flush() catch unreachable;

    const wb = buffer.writer();

    // feed
    {
        defer buffer.flush() catch unreachable;

        const curcmd = umbra.escseq.Cursor(TTY.BufferedWriter.Writer).init(wb);
        try curcmd.home();
        defer curcmd.home() catch unreachable;

        var i: usize = 0;
        while (i <= winsize.row_high) : (i += 1) {
            try curcmd.goto(0, @intCast(u16, i));
            try wb.print(" {}", .{i});
        }
    }

    // interact
    {
        defer buffer.flush() catch unreachable;

        const sgrcmd = umbra.escseq.SGR(TTY.BufferedWriter.Writer).init(wb);
        const eracmd = umbra.escseq.Erase(TTY.BufferedWriter.Writer).init(wb);
        const curcmd = umbra.escseq.Cursor(TTY.BufferedWriter.Writer).init(wb);
        const capcmd = umbra.escseq.Cap(TTY.BufferedWriter.Writer).init(wb, .Alacritty);

        var row: u16 = 0;
        var input_buffer: [16]u8 = undefined;

        try capcmd.changeScrollableRegion(0, winsize.row_high - 1);

        while (true) {
            defer buffer.flush() catch unreachable;

            const n = try tty.getInput(&input_buffer);

            const input = input_buffer[0..n];
            if (input.len != 1) continue;

            switch (input[0]) {
                'q' => break,
                'j' => {
                    if (row >= winsize.row_high) {
                        try capcmd.changeScrollableRegion(10, 20);
                        try curcmd.scrollUp(1);
                        try wb.writeAll("new line in bottom");
                        try curcmd.goto(0, row);
                        try capcmd.changeScrollableRegion(0, winsize.row_total);
                    } else {
                        const goto_row = row + 1;
                        defer row = goto_row;

                        try eracmd.line();
                        try curcmd.goto(0, row);
                        try wb.print(" {}", .{row});
                        try curcmd.goto(0, goto_row);
                        try eracmd.line();
                        try wb.writeAll(" ");
                        try sgrcmd.rendition(&.{ .bold, .fgWhite, .bgRed });
                        try wb.print("{}", .{goto_row});
                        try sgrcmd.rendition(&.{.reset});
                        try wb.writeAll(" xx");
                        try curcmd.goto(0, goto_row);
                    }
                },
                'k' => {
                    if (row <= 0) {
                        try curcmd.scrollDown(1);
                        try wb.writeAll("new line in top");
                        try curcmd.goto(0, row);
                    } else {
                        const goto_row = row - 1;
                        defer row = goto_row;

                        try eracmd.line();
                        try curcmd.goto(0, row);
                        try wb.print(" {}", .{row});
                        try curcmd.goto(0, goto_row);
                        try eracmd.line();
                        try wb.writeAll(" ");
                        try sgrcmd.rendition(&.{ .bold, .fgWhite, .bgRed });
                        try wb.print("{}", .{goto_row});
                        try sgrcmd.rendition(&.{.reset});
                        try wb.writeAll(" xx");
                        try curcmd.goto(0, goto_row);
                    }
                },

                's' => {
                    // _ = capcmd;
                    try wb.writeAll("~status");
                    try curcmd.save();
                    try capcmd.toStatusLine();
                    try wb.writeAll("hello 1/100");
                    try capcmd.fromStatusLine();
                    try curcmd.restore();
                },

                'o' => {
                    // vim O
                    try capcmd.insertLine();
                    try curcmd.goto(0, row);
                },
                'd' => {
                    // vim dd
                    try capcmd.deleteLine();
                    try curcmd.goto(0, row);
                },

                'J' => {
                    if (row < 10 or row > 20) continue;

                    try curcmd.save();
                    try capcmd.changeScrollableRegion(10, 20);
                    try curcmd.scrollUp(1);
                    try curcmd.goto(0, 20);
                    try wb.writeAll("new line in bottom");
                    try capcmd.changeScrollableRegion(0, winsize.row_total);
                    try curcmd.restore();
                },
                'K' => {
                    if (row < 10 or row > 20) continue;

                    try curcmd.save();
                    try capcmd.changeScrollableRegion(10, 20);
                    try curcmd.scrollDown(1);
                    try curcmd.goto(0, 10);
                    try wb.writeAll("new line in top");
                    try capcmd.changeScrollableRegion(0, winsize.row_total);
                    try curcmd.restore();
                },

                else => {},
            }
        }
    }
}
