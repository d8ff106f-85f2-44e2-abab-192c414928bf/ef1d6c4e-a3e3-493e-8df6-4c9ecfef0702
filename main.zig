const std = @import("std");

const LENGTH = 1024 * 1024 * 5;
var xs: [LENGTH]f32 = undefined;
var ys: [LENGTH]f32 = undefined;
var zs: [LENGTH]f32 = undefined;
var ns: [LENGTH]u32 = undefined;

pub fn main() void {
    // pre-populate randomish z
    // alg from https://stackoverflow.com/a/215818
    var u: u32 = @truncate(@as(u64, @bitCast(std.time.milliTimestamp())));
    var v: u32 = u % 65536 ;
    for (0..LENGTH) |i| {
        v = 36969 * (v & 65535) + (v >> 16);
        u = 18000 * (u & 65535) + (u >> 16);
        const z: f32 = @floatFromInt((v << 16) + (u & 65535));
        xs[i] = z;
        ys[i] = z;
        zs[i] = z;
        ns[i] = @truncate(i);
    }

    for (0..10) |i| {
        std.debug.print("{any},{any},{any},{any}\n", .{ xs[i], ys[i], zs[i], ns[i] });
    }

    const SortQuery = struct {
        xs: []f32,
        ys: []f32,
        zs: []f32,
        ns: []u32,

        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return ctx.zs[a] < ctx.zs[b];
        }

        pub fn swap(ctx: @This(), a: usize, b: usize) void {
            std.mem.swap(f32, &ctx.xs[a], &ctx.xs[b]);
            std.mem.swap(f32, &ctx.ys[a], &ctx.ys[b]);
            std.mem.swap(f32, &ctx.zs[a], &ctx.zs[b]);
            std.mem.swap(u32, &ctx.ns[a], &ctx.ns[b]);
        }
    };
    const query: SortQuery = .{
        .xs = &xs,
        .ys = &ys,
        .zs = &zs,
        .ns = &ns,
    };

    const before = std.time.milliTimestamp();
    std.sort.heapContext(0, LENGTH, query);
    const after = std.time.milliTimestamp();
    const dt: f32 = @floatFromInt(after - before);

    std.debug.print("sorted in {d} sec:\n", .{dt / 1000});

    for (0..10) |i| {
        std.debug.print("{any},{any},{any},{any}\n", .{ xs[i], ys[i], zs[i], ns[i] });
    }
}
