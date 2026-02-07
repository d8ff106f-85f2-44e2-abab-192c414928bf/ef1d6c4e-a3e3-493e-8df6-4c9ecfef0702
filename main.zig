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

    generate_dummy_mesh(4);
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
    var vert: [len * len * len][3]f32 = undefined;
    var tets: [len * len * len * 5][4]u32 = undefined;
    for (0..len) |x| {
        for (0..len) |y| {
            for (0..len) |z| {
                const xu32: u32 = @truncate(x);
                const yu32: u32 = @truncate(y);
                const zu32: u32 = @truncate(z);
                const xi  = xu32 * len * len;
                const yi  = yu32 * len;
                const zi  = zu32;
                const xii = (xu32+1) * len * len;
                const yii = (yu32+1) * len;
                const zii = (zu32+1);
                const v0 = xi  + yi  + zi;
                const v1 = xii + yi  + zi;
                const v2 = xi  + yii + zi;
                const v3 = xii + yii + zi;
                const v4 = xi  + yi  + zii;
                const v5 = xii + yi  + zii;
                const v6 = xi  + yii + zii;
                const v7 = xii + yii + zii;
                tets[xi..][yi*5..][zi*5..][0] = .{ v0, v3, v5, v6 };
                tets[xi..][yi*5..][zi*5..][1] = .{ v1, v3, v5, v0 };
                tets[xi..][yi*5..][zi*5..][2] = .{ v2, v3, v0, v6 };
                tets[xi..][yi*5..][zi*5..][3] = .{ v4, v0, v5, v6 };
                tets[xi..][yi*5..][zi*5..][4] = .{ v7, v3, v5, v6 };
                vert[xi..][yi..][zi][0] = @floatFromInt(xu32);
                vert[xi..][yi..][zi][1] = @floatFromInt(yu32);
                vert[xi..][yi..][zi][2] = @floatFromInt(zu32);
                vert[xi..][yi..][zi][0] /= 10;
                vert[xi..][yi..][zi][1] /= 10;
                vert[xi..][yi..][zi][2] /= 10;
            }
        }
    }

    for (vert[0..10]) |v| {
        std.debug.print("{any}\n", .{v});
    }

    for (tets[0..10]) |t| {
        std.debug.print("{any} {any} {any} {any}\n", .{ vert[t[0]], vert[t[1]], vert[t[2]], vert[t[3]] });
    }

}