const std = @import("std");

pub const Ico = @This();
// Header
head: Head = .{},
img16: Info,
img24: Info,
img32: Info,
img48: Info,
img64: Info,
data: [5][]u8,

pub fn init(gpa: std.mem.Allocator, path: []const u8) !Ico {
    var dir = try std.fs.cwd().openDir(path, .{});
    defer dir.close();

    const max = 5 * (16 * 16 + 24 * 24 + 32 * 32 + 48 * 48 + 64 * 64);
    const d16 = try dir.readFileAlloc(gpa, "p16.png", max);
    const d24 = try dir.readFileAlloc(gpa, "p24.png", max);
    const d32 = try dir.readFileAlloc(gpa, "p32.png", max);
    const d48 = try dir.readFileAlloc(gpa, "p48.png", max);
    const d64 = try dir.readFileAlloc(gpa, "p64.png", max);

    const off = 5 * @sizeOf(Info) + @sizeOf(Head);

    return Ico{
        .img16 = Info{
            .w = 16,
            .h = 16,
            .size = @intCast(d16.len),
            .offset = off,
        },
        .img24 = Info{
            .w = 24,
            .h = 24,
            .size = @intCast(d24.len),
            .offset = @intCast(off + d16.len),
        },
        .img32 = Info{
            .w = 32,
            .h = 32,
            .size = @intCast(d32.len),
            .offset = @intCast(off + d16.len + d24.len),
        },
        .img48 = Info{
            .w = 48,
            .h = 48,
            .size = @intCast(d48.len),
            .offset = @intCast(off + d16.len + d24.len + d32.len),
        },
        .img64 = Info{
            .w = 64,
            .h = 64,
            .size = @intCast(d64.len),
            .offset = @intCast(off + d16.len + d24.len + d32.len + d48.len),
        },
        .data = .{ d16, d24, d32, d48, d64 },
    };
}

pub fn write(ico: Ico, path: []const u8) !void {
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    var w = file.writer();
    try ico.head.writeHead(w);
    try ico.img16.writeInfo(w);
    try ico.img24.writeInfo(w);
    try ico.img32.writeInfo(w);
    try ico.img48.writeInfo(w);
    try ico.img64.writeInfo(w);
    for (ico.data) |d| {
        _ = try w.write(d);
    }
}

const Head = struct {
    h0: u16 = 0, // reserved
    h2: u16 = 1, // ico id
    h4: u16 = 5, // img count

    pub fn writeHead(h: Head, w: std.fs.File.Writer) !void {
        try w.writeInt(u16, h.h0, .little);
        try w.writeInt(u16, h.h2, .little);
        try w.writeInt(u16, h.h4, .little);
    }
};

const Info = struct {
    w: u8,
    h: u8,
    n2: u8 = 0, // pallette
    n3: u8 = 0, // reserved
    n4: u16 = 0, // planes
    n6: u16 = 32, // bit depth
    size: u32, // size of data
    offset: u32, // offset to data

    pub fn writeInfo(i: Info, w: std.fs.File.Writer) !void {
        try w.writeInt(u8, i.w, .little);
        try w.writeInt(u8, i.h, .little);
        try w.writeInt(u8, i.n2, .little);
        try w.writeInt(u8, i.n3, .little);
        try w.writeInt(u16, i.n4, .little);
        try w.writeInt(u16, i.n6, .little);
        try w.writeInt(u32, i.size, .little);
        try w.writeInt(u32, i.offset, .little);
    }
};

const Data = struct {
    buf: []u8,
    idx: usize,
    size: u32,
};

const base64 = std.base64.standard.Decoder;

fn parseDataUrl(gpa: std.mem.Allocator, txt: []u8) ![]u8 {
    const input = txt[22..];
    const size = try base64.calcSizeForSlice(input);
    const buf = try gpa.alloc(u8, size);
    try base64.decode(buf, input);
    return buf;
}

const assert = std.testing.expect;
const print = std.debug.print;

test "happy hello" {
    var alloc = std.testing.allocator;
    const txt = try alloc.dupe(u8, "data:text/plain;base64,SGVsbG8sIFdvcmxkIQ==");
    defer alloc.free(txt);
    const ans = try alloc.dupe(u8, "Hello, World!");
    defer alloc.free(ans);
    const data = try parseDataUrl(alloc, txt);
    defer alloc.free(data);
    const a = std.mem.eql(u8, ans, data);
    assert(a) catch print("got: {s}\n", .{data});
}

