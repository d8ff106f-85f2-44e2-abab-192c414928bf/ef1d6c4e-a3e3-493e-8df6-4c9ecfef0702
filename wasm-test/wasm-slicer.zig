const std = @import("std");

const Meta = extern struct {
    lines_buffer_ptr: [*][2][3]f32,
    lines_count: u32,

    nodes_count: u32,
    elems_count: u32,

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
};


export fn initMemory(nodes_count: u32, elems_count: u32) ?*Meta {
    return init(nodes_count, elems_count) catch return null;
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
