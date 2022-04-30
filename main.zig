const std = @import("std");
const assert = std.debug.assert;
const fmt = std.fmt;
const process = std.process;
const os = std.os;
const mem = std.mem;
const io = std.io;
const linux = std.os.linux;
const logger = std.log;
const fs = std.fs;

const umbra = @import("./src/umbra.zig");
const TTY = umbra.TTY;
const escseq = umbra.escseq;
const events = umbra.events;
const VideoFiles = umbra.VideoFiles;

const config = @import("./config.zig");

const Canvas = umbra.Canvas([]const u8, " {s}");

const SigCtx = struct {
    canvas: *Canvas,
    tty: *TTY,
};

var LOGFILE: ?fs.File = null;

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;
    const prefix = "[" ++ level.asText() ++ "] ";

    if (LOGFILE) |file| {
        const writer = file.writer();
        nosuspend writer.print(prefix ++ format ++ "\n", args) catch unreachable;
    }
}

var SIGCTX: ?*SigCtx = null;

fn handleResize() !void {
    // todo: changes need to be applied to
    // * canvas.{screen_cursor,data_cursor}
    // * scrollable region

    if (SIGCTX) |ctx| {
        const winsize = try ctx.tty.getWinSize();

        if (winsize.row_high < ctx.canvas.screen_high) {
            // shorter
            var buffer = ctx.tty.buffered_writer();
            defer buffer.flush() catch unreachable;

            const short = ctx.canvas.screen_high - winsize.row_high;
            var wb = buffer.writer();
            ctx.canvas.screen_cursor = winsize.row_high;
            ctx.canvas.data_cursor -= short;
            try ctx.canvas.redraw(wb, false);
            try escseq.Cursor.goto(wb, 0, ctx.canvas.screen_cursor);
        } else if (winsize.row_high > ctx.canvas.screen_high) {
            // longer
            var buffer = ctx.tty.buffered_writer();
            defer buffer.flush() catch unreachable;

            var wb = buffer.writer();
            try ctx.canvas.redraw(wb, true);
        } else {
            // no change to the height
        }
    }
}

fn handleSIGWINCH(_: c_int) callconv(.C) void {
    logger.debug("WINCH", .{});
    handleResize() catch unreachable;
}

/// mpv ignores SIGHUP, after the main exits, pid 1 will be it's parent.
/// and that's ok.
fn play(allocator: mem.Allocator, file: []const u8) !void {
    const pid = try os.fork();
    if (pid == 0) {
        io.getStdIn().close();
        io.getStdOut().close();
        io.getStdErr().close();
        const err = process.execv(allocator, &.{ "/usr/bin/mpv", "--mute=yes", file });
        logger.err("spawn mpv failed: {any}", .{err});
        unreachable;
    }
}

fn handleCharKeyboardEvent(allocator: mem.Allocator, writer: anytype, canvas: *Canvas, ev: events.CharKeyboardEvent) !void {
    switch (ev.char) {
        'q' => return error.Quit,
        'j' => try canvas.scrollDown(writer),
        'k' => try canvas.scrollUp(writer),

        'L' => {
            // go to the last line of the screen
            const gap = canvas.screen_high - canvas.screen_cursor;
            if (gap > 0) {
                canvas.screen_cursor = canvas.screen_high;
                canvas.data_cursor += gap;
                try escseq.Cursor.goto(writer, 0, canvas.screen_cursor);
            } else {
                // stay
            }
        },
        'H' => {
            // go to the first line of the screen
            const gap = canvas.screen_cursor - canvas.screen_low;
            if (gap > 0) {
                canvas.screen_cursor = canvas.screen_low;
                canvas.data_cursor -= gap;
                try escseq.Cursor.goto(writer, 0, canvas.screen_cursor);
            } else {
                // stay
            }
        },
        'g' => {
            // go to the first line of the data
            canvas.screen_cursor = canvas.screen_low;
            canvas.data_cursor = 0;
            try canvas.redraw(writer, false);
            try escseq.Cursor.goto(writer, 0, canvas.screen_cursor);
        },
        'G' => {
            // go to the last line of the data
            canvas.screen_cursor = canvas.screen_high;
            canvas.data_cursor = canvas.data.len - 1;
            try canvas.redraw(writer, false);
            try escseq.Cursor.goto(writer, 0, canvas.screen_cursor);
        },

        '\r' => {
            // play the video
            try play(allocator, canvas.data[canvas.data_cursor]);
        },

        'r' => {
            try handleResize();
        },

        else => {
            try escseq.Cursor.save(writer);
            try escseq.Cursor.goto(writer, 0, canvas.status_low);
            try escseq.Erase.line(writer);
            try fmt.format(writer, "{}", .{ev});
            try escseq.Cursor.restore(writer);
        },
    }
}

