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

pub fn generate_dummy_mesh(
    len: u32, 
    ns: []u32,
    xs: []f32, 
    ys: []f32, 
    zs: []f32, 
    ws: [][4]u32,
) void {
    const nodes = len + 1;
    std.debug.assert(ns.len == nodes * nodes * nodes);
    std.debug.assert(xs.len == nodes * nodes * nodes);
    std.debug.assert(ys.len == nodes * nodes * nodes);
    std.debug.assert(zs.len == nodes * nodes * nodes);
    std.debug.assert(ws.len == len * len * len * 5);
    for (0..nodes) |x| {
        for (0..nodes) |y| {
            for (0..nodes) |z| {
                const n = x * nodes * nodes + y * nodes + z;
                ns[n] = @truncate(n);
                xs[n] = @floatFromInt(x);
                ys[n] = @floatFromInt(y);
                zs[n] = @floatFromInt(z);
                xs[n] /= @floatFromInt(len);
                ys[n] /= @floatFromInt(len);
                zs[n] /= @floatFromInt(len);
            }
        }
    }
    for (0..len) |x| {
        for (0..len) |y| {
            for (0..len) |z| {
                const i = x * 5 * len * len;
                const j = y * 5 * len;
                const k = z * 5;
                const x_u32: u32 = @truncate(x);
                const y_u32: u32 = @truncate(y);
                const z_u32: u32 = @truncate(z);
                const x0 = x_u32 * nodes * nodes;
                const y0 = y_u32 * nodes;
                const z0 = z_u32;
                const x1 = (x_u32+1) * nodes * nodes;
                const y1 = (y_u32+1) * nodes;
                const z1 = (z_u32+1);
                const v0 = x0 + y0 + z0;
                const v1 = x1 + y0 + z0;
                const v2 = x0 + y1 + z0;
                const v3 = x1 + y1 + z0;
                const v4 = x0 + y0 + z1;
                const v5 = x1 + y0 + z1;
                const v6 = x0 + y1 + z1;
                const v7 = x1 + y1 + z1;
                ws[i..][j..][k..][0] = .{ v0, v3, v5, v6 }; // center tet
                ws[i..][j..][k..][1] = .{ v1, v3, v5, v0 }; // lower northeast
                ws[i..][j..][k..][2] = .{ v2, v3, v0, v6 }; // upper northwest
                ws[i..][j..][k..][3] = .{ v4, v0, v5, v6 }; // lower southwest
                ws[i..][j..][k..][4] = .{ v7, v3, v5, v6 }; // upper southeast
            }
        }
    }
}

