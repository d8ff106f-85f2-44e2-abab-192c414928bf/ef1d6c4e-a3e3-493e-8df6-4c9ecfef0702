const std = @import("std");
const core = @import("core.zig");

const Meta = extern struct {
    lines_buffer_ptr: [*][2][3]f32,
    ns_src: [*]u32,
    xs_src: [*]f32,
    ys_src: [*]f32,
    zs_src: [*]f32,
    xs_unsorted: [*]f32,
    ys_unsorted: [*]f32,
    zs_unsorted: [*]f32,
    rs_unsorted: [*]u32,
    ns: [*]u32,
    xs: [*]f32,
    ys: [*]f32,
    zs: [*]f32,
    tets: [*][4]u32,
    tets_nums_orig: [*]u32,
    tets_mins_orig: [*]u32,
    tets_maxs_orig: [*]u32,
    mins_nums: [*]u32,
    maxs_nums: [*]u32,
    mins: [*]u32,
    maxs: [*]u32,
    pass_buffer: [*]u32,
    cuts_buffer: [*]Cut,

    nodes_count: u32,
    elems_count: u32,

};


export fn initMemory(nodes_count: u32, elems_count: u32) ?*Meta {
    return init(nodes_count, elems_count) catch return null;
}

export fn reorient(meta: *Meta, i: f32, j: f32, k: f32, l: f32) void {
    recalculate_plane(meta, .{.i=i,.j=j,.k=k,.l=l});
}

export fn reslice(meta: *Meta, frac: f32) u32 {
    const xs_src = meta.xs_src[0..meta.nodes_count];
    const ys_src = meta.ys_src[0..meta.nodes_count];
    const zs_src = meta.zs_src[0..meta.nodes_count];
    const cuts = recalculate_cuts(meta, frac);
    for (cuts, 0..) |cut, i| {
        meta.lines_buffer_ptr[i] = cut.calcCoords(xs_src, ys_src, zs_src);
    }
    return cuts.len;
}

fn init(nodes_count: u32, elems_count: u32) !*Meta {
    const meta_buf = try std.heap.page_allocator.alloc(Meta, 1);
    const meta = &meta_buf[0];
    const lines_buffer = try std.heap.page_allocator.alloc([2][3]f32, elems_count * 4);
    meta.lines_buffer_ptr = lines_buffer.ptr;
    meta.nodes_count = nodes_count;
    meta.elems_count = elems_count;


    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    const allocator = arena.allocator();


    const ns_src = try allocator.alloc(u32, nodes_count);

    const xs_src = try allocator.alloc(f32, nodes_count);
    const ys_src = try allocator.alloc(f32, nodes_count);
    const zs_src = try allocator.alloc(f32, nodes_count);

    const xs_unsorted = try allocator.alloc(f32, nodes_count);
    const ys_unsorted = try allocator.alloc(f32, nodes_count);
    const zs_unsorted = try allocator.alloc(f32, nodes_count);

    const rs_unsorted = try allocator.alloc(u32, nodes_count);

    const ns = try allocator.alloc(u32, nodes_count);

    const xs = try allocator.alloc(f32, nodes_count);
    const ys = try allocator.alloc(f32, nodes_count);
    const zs = try allocator.alloc(f32, nodes_count);

    const tets = try allocator.alloc([4]u32, elems_count);

    const tets_nums_orig = try allocator.alloc(u32, elems_count);
    const tets_mins_orig = try allocator.alloc(u32, elems_count);
    const tets_maxs_orig = try allocator.alloc(u32, elems_count);

    const mins_nums = try allocator.alloc(u32, elems_count);
    const maxs_nums = try allocator.alloc(u32, elems_count);
    const mins = try allocator.alloc(u32, elems_count);
    const maxs = try allocator.alloc(u32, elems_count);
    const pass_buffer = try allocator.alloc(u32, elems_count);

    const cuts_buffer = try allocator.alloc(Cut, elems_count * 4);




    meta.ns_src = ns_src.ptr;

    meta.xs_src = xs_src.ptr;
    meta.ys_src = ys_src.ptr;
    meta.zs_src = zs_src.ptr;

    meta.xs_unsorted = xs_unsorted.ptr;
    meta.ys_unsorted = ys_unsorted.ptr;
    meta.zs_unsorted = zs_unsorted.ptr;

    meta.rs_unsorted = rs_unsorted.ptr;

    meta.ns = ns.ptr;

    meta.xs = xs.ptr;
    meta.ys = ys.ptr;
    meta.zs = zs.ptr;

    meta.tets = tets.ptr;

    meta.tets_nums_orig = tets_nums_orig.ptr;
    meta.tets_mins_orig = tets_mins_orig.ptr;
    meta.tets_maxs_orig = tets_maxs_orig.ptr;

    meta.mins_nums = mins_nums.ptr;
    meta.maxs_nums = maxs_nums.ptr;
    meta.mins = mins.ptr;
    meta.maxs = maxs.ptr;
    meta.pass_buffer = pass_buffer.ptr;

    meta.cuts_buffer = cuts_buffer.ptr;




    return meta;
}




















