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

const umbra = @import("./src/umbra.zig");
const Canvas = umbra.Canvas;
const TTY = umbra.TTY;
const VideoFiles = umbra.VideoFiles;
const escseq = umbra.escseq;
const events = umbra.events;
const cli_args = umbra.cli_args;

const config = @import("./config.zig");

const SigCtx = struct {
    canvas: *Canvas,
    tty: *TTY,
};

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

var SIGCTX: ?*SigCtx = null;

fn handleResize() !void {
    // todo: changes need to be applied to
    // * canvas.{screen_cursor,data_cursor}
    // * scrollable region

    if (SIGCTX) |ctx| {
        const winsize = try ctx.tty.getWinSize();

        var buffer = ctx.tty.buffered_writer();
        defer buffer.flush() catch unreachable;

        try ctx.canvas.resizeWindowHeight(winsize.row_total, buffer.writer());
    }
}

fn handleSIGWINCH(_: c_int) callconv(.C) void {
    logger.debug("WINCH", .{});
    handleResize() catch unreachable;
}

fn handleSIGCHLD(_: c_int) callconv(.C) void {
    const r = os.waitpid(-1, linux.W.NOHANG);
    logger.debug("SIGCHILD: waitpid: {any}", .{r});
}

/// mpv ignores SIGHUP, after the main exits, pid 1 will be it's parent.
/// and that's ok.
fn play(allocator: mem.Allocator, file: []const u8) !os.pid_t {
    const argv: []const []const u8 = &.{ "/usr/bin/mpv", file };

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
        logger.err("failed to exec: {s}", .{err});
        unreachable;
    }

    logger.debug("playing {s}", .{file});

    return pid;
}

fn handleCharKeyboardEvent(allocator: mem.Allocator, writer: anytype, canvas: *Canvas, ev: events.CharKeyboardEvent) !void {
    switch (ev.char) {
        'q' => return error.Quit,
        'j' => try canvas.scrollDown(writer),
        'k' => try canvas.scrollUp(writer),

        'H' => try canvas.gotoFirstLineOnScreen(writer),
        'L' => try canvas.gotoLastLineOnScreen(writer),
        'g' => try canvas.gotoFirstLine(writer),
        'G' => try canvas.gotoLastLine(writer),

        '\r', 'l' => {
            // play the video
            _ = try play(allocator, canvas.data[canvas.data_cursor]);
        },

        'r' => try handleResize(),

        'd', 'h' => {
            const old = canvas.data[canvas.data_cursor];
            const new = try fs.path.join(allocator, &.{ config.trash_dir, fs.path.basename(old) });
            defer allocator.free(new);

            logger.debug("mv {s} {s}", .{ old, new });
            fs.renameAbsolute(old, new) catch |err| {
                logger.err("failed to mv {s} {s}; err: {any}", .{ old, new, err });
            };

            // todo@hl
            // * remove the file from the canvas.data
            // * redraw the canvas
        },

        else => {},
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
                    _ = try play(allocator, canvas.data[canvas.data_cursor]);
                } else if (ev.row < canvas.screen_high) {
                    try canvas.gotoLine(writer, ev.row);
                } else {
                    // out of screen, leave it
                }
            },
        },
        else => {
            // try canvas.resetStatusLine(writer, "{any}", .{ev});
        },
    }
}

fn handleRuneKeyboardEvent(writer: anytype, canvas: Canvas, ev: events.RuneKeyboardEvent) !void {
    _ = writer;
    _ = canvas;
    _ = ev;
    // try canvas.resetStatusLine(writer, "{any}", .{ev});
}

fn createLogwriter() !fs.File.Writer {
    var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
    const path = try fmt.bufPrint(buffer[0..], "/tmp/{d}-umbra.log", .{linux.getuid()});
    var file = try fs.createFileAbsolute(path, .{});
    return file.writer();
}

pub fn main() !void {
    LOGWRITER = io.getStdErr().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == false);

    const allocator = gpa.allocator();

    var maybe_roots = try cli_args.gatherArgRoots(allocator);
    defer if (maybe_roots) |roots| roots.deinit();

    const roots = if (maybe_roots) |roots| roots.items else &config.roots;
    var files = try VideoFiles.fromRoots(allocator, roots, null);
    defer files.deinit();

    if (files.items.len < 1) {
        logger.info("no videos found", .{});
        return;
    }

    LOGWRITER = try createLogwriter();
    defer {
        LOGWRITER.context.close();
        LOGWRITER = io.getStdErr().writer();
    }

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

    {
        var act_chld: linux.Sigaction = undefined;
        os.sigaction(linux.SIG.CHLD, null, &act_chld);
        act_chld.handler.handler = handleSIGCHLD;
        os.sigaction(linux.SIG.CHLD, &act_chld, null);

        SIGCTX = &.{ .canvas = &canvas, .tty = &tty };
        var act_winch: linux.Sigaction = undefined;
        os.sigaction(linux.SIG.WINCH, null, &act_winch);
        act_winch.handler.handler = handleSIGWINCH;
        os.sigaction(linux.SIG.WINCH, &act_winch, null);
    }

    // construct frames
    try escseq.Cap.changeScrollableRegion(w, 0, canvas.screen_high);
    try escseq.Private.enableMouseInput(w);
    defer escseq.Private.disableMouseInput(w) catch unreachable;

    // first draw
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

            // try canvas.resetStatusLine(wb, "data: {}/{}; screen: {}/{}", .{ canvas.data_cursor, canvas.data.len - 1, canvas.screen_cursor, canvas.screen_high });
        }
    }
}
