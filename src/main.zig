const std = @import("std");
const httpz = @import("httpz");

const port: u16 = 8998;
const path = "www";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // std.debug.print("args len: {d}\n", .{args.len});

    if (args.len > 2) {
        std.debug.print("zw: too many args | try: zw\n", .{});
        return;
    }

    // start server
    if (args.len == 1) {
        try start_server(allocator);
        return;
    }

    // install exe
    if (std.mem.eql(u8, args[1], "i")) {
        try install_exe();
        return;
    }

    std.debug.print("unknown arg: {s} | try: zw i\n", .{args[1]});
}

fn install_exe() !void {
    std.debug.print("installing zw", .{});
    // Open build directory
    var build_dir = try std.fs.cwd().openDir("zig-out/bin", .{});
    defer build_dir.close();
    // Open install directory
    var install_dir = try std.fs.cwd().openDir("C:/Users/jakey/.zig", .{});
    defer install_dir.close();
    // Copy compiled exe to install
    try build_dir.copyFile("zw.exe", install_dir, "zw.exe", .{});
}

fn start_server(alloc: std.mem.Allocator) !void {
    var server = try httpz.Server(void).init(
        alloc,
        .{ .port = port },
        {},
    );
    defer { // clean shutdown
        server.stop(); // finishes serving any live request
        server.deinit();
    }

    var router = server.router(.{});
    router.get("/*", serve, .{});

    std.debug.print("zw server started at http://localhost:{d}/\n", .{port});

    // blocks
    try server.listen();
}

fn serve(req: *httpz.Request, res: *httpz.Response) !void {
    std.debug.print("path: {s}\n", .{req.url.path});
    var dir = try std.fs.cwd().openDir(path, .{});
    defer dir.close();
    res.status = 200;

    var list = std.ArrayList(u8).init(req.arena);
    defer list.deinit();

    const last = req.url.path.len - 1;

    if (req.url.path[last] == '/') {
        try list.appendSlice("index.html");
        res.header("Content-Type", "text/html; charset=utf-8");
    } else if (std.mem.lastIndexOfScalar(u8, req.url.path, '.')) |dot| {
        try list.appendSlice(req.url.path[1..]);
        const ext = req.url.path[dot..];
        std.debug.print("ext: {s}\n", .{ext});
        // if (std.mem.eql(u8, ext, "html")) {}
        // res.header("Content-Type", "text/html; charset=utf-8");
    } else unreachable;

    res.body = try dir.readFileAlloc(req.arena, list.items, 1024 * 1024);
}

// "zig build -- i" copies the exe to ~/.zig/
