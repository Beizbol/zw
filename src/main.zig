const std = @import("std");
const httpz = @import("httpz");

// Safe Ports: 49152 – 65535
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
        const ct = try parseFileType(ext);
        res.header("Content-Type", ct);
        // .weba audio/webm
        // .webm video/webm

        // res.header("Content-Type", "text/html; charset=utf-8");
    } else unreachable;

    res.body = try dir.readFileAlloc(req.arena, list.items, 1024 * 1024);
}

const FileExts = .{
    "htm",
    "html",
    "css",
    "mjs",
    "cjs",
    "js",
    "ico",
    "avif",
    "gif",
    "jpg",
    "png",
    "svg",
    "webp",
    "json",
    "xml",
    "xls",
    "xlsx",
    "ppt",
    "pptx",
    "doc",
    "docx",
    "csv",
    "pdf",
    "txt",
    "7z",
    "gz",
    "zip",
    "aac",
    "mp3",
    "wav",
    "weba",
    "webm",
};

const Alloc = std.mem.Allocator;
const List = std.ArrayList(u64);
const now = std.time.Instant.now;
fn bench(alloc: Alloc, lvls: usize) !void {
    if (lvls > 10) return error.LvlsTooLarge;
    // const buf_run = try alloc.alloc(u64, 8 ** lvls);
    const stats = try alloc.alloc(Stats, lvls);
    for (0..lvls) |i| {
        stats[i] = try run(i, .{""});
    }
}

const Stats = struct {
    total: u64,
    min: u64,
    max: u64,
    avg: u64,
    med: u64,
};

fn run(lvl: usize, exts: [][]const u8) !Stats {
    const count = 8 ** lvl;
    var s = Stats{
        .total = 0,
        .min = 0,
        .max = 0,
        .avg = 0,
        .med = 0,
    };

    for (0..count) |i| {
        const start = try now();
        const str = try parseFileType(exts[i]);
        const end = try now();
        _ = str;
        const dt = end.since(start);
        s.total += dt;
    }
    return s;
}

const contentType = enum {};
/// impl: chained if-else std.mem.eql
/// defaults to application/octet-stream
/// currently expects inputs of len 3-5
fn parseFileType(ext: []const u8) ![]const u8 {
    // std.debug.print("ext: {s}\n", .{ext});
    if (ext.len < 3 or ext.len > 5) {
        return error.InputLength;
    } else if (std.mem.eql(u8, ext, ".html")) {
        return "text/html";
    } else if (std.mem.eql(u8, ext, ".css")) {
        return "text/css";
    } else if (std.mem.eql(u8, ext, ".mjs")) {
        return "text/javascript";
    } else if (std.mem.eql(u8, ext, ".cjs")) {
        return "text/javascript";
    } else if (std.mem.eql(u8, ext, ".js")) {
        return "text/javascript";
    } else if (std.mem.eql(u8, ext, ".ico")) {
        return "image/x-icon";
    } else if (std.mem.eql(u8, ext, ".avif")) {
        return "image/avif";
    } else if (std.mem.eql(u8, ext, ".gif")) {
        return "image/gif";
    } else if (std.mem.eql(u8, ext, ".jpg")) {
        return "image/jpeg";
    } else if (std.mem.eql(u8, ext, ".png")) {
        return "image/png";
    } else if (std.mem.eql(u8, ext, ".svg")) {
        return "image/svg+xml";
    } else if (std.mem.eql(u8, ext, ".webp")) {
        return "image/webp";
    } else if (std.mem.eql(u8, ext, ".json")) {
        return "application/json";
    } else if (std.mem.eql(u8, ext, ".xml")) {
        return "application/xml";
    } else if (std.mem.eql(u8, ext, ".xls")) {
        return "application/vnd.ms-excel";
    } else if (std.mem.eql(u8, ext, ".xlsx")) {
        return "application/vnd.ms-excel";
    } else if (std.mem.eql(u8, ext, ".ppt")) {
        return "application/vnd.ms-powerpoint";
    } else if (std.mem.eql(u8, ext, ".pptx")) {
        return "application/vnd.ms-powerpoint";
    } else if (std.mem.eql(u8, ext, ".doc")) {
        return "application/msword";
    } else if (std.mem.eql(u8, ext, ".docx")) {
        return "application/msword";
    } else if (std.mem.eql(u8, ext, ".csv")) {
        return "text/csv";
    } else if (std.mem.eql(u8, ext, ".pdf")) {
        return "application/pdf";
    } else if (std.mem.eql(u8, ext, ".txt")) {
        return "text/plain";
    } else if (std.mem.eql(u8, ext, ".gz")) {
        return "application/gzip";
    } else if (std.mem.eql(u8, ext, ".zip")) {
        return "application/zip";
    } else if (std.mem.eql(u8, ext, ".aac")) {
        return "audio/aac";
    } else if (std.mem.eql(u8, ext, ".mp3")) {
        return "audio/mp3";
    } else if (std.mem.eql(u8, ext, ".wav")) {
        return "audio/wav";
    } else if (std.mem.eql(u8, ext, ".weba")) {
        return "audio/webm";
    } else if (std.mem.eql(u8, ext, ".webm")) {
        return "video/webm";
    } else { // Blob
        return "application/octet-stream";
    }
}
