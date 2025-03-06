const std = @import("std");
const httpz = @import("httpz");

const PORT: u16 = 8998;
const PATH = "www";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len > 1) {
        std.debug.print("zw: too many args | try: zw\n", .{});
        return;
    }
    try start_server(allocator);
}

const Ctx = struct { last: i128 };

fn start_server(gpa: std.mem.Allocator) !void {
    var ctx = Ctx{
        .last = std.time.nanoTimestamp(),
    };

    var server = try httpz.Server(*Ctx).init(
        gpa,
        .{ .port = PORT },
        &ctx,
    );
    defer { // clean shutdown
        server.stop(); // finishes serving any live request
        server.deinit();
    }

    var router = try server.router(.{});

    router.get("/zw", reload, .{});
    router.get("/*", serve, .{});

    std.debug.print("zw server started at http://localhost:{d}/\n", .{PORT});

    // blocks
    try server.listen();
}

fn reload(ctx: *Ctx, _: *httpz.Request, res: *httpz.Response) !void {
    var root = std.fs.cwd().openDir(PATH, .{ .iterate = true }) catch |err| {
        std.debug.print("dir err: {any}\n", .{err});
        return;
    };
    defer root.close();
    var walker = root.walk(res.arena) catch |err| {
        std.debug.print("walk err: {any}\n", .{err});
        return;
    };
    defer walker.deinit();
    var code: u16 = 204; // No Content
    while (walker.next() catch return) |entry| {
        // skip non files
        if (entry.kind != .file) continue;
        // get file info
        const info = root.statFile(entry.path) catch |err| {
            std.debug.print("statFile err: {any}\n", .{err});
            return;
        };
        // check if modified
        if (info.mtime > ctx.last) {
            ctx.last = info.mtime;
            code = 200; // OK Refresh
        }
    }
    res.status = code;
}

fn serve(_: *Ctx, req: *httpz.Request, res: *httpz.Response) !void {
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

        // application/json
        // image/png
        // image/svg+xml
        // image/jpeg
        // image/webp

        // .weba audio/webm
        // .webm video/webm

        // res.header("Content-Type", "text/html; charset=utf-8");
    } else unreachable;

    res.body = try dir.readFileAlloc(req.arena, list.items, 1024 * 1024);
}
