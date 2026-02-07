const std = @import("std");

const SIDE_LENGTH = 100;
const NODE_LENGTH = SIDE_LENGTH + 1;
const VERT_LENGTH = NODE_LENGTH * NODE_LENGTH * NODE_LENGTH;
const TETS_LENGTH = SIDE_LENGTH * SIDE_LENGTH * SIDE_LENGTH * 5;

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const xs_orig = try allocator.alloc(f32, VERT_LENGTH);
    const ys_orig = try allocator.alloc(f32, VERT_LENGTH);
    const zs_orig = try allocator.alloc(f32, VERT_LENGTH);
    
    const rs_orig = try allocator.alloc(u32, VERT_LENGTH);

    const ns = try allocator.alloc(u32, VERT_LENGTH);

    const xs = try allocator.alloc(f32, VERT_LENGTH);
    const ys = try allocator.alloc(f32, VERT_LENGTH);
    const zs = try allocator.alloc(f32, VERT_LENGTH);

    const tets = try allocator.alloc([4]u32, TETS_LENGTH);
    const mins = try allocator.alloc([2]u32, TETS_LENGTH);
    const maxs = try allocator.alloc([2]u32, TETS_LENGTH);

    // var u: u32 = @truncate(@as(u64, @bitCast(std.time.milliTimestamp())));
    // var v: u32 = u % 65536 ;
    // var M: [9]f32 = undefined;
    // for (&M) |*m| {
    //     m.* = @floatFromInt(rand(&u, &v));
    //     m.* /= 65536 * 65536;
    // }

    // init_random_points(ns, xs, ys, zs);
    generate_dummy_mesh(SIDE_LENGTH, ns, xs, ys, zs, tets);
    // rotate_vertex_inplace(M, xs, ys, zs);
    @memcpy(xs_orig, xs);
    @memcpy(ys_orig, ys);
    @memcpy(zs_orig, zs);


    std.debug.print("begin precompute...\n", .{});
    const t1 = std.time.milliTimestamp();
    
    sort_vertex_inplace(ns, xs, ys, zs);


    for (ns, 0..) |index, rank| {
        rs_orig[index] = @truncate(rank);
    }

    for (tets, mins, maxs, 0..) |tet, *min, *max, i| {
        const r0 = rs_orig[tet[0]];
        const r1 = rs_orig[tet[1]];
        const r2 = rs_orig[tet[2]];
        const r3 = rs_orig[tet[3]];
        min[0] = @truncate(i);
        max[0] = @truncate(i);
        min[1] = @min(r0, r1, r2, r3);
        max[1] = @max(r0, r1, r2, r3);
    }

    sort_tets_inplace(mins);
    sort_tets_inplace(maxs);

    
    const t2 = std.time.milliTimestamp();
    const dt: f32 = @floatFromInt(t2 - t1);

    
    for (0..10) |i| {
        std.debug.print("{any} {any} {any} {any}\n", .{ mins[i][0], mins[i][1], maxs[i][0], maxs[i][1] });
    }
    
    std.debug.print("precomputed in {d} sec.\n", .{dt / 1000});


    const test_slice_z: f32 = 0.021;
    const critical_rank = rank: {
        for (zs, 0..) |z, i| {
            if (z >= test_slice_z) {
                break :rank i;
            }
        }
        break :rank zs.len;
    };

    const before_z_no_touch = count: {
        for (maxs, 0..) |meta, i| {
            if (meta[1] >= critical_rank) {
                break :count i;
            }
        }
        break :count maxs.len;
    };

    const maxs_fail = maxs[0..before_z_no_touch];

    const after_z_no_touch = count: {
        for (mins, 0..) |meta, i| {
            if (meta[1] >= critical_rank) {
                break :count i;
            }
        }
        break :count mins.len;
    };

    const mins_fail = mins[after_z_no_touch..];

    std.debug.print("critical rank: {any}\n", .{critical_rank});
    std.debug.print("{any} tets total\n", .{tets.len});
    std.debug.print("{any} tets culled by max\n", .{maxs_fail.len});
    std.debug.print("{any} tets culled by min\n", .{mins_fail.len});
    std.debug.print("{any} tets remains\n", .{tets.len - maxs_fail.len - mins_fail.len});

}

fn rotate_vertex_inplace(M: [9]f32, xs: []f32, ys: []f32, zs: []f32) void {
    for (xs, ys, zs) |*x, *y, *z| {
        const x0, const y0, const z0 = .{x.*, y.*, z.*};
        x.* = M[0]*x0 + M[1]*y0 + M[2]*z0;
        y.* = M[3]*x0 + M[4]*y0 + M[5]*z0;
        z.* = M[6]*x0 + M[7]*y0 + M[8]*z0;
    }
}

fn sort_vertex_inplace(ns: []u32, xs: []f32, ys: []f32, zs: []f32) void {
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

    std.sort.heapContext(0, VERT_LENGTH, query);
}

fn sort_tets_inplace(index_and_rank: [][2]u32) void {
    const SortQuery = struct {
        table: [][2]u32,

        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return ctx.table[a][1] < ctx.table[b][1];
        }

        pub fn swap(ctx: @This(), a: usize, b: usize) void {
            std.mem.swap([2]u32, &ctx.table[a], &ctx.table[b]);
        }
    };

    const query: SortQuery = .{
        .table = index_and_rank,
    };

    std.sort.heapContext(0, index_and_rank.len, query);
}

fn generate_dummy_mesh(
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
                ws[i..][j..][k..][1] = .{ v1, v3, v5, v0 };
                ws[i..][j..][k..][2] = .{ v2, v3, v0, v6 };
                ws[i..][j..][k..][3] = .{ v4, v0, v5, v6 };
                ws[i..][j..][k..][4] = .{ v7, v3, v5, v6 };
            }
        }
    }
}

fn rand(u: *u32, v: *u32) u32 {
    // alg from https://stackoverflow.com/a/215818
    v.* = 36969 * (v.* & 65535) + (v.* >> 16);
    u.* = 18000 * (u.* & 65535) + (u.* >> 16);
    return (v.* << 16) + (u.* & 65535);
}

fn init_random_points(ns: []u32, xs: []f32, ys: []f32, zs: []f32) void {
    var u: u32 = @truncate(@as(u64, @bitCast(std.time.milliTimestamp())));
    var v: u32 = u % 65536 ;
    for (ns, xs, ys, zs, 0..) |*n, *x, *y, *z, i| {
        n.* = @truncate(i);
        x.* = @floatFromInt(rand(&u, &v));
        y.* = @floatFromInt(rand(&u, &v));
        z.* = @floatFromInt(rand(&u, &v));
        x.* /= 65536;
        y.* /= 65536;
        z.* /= 65536;
    }
}