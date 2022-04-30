const std = @import("std");
const print = std.debug.print;
const os = std.os;
const linux = std.os.linux;
const time = std.time;

fn handleSIGWINCH(_: c_int) callconv(.C) void {
    print("SIGWINCH\n", .{});
}

pub fn main() void {

    var act_winch: linux.Sigaction = undefined;
    os.sigaction(linux.SIG.WINCH, null, &act_winch);
    act_winch.handler.handler = handleSIGWINCH;
    os.sigaction(linux.SIG.WINCH, &act_winch, null);

    while (true) {
        time.sleep(time.ns_per_s);
    }
}
