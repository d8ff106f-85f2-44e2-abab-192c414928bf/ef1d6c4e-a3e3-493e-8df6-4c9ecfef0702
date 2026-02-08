const std = @import("std");

const SIDE_LENGTH = 100;
const NODE_LENGTH = SIDE_LENGTH + 1;
const VERT_LENGTH = NODE_LENGTH * NODE_LENGTH * NODE_LENGTH;
const TETS_LENGTH = SIDE_LENGTH * SIDE_LENGTH * SIDE_LENGTH * 5;

const Cut = struct {
    v0: u32, // retained vertex
    v1: u32, // truncated vertex 1
    v2: u32, // truncated vertex 2
    w1: f32, // weight of truncated vertex 1
    w2: f32, // weight of truncated vertex 2
    pub fn calcCoords(cut: Cut, xs: []f32, ys: []f32, zs: []f32) [2][3]f32 {
        const p0: @Vector(3, f32) = .{ xs[cut.v0], ys[cut.v0], zs[cut.v0] };
        const p1: @Vector(3, f32) = .{ xs[cut.v1], ys[cut.v1], zs[cut.v1] };
        const p2: @Vector(3, f32) = .{ xs[cut.v2], ys[cut.v2], zs[cut.v2] };
        const w1: @Vector(3, f32) = @splat(cut.w1);
        const w2: @Vector(3, f32) = @splat(cut.w2);
        const m1: @Vector(3, f32) = @splat(1 - cut.w1);
        const m2: @Vector(3, f32) = @splat(1 - cut.w2);
        return .{
            p0 * m1 + p1 * w1,
            p0 * m2 + p2 * w2,
        };
    }
};

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const xs_src = try allocator.alloc(f32, VERT_LENGTH);
    const ys_src = try allocator.alloc(f32, VERT_LENGTH);
    const zs_src = try allocator.alloc(f32, VERT_LENGTH);

    const xs_unsorted = try allocator.alloc(f32, VERT_LENGTH);
    const ys_unsorted = try allocator.alloc(f32, VERT_LENGTH);
    const zs_unsorted = try allocator.alloc(f32, VERT_LENGTH);
    
    const rs_unsorted = try allocator.alloc(u32, VERT_LENGTH);

    const ns = try allocator.alloc(u32, VERT_LENGTH);

    const xs = try allocator.alloc(f32, VERT_LENGTH);
    const ys = try allocator.alloc(f32, VERT_LENGTH);
    const zs = try allocator.alloc(f32, VERT_LENGTH);

    const tets = try allocator.alloc([4]u32, TETS_LENGTH);

    const tets_nums_orig = try allocator.alloc(u32, TETS_LENGTH);
    const tets_mins_orig = try allocator.alloc(u32, TETS_LENGTH);
    const tets_maxs_orig = try allocator.alloc(u32, TETS_LENGTH);
    
    const mins_nums = try allocator.alloc(u32, TETS_LENGTH);
    const maxs_nums = try allocator.alloc(u32, TETS_LENGTH);
    const mins = try allocator.alloc(u32, TETS_LENGTH);
    const maxs = try allocator.alloc(u32, TETS_LENGTH);
    const pass_buffer = try allocator.alloc(u32, TETS_LENGTH);

    const cuts_buffer = try allocator.alloc(Cut, TETS_LENGTH * 4);

    const M: [9]f32 = .{
        1, 0, 0,
        0, @cos(0.25),-@sin(0.25), 
        0, @sin(0.25), @cos(0.25),
    };

    // const M: [9]f32 = .{
    //     1, 0, 0,
    //     0, 1, 0,
    //     0, 0, 1,
    // };


    // init_random_points(ns, xs, ys, zs);

    generate_dummy_mesh(SIDE_LENGTH, ns, xs_src, ys_src, zs_src, tets);
    @memcpy(xs_unsorted, xs_src);
    @memcpy(ys_unsorted, ys_src);
    @memcpy(zs_unsorted, zs_src);
    
    std.debug.print("begin precompute...\n", .{});
    const t1 = std.time.milliTimestamp();
    
    rotate_vertex_inplace(M, xs_unsorted, ys_unsorted, zs_unsorted);
    @memcpy(xs, xs_unsorted);
    @memcpy(ys, ys_unsorted);
    @memcpy(zs, zs_unsorted);
    sort_vertex_inplace(ns, xs, ys, zs);

    for (ns, 0..) |index, rank| {
        rs_unsorted[index] = @truncate(rank);
    }

    for (tets, 0..) |tet, i| {
        const r0 = rs_unsorted[tet[0]];
        const r1 = rs_unsorted[tet[1]];
        const r2 = rs_unsorted[tet[2]];
        const r3 = rs_unsorted[tet[3]];
        tets_nums_orig[i] = @truncate(i);
        tets_mins_orig[i] = @min(r0, r1, r2, r3);
        tets_maxs_orig[i] = @max(r0, r1, r2, r3);
    }
    
    @memcpy(mins_nums, tets_nums_orig);
    @memcpy(maxs_nums, tets_nums_orig);
    @memcpy(mins, tets_mins_orig);
    @memcpy(maxs, tets_maxs_orig);

    sort_tets_inplace(mins_nums, mins);
    sort_tets_inplace(maxs_nums, maxs);

    
    const t2 = std.time.milliTimestamp();
    const dt1: f32 = @floatFromInt(t2 - t1);
    std.debug.print("precomputed in {d} sec.\n", .{dt1 / 1000});

    
    // for (0..10) |i| {
    //     std.debug.print("{any} {any} {any} {any}\n", .{ mins_nums[i], mins[i], maxs_nums[0], maxs[i] });
    // }

    const rotated_z_lower: f32 = zs[0];
    const rotated_z_upper: f32 = zs[zs.len - 1];
    

    const t3 = std.time.milliTimestamp();
    var frames: usize = 0;
    var test_slice_z: f32 = rotated_z_lower;

    
    while (test_slice_z <= rotated_z_upper) : (test_slice_z += 1.0/128.0) {
        frames += 1;
        const critical_rank = rank: {
            for (zs, 0..) |z, i| {
                if (z >= test_slice_z) {
                    break :rank i;
                }
            }
            break :rank zs.len;
        };

        const after_z_no_touch = count: {
            for (mins, 0..) |min, i| {
                if (min >= critical_rank) {
                    break :count i;
                }
            }
            break :count mins.len;
        };

        const before_z_no_touch = count: {
            for (maxs, 0..) |max, i| {
                if (max >= critical_rank) {
                    break :count i;
                }
            }
            break :count maxs.len;
        };

        const mins_pass = mins_nums[0..after_z_no_touch];
        const mins_fail = mins_nums[after_z_no_touch..];
        const maxs_pass = maxs_nums[before_z_no_touch..];
        const maxs_fail = maxs_nums[0..before_z_no_touch];
        const pass_total = tets.len - maxs_fail.len - mins_fail.len;

        // std.debug.print("critical rank: {any}\n", .{critical_rank});
        // std.debug.print("{any} tets total\n", .{tets.len});
        // std.debug.print("{any} tets culled by max\n", .{maxs_fail.len});
        // std.debug.print("{any} tets culled by min\n", .{mins_fail.len});
        // std.debug.print("{any} tets remains\n", .{tets.len - maxs_fail.len - mins_fail.len});

        // now iterate through all remaining
        var pass_count: u32 = 0;
        if (maxs_pass.len <= mins_pass.len) {
            // std.debug.print("max smaller\n", .{});
            for (maxs_pass) |tet_index| {
                if (pass_count >= pass_total) break;
                if (tets_mins_orig[tet_index] < critical_rank) {
                    pass_buffer[pass_count] = tet_index;
                    pass_count += 1;
                }
            }
        } else {
            // std.debug.print("min smaller\n", .{});
            for (mins_pass) |tet_index| {
                if (pass_count >= pass_total) break;
                if (tets_maxs_orig[tet_index] >= critical_rank) {
                    pass_buffer[pass_count] = tet_index;
                    pass_count += 1;
                }
            }
        }
        std.debug.assert(pass_count == pass_total);
        const passed_tets = pass_buffer[0..pass_count];

        var cuts_count: u32 = 0;
        for (passed_tets) |tet_index| {
            const tet = tets[tet_index];
            const odd_lut: [8][3]u2 = .{
                .{ 3, 3, 3 }, // 0, uniform
                .{ 0, 1, 2 }, // 1, a is the odd one out
                .{ 1, 2, 0 }, // 2, b is the odd one out
                .{ 2, 0, 1 }, // 3, c is the odd one out
                .{ 2, 0, 1 }, // 4, c is the odd one out
                .{ 1, 2, 0 }, // 5, b is the odd one out
                .{ 0, 1, 2 }, // 6, a is the odd one out
                .{ 3, 3, 3 }, // 7, uniform
            };
            const cases: [4][3]u2 = .{
                .{ 0, 1, 2 },
                .{ 1, 2, 3 },
                .{ 2, 3, 0 },
                .{ 3, 0, 1 },
            };
            for (cases) |vi| {
                const a, const b, const c = vi;
                const va = tet[a];
                const vb = tet[b];
                const vc = tet[c];
                const za = zs_unsorted[va] - test_slice_z;
                const zb = zs_unsorted[vb] - test_slice_z;
                const zc = zs_unsorted[vc] - test_slice_z;
                const ver_lut: [3]u32 = .{ va, vb, vc };
                var zero_case: u3 = 0;
                if (za == 0) zero_case |= 1;
                if (zb == 0) zero_case |= 2;
                if (zc == 0) zero_case |= 4;
                switch (zero_case) {
                    0 => {}, // no touch, move on to next check
                    3, 5, 6 => { // draw edge touch
                        const p = odd_lut[zero_case];
                        const v0 = ver_lut[p[0]];
                        const v1 = ver_lut[p[1]];
                        const v2 = ver_lut[p[2]];
                        cuts_buffer[cuts_count] = .{
                            .v0 = v0,
                            .v1 = v1,
                            .v2 = v2,
                            .w1 = 1,
                            .w2 = 1,
                        };
                        cuts_count += 1;
                        continue;
                    },
                    1, 2, 4, 7 => continue, // don't draw corner or face touch
                }
                var less_case: u3 = 0;
                if (za < 0) less_case |= 1;
                if (zb < 0) less_case |= 2;
                if (zc < 0) less_case |= 4;
                switch (less_case) {
                    0, 7 => {},
                    else => {
                        const p = odd_lut[less_case];
                        const v0 = ver_lut[p[0]];
                        const v1 = ver_lut[p[1]];
                        const v2 = ver_lut[p[2]];
                        const dz1 = zs_unsorted[v1] - zs_unsorted[v0];
                        const dz2 = zs_unsorted[v2] - zs_unsorted[v0];
                        const dzw = test_slice_z - zs_unsorted[v0];
                        cuts_buffer[cuts_count] = .{
                            .v0 = v0,
                            .v1 = v1,
                            .v2 = v2,
                            .w1 = dzw / dz1,
                            .w2 = dzw / dz2,
                        };
                        cuts_count += 1;
                        std.debug.assert(dz1 != 0);
                        std.debug.assert(dz2 != 0);
                    },
                }
            }
        }
        // std.debug.print("z = {any}: {any} passed tets, {any} cuts\n", .{ test_slice_z, pass_count, cuts_count });
        
        const cuts = cuts_buffer[0..cuts_count];
        
        var successes: u32 = 0;
        for (cuts) |cut| {
            const pair = cut.calcCoords(xs_unsorted,ys_unsorted,zs_unsorted);
            if (@abs(pair[0][2] - test_slice_z) < 1.0 / 65536.0) {
                successes += 1;
            }
            if (@abs(pair[1][2] - test_slice_z) < 1.0 / 65536.0) {
                successes += 1;
            }
            std.debug.assert(@abs(pair[0][2] - test_slice_z) < 1.0 / 65536.0);
            std.debug.assert(@abs(pair[1][2] - test_slice_z) < 1.0 / 65536.0);
            // std.debug.print("    {any},{any}\n", .{pair[0][2],pair[1][2]});
        }
        std.debug.print("{any} correct pts\n", .{successes});
    }
    
    const t4 = std.time.milliTimestamp();
    const dt2: f32 = @floatFromInt(t4 - t3);
    std.debug.print("{any} frames in {any} miliseconds\n", .{frames, dt2});

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