fn handleMouseEvent(allocator: mem.Allocator, writer: anytype, canvas: *Canvas, ev: events.MouseEvent) !void {
    switch (ev.btn) {
        .Up => try canvas.scrollUp(writer),
        .Down => try canvas.scrollDown(writer),
        .Left => switch (ev.press_state) {
            .Down => {},
            .Up => {
                if (canvas.screen_cursor == ev.row) {
                    try play(allocator, canvas.data[canvas.data_cursor]);
                } else {
                    canvas.screen_cursor = ev.row;
                    try escseq.Cursor.goto(writer, 0, canvas.screen_cursor);
                }
            },
        },
        else => {
            try canvas.resetStatusLine(writer, "{any}", .{ev});
        },
    }
}

fn handleRuneKeyboardEvent(writer: anytype, canvas: Canvas, ev: events.RuneKeyboardEvent) !void {
    try canvas.resetStatusLine(writer, "{any}", .{ev});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == false);

    const allocator = gpa.allocator();

    {
        var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
        var stream = io.FixedBufferStream([]u8){ .buffer = &buffer, .pos = 0 };
        const writer = stream.writer();
        try fmt.format(writer, "/tmp/{d}-umbra.log", .{linux.getuid()});
        const path = buffer[0..stream.pos];
        var file = try fs.createFileAbsolute(path, .{.truncate = false});
        LOGFILE = file;
    }
    defer LOGFILE.?.close();

    var tty = try TTY.init();
    defer tty.deinit();

    var buffer = tty.buffered_writer();
    defer buffer.flush() catch unreachable;

    const w = tty.writer();
    const wb = buffer.writer();

    var files = try VideoFiles.fromRoots(allocator, &config.roots, null);
    defer files.deinit();

    var canvas: Canvas = blk: {
        const winsize = try tty.getWinSize();
        const status_rows = 1;
        const screen_high = winsize.row_high - status_rows;
        const status_low = screen_high + 1;

        break :blk Canvas{
            .data = files.items,
            .screen_low = 0,
            .screen_high = screen_high,
            .status_low = status_low,

            .data_cursor = 0,
            .screen_cursor = 0,
        };
    };

    // construct frames
    try escseq.Cap.changeScrollableRegion(w, 0, canvas.screen_high);
    try escseq.Private.enableMouseInput(w);
    defer escseq.Private.disableMouseInput(w) catch unreachable;

    SIGCTX = &.{ .canvas = &canvas, .tty = &tty };
    logger.debug("register SIGCTX?{s}", .{SIGCTX != null});
    var act_winch: linux.Sigaction = undefined;
    os.sigaction(linux.SIG.WINCH, null, &act_winch);
    act_winch.handler.handler = handleSIGWINCH;
    act_winch.handler.sigaction = null;
    os.sigaction(linux.SIG.WINCH, &act_winch, null);

    // first draw
    try canvas.redraw(wb, true);
    try buffer.flush();

    // interact
    {
        defer buffer.flush() catch unreachable;

        try escseq.Cursor.home(w);

        var input_buffer: [16]u8 = undefined;

        while (true) {
            defer buffer.flush() catch unreachable;

            const event: events.Event = blk: {
                const n = try tty.getInput(&input_buffer);
                const input = input_buffer[0..n];
                break :blk events.Event.fromString(input) catch |err| switch (err) {
                    // 连续滚动鼠标滚轮，有很大概率会出现这个错误
                    // 我们目前先忽略掉这个错误
                    error.InvalidCharacter => continue,
                    else => return err,
                };
            };

            switch (event) {
                .Mouse => |mouse| {
                    try handleMouseEvent(allocator, wb, &canvas, mouse);
                },
                .Char => |char| {
                    handleCharKeyboardEvent(allocator, wb, &canvas, char) catch |err| switch (err) {
                        error.Quit => break,
                        else => return err,
                    };
                },
                .Rune => |rune| {
                    try handleRuneKeyboardEvent(wb, canvas, rune);
                },
            }
        }
    }
}
