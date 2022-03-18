const std = @import("std");
const io = std.io;
const fs = std.fs;
const time = std.time;

const EscSeq = @import("./EscapeSequence.zig");

const testing = std.testing;


fn fgapi(w: fs.File.Writer) !void {
    const fg = EscSeq.Foreground{.w = w};
    defer fg.default() catch unreachable;

    try fg.color(.black);
    try w.writeAll("black");

    try fg.color(.blue);
    try w.writeAll("blue");

    try fg.color(.cyan);
    try w.writeAll("cyan");

    try fg.color(.green);
    try w.writeAll("green");

    try fg.color(.magenta);
    try w.writeAll("magenta");

    try fg.color(.red);
    try w.writeAll("red");

    try fg.color(.white);
    try w.writeAll("white");

    try fg.color(.yellow);
    try w.writeAll("yellow");
}

fn bgapi(w: fs.File.Writer) !void {
    const bg = EscSeq.Background{.w = w};
    defer bg.default() catch unreachable;

    try bg.color(.black);
    try w.writeAll("black");

    try bg.color(.blue);
    try w.writeAll("blue");

    try bg.color(.cyan);
    try w.writeAll("cyan");

    try bg.color(.green);
    try w.writeAll("green");

    try bg.color(.magenta);
    try w.writeAll("magenta");

    try bg.color(.red);
    try w.writeAll("red");

    try bg.color(.white);
    try w.writeAll("white");

    try bg.color(.yellow);
    try w.writeAll("yellow");

}

fn cursorapi(w: anytype) !void {
    const cursor = EscSeq.Cursor{.w = w};

    try cursor.save();
    defer cursor.restore() catch unreachable;

    try cursor.home();
    try cursor.down(10);
    try cursor.forward(10);
    try cursor.up(5);
    try cursor.back(5);
}

fn styleapi(w: fs.File.Writer) !void {
    const style = EscSeq.Style{.w = w};

    defer style.reset() catch unreachable;

    try style.blink();
    try w.writeAll("blink");
    try style.resetBlink();

    try style.bold();
    try w.writeAll("bold");
    try style.resetBold();

    try style.dim();
    try w.writeAll("dim");
    try style.resetDim();

    try style.italic();
    try w.writeAll("italic");
    try style.resetItalic();

    try style.strikethrough();
    try w.writeAll("strike");
    try style.resetStrikethrough();

    try style.underline();
    try w.writeAll("underline");
    try style.resetUnderline();

}

test "bg" {
    try bgapi(io.getStdOut().writer());
}

test "fg" {
    try fgapi(io.getStdOut().writer());
}

test "cursor" {
    try cursorapi(io.getStdOut().writer());
}

test "style" {
    try styleapi(io.getStdOut().writer());
}

pub fn main() !void {

    const w = io.getStdOut().writer();

    try fgapi(w);

    try w.writeAll("\n");
    try bgapi(w);

    try w.writeAll("\n");
    try cursorapi(w);

    try w.writeAll("\n");
    try styleapi(w);
}