fn sort_tets_inplace(index: []u32, rank: []u32) void {
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
                ws[i..][j..][k..][1] = .{ v1, v3, v5, v0 }; // lower northeast
                ws[i..][j..][k..][2] = .{ v2, v3, v0, v6 }; // upper northwest
                ws[i..][j..][k..][3] = .{ v4, v0, v5, v6 }; // lower southwest
                ws[i..][j..][k..][4] = .{ v7, v3, v5, v6 }; // upper southeast
            }
        }
    }
}

// fn rand(u: *u32, v: *u32) u32 {
//     // alg from https://stackoverflow.com/a/215818
//     v.* = 36969 * (v.* & 65535) + (v.* >> 16);
//     u.* = 18000 * (u.* & 65535) + (u.* >> 16);
//     return (v.* << 16) + (u.* & 65535);
// }

// fn init_random_points(ns: []u32, xs: []f32, ys: []f32, zs: []f32) void {
//     var u: u32 = @truncate(@as(u64, @bitCast(std.time.milliTimestamp())));
//     var v: u32 = u % 65536 ;
//     for (ns, xs, ys, zs, 0..) |*n, *x, *y, *z, i| {
//         n.* = @truncate(i);
//         x.* = @floatFromInt(rand(&u, &v));
//         y.* = @floatFromInt(rand(&u, &v));
//         z.* = @floatFromInt(rand(&u, &v));
//         x.* /= 65536;
//         y.* /= 65536;
//         z.* /= 65536;
//     }
// }