const std = @import("std");
const assert = std.debug.assert;
const fmt = std.fmt;
const os = std.os;
const mem = std.mem;
const io = std.io;
const linux = std.os.linux;
const logger = std.log;
const fs = std.fs;
const builtin = @import("builtin");
const rand = std.rand;

const umbra = @import("src/umbra.zig");
const Canvas = umbra.Canvas;
const TTY = umbra.TTY;
const VideoFiles = umbra.VideoFiles;
const Mnts = umbra.Mnts;
const escseq = umbra.escseq;
const events = umbra.events;
const cli_args = umbra.cli_args;

const config = @import("config.zig");

const SigCtx = struct {
    canvas: *Canvas,
    tty: *TTY,
    buffered_writer: *TTY.BufferedWriter,
};

var SIGCTX: SigCtx = undefined;
var PRNG: rand.DefaultPrng = undefined;
var LOGWRITER: fs.File.Writer = undefined;

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;
    const prefix = "[" ++ level.asText() ++ "] ";

    nosuspend LOGWRITER.print(prefix ++ format ++ "\n", args) catch unreachable;
}

fn handleResize() !void {
    // ensure no interleaving writes
    assert(SIGCTX.buffered_writer.buf.end == 0);
    const winsize = try SIGCTX.tty.getWinSize();
    try SIGCTX.canvas.resizeScreen(winsize.row_total, SIGCTX.buffered_writer.writer());
    try SIGCTX.buffered_writer.flush();
}

fn handleSIGWINCH(_: c_int) callconv(.C) void {
    handleResize() catch unreachable;
}

fn handleSIGCHLD(_: c_int) callconv(.C) void {
    const r = os.waitpid(-1, linux.W.NOHANG);
    logger.debug("SIGCHILD: waitpid: {any}", .{r});
}

/// mpv ignores SIGHUP, after the main exits, pid 1 will be it's parent.
/// and that's ok.
fn play(allocator: mem.Allocator, file: []const u8) !os.pid_t {
    const argv: []const []const u8 = &.{ "/usr/bin/mpv", "--no-terminal", file };

    // stole from std.ChildProcess.spawnPosix
    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const argv_buf = try arena.allocSentinel(?[*:0]u8, argv.len, null);
    for (argv) |arg, i| argv_buf[i] = (try arena.dupeZ(u8, arg)).ptr;

    const envp = if (builtin.output_mode == .Exe)
        @ptrCast([*:null]?[*:0]u8, os.environ.ptr)
    else
        unreachable;

    const pid = try os.fork();

    if (pid == 0) {
        os.close(0);
        os.close(1);
        os.close(2);
        const err = os.execvpeZ_expandArg0(.no_expand, argv_buf.ptr[0].?, argv_buf.ptr, envp);
        logger.err("failed to exec: {}", .{err});
        unreachable;
    }

    logger.debug("playing {s}", .{file});

    return pid;
}

fn handleKeySymbol(allocator: mem.Allocator, writer: anytype, canvas: *Canvas, ev: events.KeySymbol, mnts: Mnts) !void {
    _ = mnts;
    switch (ev.symbol) {
        'q' => return error.Quit,
        'j' => try canvas.scrollDown(writer),
        'k' => try canvas.scrollUp(writer),

        'H' => try canvas.gotoFirstLineOnScreen(writer),
        'L' => try canvas.gotoLastLineOnScreen(writer),
        'g' => try canvas.gotoFirstLine(writer),
        'G' => try canvas.gotoLastLine(writer),
        'm' => {
            const screen_mid = canvas.screen_high / 2;
            try canvas.gotoLineOnScreen(writer, screen_mid);
        },

        '\r', 'l' => {
            // play the video
            _ = try play(allocator, canvas.data[canvas.data_cursor]);
        },

        // ctrl-u
        21 => {
            const row = canvas.screen_cursor;
            {
                var i: u16 = 0;
                while (i <= canvas.screen_high) : (i += 1) {
                    try canvas.scrollUp(writer);
                }
            }
            try canvas.gotoLineOnScreen(writer, row);
            try canvas.redraw(writer, true);
            try canvas.highlightCurrentLine(writer);
        },
        // ctrl-d
        4 => {
            const row = canvas.screen_cursor;
            {
                var i: u16 = 0;
                while (i <= canvas.screen_high) : (i += 1) {
                    try canvas.scrollDown(writer);
                }
            }
            try canvas.gotoLineOnScreen(writer, row);
            try canvas.redraw(writer, true);
            try canvas.highlightCurrentLine(writer);
        },

        // \x08 for backspace
        'd', '\x08' => {
            const src = canvas.data[canvas.data_cursor];
            try trashFile(allocator, mnts, writer, canvas, src);

            // todo: remove the file from the canvas.data
            // todo: redraw the canvas
        },

        's' => {
            const random = PRNG.random();
            random.shuffle([]const u8, canvas.data);
            try canvas.redraw(writer, true);
            try canvas.highlightCurrentLine(writer);
            try canvas.resetStatusLine(writer, "shuffled data", .{});
        },

        else => |symbol| {
            try canvas.resetStatusLine(writer, "ascii: {c} {d}", .{ symbol, symbol });
        },
    }
}

