const std = @import("std");

pub fn rotate_vertex_inplace(M: [9]f32, xs: []f32, ys: []f32, zs: []f32) void {
    for (xs, ys, zs) |*x, *y, *z| {
        const x0, const y0, const z0 = .{x.*, y.*, z.*};
        x.* = M[0]*x0 + M[1]*y0 + M[2]*z0;
        y.* = M[3]*x0 + M[4]*y0 + M[5]*z0;
        z.* = M[6]*x0 + M[7]*y0 + M[8]*z0;
    }
}

pub fn sort_vertex_inplace(ns: []u32, xs: []f32, ys: []f32, zs: []f32) void {
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

    std.sort.heapContext(0, ns.len, query);
}

pub fn sort_tets_inplace(index: []u32, rank: []u32) void {
    const SortQuery = struct {
        index: []u32,
        rank: []u32,

        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return ctx.rank[a] < ctx.rank[b];
        }

        pub fn swap(ctx: @This(), a: usize, b: usize) void {
            std.mem.swap(u32, &ctx.index[a], &ctx.index[b]);
            std.mem.swap(u32, &ctx.rank[a], &ctx.rank[b]);
        }
    };

    const query: SortQuery = .{
        .index = index,
        .rank = rank,
    };

    std.sort.heapContext(0, index.len, query);
}