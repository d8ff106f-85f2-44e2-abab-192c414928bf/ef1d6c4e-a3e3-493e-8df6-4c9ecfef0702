const std = @import("std");

const LENGTH = 1024 * 1024 * 5;

fn rand(u: *u32, v: *u32) u32 {
    v.* = 36969 * (v.* & 65535) + (v.* >> 16);
    u.* = 18000 * (u.* & 65535) + (u.* >> 16);
    return (v.* << 16) + (u.* & 65535);
}

fn init_random_points(ns: []u32, xs: []f32, ys: []f32, zs: []f32) void {
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
}

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const ns = try allocator.alloc(u32, LENGTH);
    const xs = try allocator.alloc(f32, LENGTH);
    const ys = try allocator.alloc(f32, LENGTH);
    const zs = try allocator.alloc(f32, LENGTH);

    init_random_points(ns, xs, ys, zs);

    for (0..10) |i| {
        std.debug.print("{any},{any},{any},{any}\n", .{ ns[i], xs[i], ys[i], zs[i] });
    }

    var u: u32 = @truncate(@as(u64, @bitCast(std.time.milliTimestamp())));
    var v: u32 = u % 65536 ;
    var M: [9]f32 = undefined;
    for (&M) |*m| {
        m.* = @floatFromInt(rand(&u, &v));
        m.* /= 65536 * 65536;
    }

    const t0 = std.time.milliTimestamp();
    rotate_vertex_inplace(M, xs, ys, zs);
    const t1 = std.time.milliTimestamp();
    sort_vertex_inplace(ns, xs, ys, zs);
    const t2 = std.time.milliTimestamp();
    const dt1: f32 = @floatFromInt(t1 - t0);
    const dt2: f32 = @floatFromInt(t2 - t1);

    std.debug.print("matmul in {d} sec:\n", .{dt1 / 1000});
    std.debug.print("sorted in {d} sec:\n", .{dt2 / 1000});

    for (0..10) |i| {
        std.debug.print("{any},{any},{any},{any}\n", .{ ns[i], xs[i], ys[i], zs[i] });
    }

    generate_dummy_mesh(20);
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

    std.sort.heapContext(0, LENGTH, query);
}

fn generate_dummy_mesh(comptime len: u32) void {
    var xs: [len * len * len]f32 = undefined;
    var ys: [len * len * len]f32 = undefined;
    var zs: [len * len * len]f32 = undefined;
    var tets: [len * len * len * 5][4]u32 = undefined;
    for (0..len) |x| {
        for (0..len) |y| {
            for (0..len) |z| {
                const x_u32: u32 = @truncate(x);
                const y_u32: u32 = @truncate(y);
                const z_u32: u32 = @truncate(z);
                const x0 = x_u32 * len * len;
                const y0 = y_u32 * len;
                const z0 = z_u32;
                const x1 = (x_u32+1) * len * len;
                const y1 = (y_u32+1) * len;
                const z1 = (z_u32+1);
                const v0 = x0 + y0 + z0;
                const v1 = x1 + y0 + z0;
                const v2 = x0 + y1 + z0;
                const v3 = x1 + y1 + z0;
                const v4 = x0 + y0 + z1;
                const v5 = x1 + y0 + z1;
                const v6 = x0 + y1 + z1;
                const v7 = x1 + y1 + z1;
                tets[x0..][y0*5..][z0*5..][0] = .{ v0, v3, v5, v6 };
                tets[x0..][y0*5..][z0*5..][1] = .{ v1, v3, v5, v0 };
                tets[x0..][y0*5..][z0*5..][2] = .{ v2, v3, v0, v6 };
                tets[x0..][y0*5..][z0*5..][3] = .{ v4, v0, v5, v6 };
                tets[x0..][y0*5..][z0*5..][4] = .{ v7, v3, v5, v6 };
                xs[x0..][y0..][z0] = @floatFromInt(x_u32);
                ys[x0..][y0..][z0] = @floatFromInt(y_u32);
                zs[x0..][y0..][z0] = @floatFromInt(z_u32);
                xs[x0..][y0..][z0] /= @floatFromInt(len);
                ys[x0..][y0..][z0] /= @floatFromInt(len);
                zs[x0..][y0..][z0] /= @floatFromInt(len);
            }
        }
    }

}