fn handleMouse(allocator: mem.Allocator, writer: anytype, canvas: *Canvas, ev: events.Mouse) !void {
    switch (ev.btn) {
        .up => try canvas.scrollUp(writer),
        .down => try canvas.scrollDown(writer),
        .left => switch (ev.press_state) {
            .down => {
                try canvas.resetStatusLine(writer, "{any}", .{ev});
            },
            .up => {
                const need_to_play = blk: {
                    if (canvas.screen_cursor == ev.row) {
                        break :blk true;
                    } else if (ev.row <= canvas.screen_high) {
                        const before = canvas.screen_cursor;
                        try canvas.gotoLineOnScreen(writer, ev.row);
                        // false when data is not enough to fill one single page
                        break :blk if (ev.row > canvas.data_high) false else before == canvas.screen_cursor;
                    } else {
                        // out of screen
                        break :blk false;
                    }
                };
                if (need_to_play) _ = try play(allocator, canvas.data[canvas.data_cursor]);
            },
        },
        .mid, .right => switch (ev.press_state) {
            .down => {},
            .up => _ = try play(allocator, canvas.data[canvas.data_cursor]),
        },
        else => {
            try canvas.resetStatusLine(writer, "{any}", .{ev});
        },
    }
}

fn handleKeyCodes(allocator: mem.Allocator, writer: anytype, canvas: *Canvas, ev: events.KeyCodes) !void {
    if (mem.startsWith(u8, ev.codes, "\x1b[")) {
        switch (ev.codes.len) {
            3 => switch (ev.codes[2]) {
                // arrow up
                'A' => try canvas.scrollUp(writer),
                // arrow down
                'B' => try canvas.scrollDown(writer),
                // arrow right
                'C' => _ = try play(allocator, canvas.data[canvas.data_cursor]),
                else => {
                    try canvas.resetStatusLine(writer, "codes: {any} '{c}'", .{ ev, ev.codes[2..ev.codes.len] });
                },
            },
            else => {
                try canvas.resetStatusLine(writer, "codes: {any} '{c}'", .{ ev, ev.codes[2..ev.codes.len] });
            },
        }
    } else if (mem.startsWith(u8, ev.codes, "\x1bO")) {
        switch (ev.codes[2]) {
            // F1
            'P' => {
                try canvas.resetStatusLine(writer, "data_high={any}; window.[rows={},high={}]; status.[rows={},high={}]; screen.[rows={},low={},high={}]; cursor.[data={},screen={}]", .{
                    canvas.data_high, canvas.window_rows, canvas.window_high, canvas.status_rows, canvas.status_low, canvas.screen_rows, canvas.screen_low, canvas.screen_high, canvas.data_cursor, canvas.screen_cursor,
                });
            },
            else => {
                try canvas.resetStatusLine(writer, "codes: {any} '{c}'", .{ ev, fmt.fmtSliceEscapeLower(ev.codes) });
            },
        }
    } else {
        try canvas.resetStatusLine(writer, "codes: {any} '{c}'", .{ ev, fmt.fmtSliceEscapeLower(ev.codes) });
    }
}

fn createLogwriter() !fs.File.Writer {
    var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
    const path = try fmt.bufPrint(buffer[0..], "/tmp/{d}-umbra.log", .{linux.getuid()});
    var file = try fs.createFileAbsolute(path, .{});
    return file.writer();
}

