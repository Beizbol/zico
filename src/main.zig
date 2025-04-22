const std = @import("std");
const builtin = @import("builtin");
const Ico = @import("ico.zig");

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const gpa, const check = switch (builtin.mode) {
        .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
        .ReleaseFast => .{ std.heap.smp_allocator, false },
        .ReleaseSmall => .{ std.heap.wasm_allocator, false },
    };
    defer if (check) { // Detects Leaks
        _ = debug_allocator.deinit();
    };
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);
    if (args.len != 2) {
        std.debug.print("try: zico my.svg\n", .{});
        return;
    }

    const dir_bin = try std.fs.selfExeDirPathAlloc(gpa);
    defer gpa.free(dir_bin);

    const path_resvg = try std.fs.path.join(gpa, &[_][]const u8{ dir_bin, "resvg" });
    defer gpa.free(path_resvg);

    const path_tmp = try std.fs.path.join(gpa, &[_][]const u8{ dir_bin, "tmp" });
    defer gpa.free(path_tmp);

    std.fs.makeDirAbsolute(path_tmp) catch {};
    defer std.fs.deleteTreeAbsolute(path_tmp) catch {};

    const path_svg = args[1];
    // try validate_input(path);

    const sizes: [5]*const [2]u8 = .{
        "64", "48", "32", "24", "16",
    };

    for (sizes) |size| {
        const path_out = try std.fmt.allocPrint(
            gpa,
            "{s}/p{s}.png",
            .{ path_tmp, size },
        );
        defer gpa.free(path_out);

        const argv = [_][]const u8{
            path_resvg,
            "-w",
            size,
            "-h",
            size,
            path_svg,
            path_out,
        };

        // By default, child will inherit stdout & stderr from its parents
        var child = std.process.Child.init(&argv, gpa);
        try child.spawn();

        const term = try child.wait();
        if (term.Exited != 0) return error.ReSVG;
    }

    const img = try Ico.init(gpa, path_tmp);
    defer for (img.data) |d| {
        gpa.free(d);
    };

    try img.write("favicon.ico");
    std.debug.print("wrote favicon.ico\n", .{});
}

const assert = std.testing.expect;

test "diff icos" {
    const ta = std.testing.allocator;
    const max = 64 * 1024 * 1024;
    const good = try std.fs.cwd().readFileAlloc(ta, "test/favicon.ico", max);
    defer ta.free(good);
    const fav = try std.fs.cwd().readFileAlloc(ta, "favicon.ico", max);
    defer ta.free(fav);
    std.debug.print("diff\n", .{});
    std.debug.print("f: {any}\n", .{fav[0..64]});
    std.debug.print("g: {any}\n", .{good[0..64]});
    return error.Diff;
}
