const std = @import("std");

const LENGTH = 1024 * 1024 * 5;

fn rand(u: *u32, v: *u32) u32 {
    v.* = 36969 * (v.* & 65535) + (v.* >> 16);
    u.* = 18000 * (u.* & 65535) + (u.* >> 16);
    return (v.* << 16) + (u.* & 65535);

}

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var ns = try allocator.alloc(u32, LENGTH);
    var xs = try allocator.alloc(f32, LENGTH);
    var ys = try allocator.alloc(f32, LENGTH);
    var zs = try allocator.alloc(f32, LENGTH);

    // pre-populate randomish z
    // alg from https://stackoverflow.com/a/215818
    var u: u32 = @truncate(@as(u64, @bitCast(std.time.milliTimestamp())));
    var v: u32 = u % 65536 ;
    for (0..LENGTH) |i| {
        ns[i] = @truncate(i);
        xs[i] = @floatFromInt(rand(&u, &v));
        ys[i] = @floatFromInt(rand(&u, &v));
        zs[i] = @floatFromInt(rand(&u, &v));
        xs[i] /= 65536;
        ys[i] /= 65536;
        zs[i] /= 65536;
    }

    for (0..10) |i| {
        std.debug.print("{any},{any},{any},{any}\n", .{ ns[i], xs[i], ys[i], zs[i] });
    }

    var M: [9]f32 = undefined;
    for (&M) |*m| {
        m.* = @floatFromInt(rand(&u, &v));
        m.* /= 65536 * 65536;
    }

    const t0 = std.time.milliTimestamp();
    rotate_inplace(M, xs, ys, zs);
    const t1 = std.time.milliTimestamp();
    sort_inplace(ns, xs, ys, zs);
    const t2 = std.time.milliTimestamp();
    const dt1: f32 = @floatFromInt(t1 - t0);
    const dt2: f32 = @floatFromInt(t2 - t1);

    std.debug.print("matmul in {d} sec:\n", .{dt1 / 1000});
    std.debug.print("sorted in {d} sec:\n", .{dt2 / 1000});

    for (0..10) |i| {
        std.debug.print("{any},{any},{any},{any}\n", .{ ns[i], xs[i], ys[i], zs[i] });
    }
}

fn rotate_inplace(M: [9]f32, xs: []f32, ys: []f32, zs: []f32) void {
    for (xs, ys, zs) |*x, *y, *z| {
        const x0, const y0, const z0 = .{x.*, y.*, z.*};
        x.* = M[0]*x0 + M[1]*y0 + M[2]*z0;
        y.* = M[3]*x0 + M[4]*y0 + M[5]*z0;
        z.* = M[6]*x0 + M[7]*y0 + M[8]*z0;
    }
}

fn sort_inplace(ns: []u32, xs: []f32, ys: []f32, zs: []f32) void {
    const SortQuery = struct {
        ns: []u32,
        xs: []f32,
        ys: []f32,
        zs: []f32,

        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return ctx.zs[a] < ctx.zs[b];
        }

        pub fn swap(ctx: @This(), a: usize, b: usize) void {
            std.mem.swap(u32, &ctx.ns[a], &ctx.ns[b]);
            std.mem.swap(f32, &ctx.xs[a], &ctx.xs[b]);
            std.mem.swap(f32, &ctx.ys[a], &ctx.ys[b]);
            std.mem.swap(f32, &ctx.zs[a], &ctx.zs[b]);
        }
    };

    const query: SortQuery = .{
        .ns = ns,
        .xs = xs,
        .ys = ys,
        .zs = zs,
    };

    std.sort.heapContext(0, LENGTH, query);
}