test "happy img" {
    var alloc = std.testing.allocator;
    const txt = try alloc.dupe(u8, "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAASwAAACWCAYAAABkW7XSAAAAAXNSR0IArs4c6QAABGJJREFUeF7t1AEJAAAMAsHZv/RyPNwSyDncOQIECEQEFskpJgECBM5geQICBDICBitTlaAECBgsP0CAQEbAYGWqEpQAAYPlBwgQyAgYrExVghIgYLD8AAECGQGDlalKUAIEDJYfIEAgI2CwMlUJSoCAwfIDBAhkBAxWpipBCRAwWH6AAIGMgMHKVCUoAQIGyw8QIJARMFiZqgQlQMBg+QECBDICBitTlaAECBgsP0CAQEbAYGWqEpQAAYPlBwgQyAgYrExVghIgYLD8AAECGQGDlalKUAIEDJYfIEAgI2CwMlUJSoCAwfIDBAhkBAxWpipBCRAwWH6AAIGMgMHKVCUoAQIGyw8QIJARMFiZqgQlQMBg+QECBDICBitTlaAECBgsP0CAQEbAYGWqEpQAAYPlBwgQyAgYrExVghIgYLD8AAECGQGDlalKUAIEDJYfIEAgI2CwMlUJSoCAwfIDBAhkBAxWpipBCRAwWH6AAIGMgMHKVCUoAQIGyw8QIJARMFiZqgQlQMBg+QECBDICBitTlaAECBgsP0CAQEbAYGWqEpQAAYPlBwgQyAgYrExVghIgYLD8AAECGQGDlalKUAIEDJYfIEAgI2CwMlUJSoCAwfIDBAhkBAxWpipBCRAwWH6AAIGMgMHKVCUoAQIGyw8QIJARMFiZqgQlQMBg+QECBDICBitTlaAECBgsP0CAQEbAYGWqEpQAAYPlBwgQyAgYrExVghIgYLD8AAECGQGDlalKUAIEDJYfIEAgI2CwMlUJSoCAwfIDBAhkBAxWpipBCRAwWH6AAIGMgMHKVCUoAQIGyw8QIJARMFiZqgQlQMBg+QECBDICBitTlaAECBgsP0CAQEbAYGWqEpQAAYPlBwgQyAgYrExVghIgYLD8AAECGQGDlalKUAIEDJYfIEAgI2CwMlUJSoCAwfIDBAhkBAxWpipBCRAwWH6AAIGMgMHKVCUoAQIGyw8QIJARMFiZqgQlQMBg+QECBDICBitTlaAECBgsP0CAQEbAYGWqEpQAAYPlBwgQyAgYrExVghIgYLD8AAECGQGDlalKUAIEDJYfIEAgI2CwMlUJSoCAwfIDBAhkBAxWpipBCRAwWH6AAIGMgMHKVCUoAQIGyw8QIJARMFiZqgQlQMBg+QECBDICBitTlaAECBgsP0CAQEbAYGWqEpQAAYPlBwgQyAgYrExVghIgYLD8AAECGQGDlalKUAIEDJYfIEAgI2CwMlUJSoCAwfIDBAhkBAxWpipBCRAwWH6AAIGMgMHKVCUoAQIGyw8QIJARMFiZqgQlQMBg+QECBDICBitTlaAECBgsP0CAQEbAYGWqEpQAAYPlBwgQyAgYrExVghIgYLD8AAECGQGDlalKUAIEDJYfIEAgI2CwMlUJSoCAwfIDBAhkBAxWpipBCRAwWH6AAIGMgMHKVCUoAQIGyw8QIJARMFiZqgQlQMBg+QECBDICBitTlaAECBgsP0CAQEbAYGWqEpQAgQdWMQCX4yW9owAAAABJRU5ErkJggg==");
    const data = try parseDataUrl(std.testing.allocator, txt);
    _ = data;
}

test "jdo ico" {
    const ico = try Ico.init(std.testing.allocator, "test/jdo.txt");
    std.testing.expect(ico == ico);
}