const Cut = struct {
    v0: u32, // retained vertex
    v1: u32, // truncated vertex 1
    v2: u32, // truncated vertex 2
    w1: f32, // weight of truncated vertex 1
    w2: f32, // weight of truncated vertex 2
    pub fn calcCoords(cut: Cut, x: []const f32, y: []const f32, z: []const f32) [2][3]f32 {
        const p0: @Vector(3, f32) = .{ x[cut.v0], y[cut.v0], z[cut.v0] };
        const p1: @Vector(3, f32) = .{ x[cut.v1], y[cut.v1], z[cut.v1] };
        const p2: @Vector(3, f32) = .{ x[cut.v2], y[cut.v2], z[cut.v2] };
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

fn recalculate_cuts(meta: *Meta, frac: f32) []const Cut {

    const zs_unsorted = meta.zs_unsorted[0..meta.nodes_count];
    const zs = meta.zs[0..meta.nodes_count];
    const tets = meta.tets[0..meta.elems_count];
    const tets_mins_orig = meta.tets_mins_orig[0..meta.elems_count];
    const tets_maxs_orig = meta.tets_maxs_orig[0..meta.elems_count];
    const mins_nums = meta.mins_nums[0..meta.elems_count];
    const maxs_nums = meta.maxs_nums[0..meta.elems_count];
    const mins = meta.mins[0..meta.elems_count];
    const maxs = meta.maxs[0..meta.elems_count];
    const pass_buffer = meta.pass_buffer[0..meta.elems_count];
    const cuts_buffer = meta.cuts_buffer[0..meta.elems_count * 4];



    const test_slice_z = @min(zs[0], zs[zs.len-1]) * (1 - frac) + frac * @max(zs[0], zs[zs.len-1]);

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

    // now iterate through all remaining
    var pass_count: u32 = 0;
    if (maxs_pass.len <= mins_pass.len) {
        for (maxs_pass) |tet_index| {
            if (pass_count >= pass_total) break;
            if (tets_mins_orig[tet_index] < critical_rank) {
                pass_buffer[pass_count] = tet_index;
                pass_count += 1;
            }
        }
    } else {
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

    return cuts_buffer[0..cuts_count];
}

fn recalculate_plane(meta: *Meta, q: Quat) void {
    const M = q.asMatrix();
    // std.debug.print("begin precompute...\n", .{});

    const xs_unsorted = meta.xs_unsorted[0..meta.nodes_count];
    const ys_unsorted = meta.ys_unsorted[0..meta.nodes_count];
    const zs_unsorted = meta.zs_unsorted[0..meta.nodes_count];
    const rs_unsorted = meta.rs_unsorted[0..meta.nodes_count];
    const ns_src = meta.ns_src[0..meta.nodes_count];
    const xs_src = meta.xs_src[0..meta.nodes_count];
    const ys_src = meta.ys_src[0..meta.nodes_count];
    const zs_src = meta.zs_src[0..meta.nodes_count];
    const ns = meta.ns[0..meta.nodes_count];
    const xs = meta.xs[0..meta.nodes_count];
    const ys = meta.ys[0..meta.nodes_count];
    const zs = meta.zs[0..meta.nodes_count];
    const tets = meta.tets[0..meta.elems_count];
    const tets_nums_orig = meta.tets_nums_orig[0..meta.elems_count];
    const tets_mins_orig = meta.tets_mins_orig[0..meta.elems_count];
    const tets_maxs_orig = meta.tets_maxs_orig[0..meta.elems_count];
    const mins_nums = meta.mins_nums[0..meta.elems_count];
    const maxs_nums = meta.maxs_nums[0..meta.elems_count];
    const mins = meta.mins[0..meta.elems_count];
    const maxs = meta.maxs[0..meta.elems_count];

    
    @memcpy(xs_unsorted, xs_src);
    @memcpy(ys_unsorted, ys_src);
    @memcpy(zs_unsorted, zs_src);
    
    // const t1 = std.time.milliTimestamp();
    
    core.rotate_vertex_inplace(M, xs_unsorted, ys_unsorted, zs_unsorted);
    @memcpy(ns, ns_src);
    @memcpy(xs, xs_unsorted);
    @memcpy(ys, ys_unsorted);
    @memcpy(zs, zs_unsorted);
    core.sort_vertex_inplace(ns, xs, ys, zs);

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

    core.sort_tets_inplace(mins_nums, mins);
    core.sort_tets_inplace(maxs_nums, maxs);

    
    // const t2 = std.time.milliTimestamp();
    // const dt1: f32 = @floatFromInt(t2 - t1);
    // std.debug.print("precomputed in {d} sec.\n", .{dt1 / 1000});
}
















const Quat = struct {
    i: f32 = 0, j: f32 = 0, k: f32 = 0, l: f32 = 1,
    fn mul(a: Quat, b: Quat) Quat {
        const ii, const ij, const ik, const il,
        const ji, const jj, const jk, const jl,
        const ki, const kj, const kk, const kl,
        const li, const lj, const lk, const ll = outer(a,b);       
        return .{ 
            .i = li-kj+jk+il, 
            .j = lj+ki+jl-ik, 
            .k = lk+kl-ji+ij, 
            .l = ll-kk-jj-ii,
        };
    }
    fn outer(a: Quat, b: Quat) [16]f32 {
        return .{
            a.i*b.i,a.i*b.j,a.i*b.k,a.i*b.l,
            a.j*b.i,a.j*b.j,a.j*b.k,a.j*b.l,
            a.k*b.i,a.k*b.j,a.k*b.k,a.k*b.l,
            a.l*b.i,a.l*b.j,a.l*b.k,a.l*b.l,
        };
    }
    fn asMatrix(q: Quat) [9]f32 {
        const ii, const ij, const ik, const il,
        const ji, const jj, const jk, const jl,
        const ki, const kj, const kk, const kl,
        const li, const lj, const lk, const ll = outer(q,q);
        return .{
            ll+ii-(jj+kk), ij+ji-(kl+lk), ki+ik+(lj+jl),
            ij+ji+(kl+lk), ll+jj-(kk+ii), jk+kj-(li+il),
            ki+ik-(lj+jl), jk+kj+(li+il), ll+kk-(ii+jj),
        };
    }
    fn fromTwoVec(a: [3]f32, b: [3]f32) Quat {
        const c = .{
            a[1]*b[2] - a[2]*b[1],
            a[2]*b[0] - a[0]*b[2],
            a[0]*b[1] - a[1]*b[0],
        };
        const aa = a[0]*a[0] + a[1]*a[1] + a[2]*a[2];
        const bb = b[0]*b[0] + b[1]*b[1] + b[2]*b[2];
        const cc = c[0]*c[0] + c[1]*c[1] + c[2]*c[2];
        if (aa == 0 or bb == 0) return .{};
        return .{
            .i = c[0] / @sqrt(aa * bb),
            .j = c[1] / @sqrt(aa * bb),
            .k = c[2] / @sqrt(aa * bb),
            .l = @sqrt(1 - cc / aa / bb),
        };        
    }
};