fn trashFile(allocator: mem.Allocator, mnts: Mnts, writer: anytype, canvas: *Canvas, src: []const u8) !void {
    const maybe = mnts.mntpoint(src) catch |err| switch (err) {
        error.FileNotFound, error.AccessDenied => {
            logger.err("{}: {s}", .{ err, src });
            try canvas.resetStatusLine(writer, "{s}: {s}", .{ @errorName(err), canvas.wrapItem(src) });
            return;
        },
        else => return err,
    };
    if (maybe) |root| {
        const dest = try fs.path.join(allocator, &.{ root, config.trash_dir, fs.path.basename(src) });
        defer allocator.free(dest);

        if (fs.renameAbsolute(src, dest)) {
            try canvas.resetStatusLine(writer, "trashed {s}", .{canvas.wrapItem(src)});
        } else |err| {
            logger.err("{}: mv {s} {s}", .{ err, src, dest });
            try canvas.resetStatusLine(writer, "{s}", .{@errorName(err)});
        }
    } else {
        logger.err("no mountpoint: {s}", .{src});
        try canvas.resetStatusLine(writer, "no mntpoint: {s}", .{canvas.wrapItem(src)});
    }
}

pub fn main() !void {
    LOGWRITER = io.getStdErr().writer();

    PRNG = rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try os.getrandom(mem.asBytes(&seed));
        break :blk seed;
    });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(!gpa.deinit());

    const allocator = gpa.allocator();

    var mnts = try Mnts.init(allocator);
    defer mnts.deinit();

    var maybe_roots = try cli_args.gatherArgRoots(allocator);
    defer if (maybe_roots) |roots| roots.deinit();

    const roots = if (maybe_roots) |roots| roots.items else &config.roots;
    var files = try VideoFiles.init(allocator, roots);
    defer files.deinit();

    if (files.items.len < 1) {
        logger.info("no videos found", .{});
        return;
    }

    LOGWRITER = try createLogwriter();
    defer LOGWRITER.context.close();

    try os.dup2(LOGWRITER.context.handle, io.getStdErr().handle);
    try os.dup2(LOGWRITER.context.handle, io.getStdOut().handle);

    var tty = try TTY.init();
    defer tty.deinit();

    var buffer = tty.buffered_writer();
    defer buffer.flush() catch unreachable;

    const w = tty.writer();
    const wb = buffer.writer();

    var canvas: Canvas = blk: {
        const winsize = try tty.getWinSize();
        break :blk Canvas.init(files.items, winsize.row_total, 1, winsize.col_total - 1);
    };

    SIGCTX = .{ .canvas = &canvas, .tty = &tty, .buffered_writer = &buffer };

    {
        var act_chld: linux.Sigaction = undefined;
        try os.sigaction(linux.SIG.CHLD, null, &act_chld);
        act_chld.handler.handler = handleSIGCHLD;
        try os.sigaction(linux.SIG.CHLD, &act_chld, null);

        var act_winch: linux.Sigaction = undefined;
        try os.sigaction(linux.SIG.WINCH, null, &act_winch);
        act_winch.handler.handler = handleSIGWINCH;
        try os.sigaction(linux.SIG.WINCH, &act_winch, null);
    }

    // construct frames
    try escseq.Private.enableMouseInput(w);
    defer escseq.Private.disableMouseInput(w) catch unreachable;

    // first draw
    try canvas.resetScrollableRegion(wb);
    try canvas.redraw(wb, true);
    try escseq.Cursor.home(wb);
    try canvas.highlightCurrentLine(wb);
    try buffer.flush();

    // interact
    {
        defer buffer.flush() catch unreachable;

        var input_buffer: [16]u8 = undefined;

        while (true) {
            defer buffer.flush() catch unreachable;

            const event: events.Event = blk: {
                const n = try tty.getInput(&input_buffer);
                const input = input_buffer[0..n];
                break :blk events.Event.fromString(input) catch |err| switch (err) {
                    // 连续滚动鼠标滚轮，有很大概率会出现这个错误, 目前先忽略掉
                    error.InvalidCharacter => continue,
                    else => return err,
                };
            };

            switch (event) {
                .mouse => |mouse| {
                    try handleMouse(allocator, wb, &canvas, mouse);
                },
                .symbol => |symbol| {
                    handleKeySymbol(allocator, wb, &canvas, symbol, mnts) catch |err| switch (err) {
                        error.Quit => break,
                        else => return err,
                    };
                },
                .codes => |codes| {
                    try handleKeyCodes(allocator, wb, &canvas, codes);
                },
            }

            // try canvas.resetStatusLine(wb, "data: {}/{}; screen: {}/{}", .{ canvas.data_cursor, canvas.data.len - 1, canvas.screen_cursor, canvas.screen_high });
        }
    }
}
