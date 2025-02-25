const std = @import("std");
const httpz = @import("httpz");

const PORT: u16 = 8998;
const PATH = "www";

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
        .{ .port = PORT },
        {},
    );
    defer { // clean shutdown
        server.stop(); // finishes serving any live request
        server.deinit();
    }

    var router = server.router(.{});

    router.get("/zw", reload, .{});
    router.get("/*", serve, .{});

    std.debug.print("zw server started at http://localhost:{d}/\n", .{PORT});

    // blocks
    try server.listen();
}

fn reload(_: *httpz.Request, res: *httpz.Response) !void {
    try res.startEventStream(StreamContext{
        .arena = res.arena,
    }, StreamContext.handle);
}

const StreamContext = struct {
    arena: std.mem.Allocator,

    fn handle(ctx: StreamContext, stream: std.net.Stream) void {
        // some event loop
        // std.debug.print("zw sse\n", .{});
        var root = std.fs.cwd().openDir(PATH, .{ .iterate = true }) catch |err| {
            std.debug.print("err: {any}\n", .{err});
            return;
        };
        defer root.close();

        var last: i128 = 0;
        var dirty = false;
        var first = true;
        var n: usize = 0;
        while (true) {
            dirty = false;
            // std.debug.print("checking\n", .{});
            var walker = root.walk(ctx.arena) catch |err| {
                std.debug.print("err: {any}\n", .{err});
                return;
            };
            defer walker.deinit();
            while (walker.next() catch return) |entry| {
                if (entry.kind != .file) continue;

                // std.debug.print("entry: {s}\n", .{entry.path});

                var file = root.openFile(entry.path, .{}) catch |err| {
                    std.debug.print("open err: {any}\n", .{err});
                    return;
                };
                defer file.close();
                const info = file.stat() catch |err| {
                    std.debug.print("stat err: {any}\n", .{err});
                    return;
                };
                if (info.mtime > last) {
                    last = info.mtime;
                    dirty = true;
                }
            }

            if (first) {
                first = false;
            } else if (dirty) {
                // std.debug.print("reload\n", .{});
                stream.writeAll("event: reload\ndata: {}\n\n") catch |err| {
                    std.debug.print("err: {any}\n", .{err});
                    return;
                };
            } else if (n > 15) {
                // std.debug.print("nop\n", .{});
                n = 0;
                stream.writeAll("event: nop\ndata: {}\n\n") catch |err| {
                    std.debug.print("err: {any}\n", .{err});
                    return;
                };
            } else {
                n += 1;
            }

            std.Thread.sleep(std.time.ns_per_ms * 250);
        }
    }
};

fn serve(req: *httpz.Request, res: *httpz.Response) !void {
    var dir = try std.fs.cwd().openDir(PATH, .{});
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
        if (std.mem.eql(u8, ext, ".html")) {
            std.debug.print("path: {s}\n", .{req.url.path});
            res.header("Content-Type", "text/html");
        } else if (std.mem.eql(u8, ext, ".css")) {
            std.debug.print("path: {s}\n", .{req.url.path});
            res.header("Content-Type", "text/css");
        } else if (std.mem.eql(u8, ext, ".js")) {
            std.debug.print("path: {s}\n", .{req.url.path});
            res.header("Content-Type", "text/javascript");
        }
        // res.header("Content-Type", "text/html; charset=utf-8");
    } else unreachable;

    res.body = try dir.readFileAlloc(req.arena, list.items, 1024 * 1024);
}

// "zig build -- i" copies the exe to ~/.zig/
