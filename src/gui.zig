const std = @import("std");
const sdl_imports = @import("sdl_imports.zig");
const C = sdl_imports.C;


fn mvd(m: [9]f32, v: [3]f32, d: [3]f32) [3]f32 {
    return .{
        m[0]*(v[0]+d[0]) + m[1]*(v[1]+d[1]) + m[2]*(v[2]+d[2]),
        m[3]*(v[0]+d[0]) + m[4]*(v[1]+d[1]) + m[5]*(v[2]+d[2]),
        m[6]*(v[0]+d[0]) + m[7]*(v[1]+d[1]) + m[8]*(v[2]+d[2]),
    };
}
const Cut = @import("main.zig").Cut;
pub fn drawScene(renderer: *C.SDL_Renderer, w: f32, h: f32, zoom: f32, m: [9]f32, cuts: []const Cut, vertices: [3][]const f32) void {
    const scale = (@min(w,h) / 2) * @exp2(zoom / 12);
    const offset: [3]f32 = .{ -0.5, -0.5, -0.5 };

    const corners: [8][3]f32 = .{
        .{ 0, 0, 0 },
        .{ 1, 0, 0 },
        .{ 0, 1, 0 },
        .{ 1, 1, 0 },
        .{ 0, 0, 1 },
        .{ 1, 0, 1 },
        .{ 0, 1, 1 },
        .{ 1, 1, 1 },
    };
    const edges: [12][2]u3 = .{
        .{ 0, 1 },
        .{ 0, 2 },
        .{ 0, 4 },
        .{ 1, 3 },
        .{ 3, 2 },
        .{ 2, 6 },
        .{ 6, 4 },
        .{ 4, 5 },
        .{ 5, 1 },
        .{ 7, 3 },
        .{ 7, 5 },
        .{ 7, 6 },
    };


    // transform the eight corner vertices
    const verts: [8][3]f32 = .{
        mvd(m, corners[0], offset),
        mvd(m, corners[1], offset),
        mvd(m, corners[2], offset),
        mvd(m, corners[3], offset),
        mvd(m, corners[4], offset),
        mvd(m, corners[5], offset),
        mvd(m, corners[6], offset),
        mvd(m, corners[7], offset),
    };

    for (edges) |n| {
        const p0 = verts[n[0]];
        const p1 = verts[n[1]];
        const pts: [2]C.SDL_FPoint = .{
            .{ .x = p0[0] * scale + w/2, .y = p0[1] * scale + h/2 },
            .{ .x = p1[0] * scale + w/2, .y = p1[1] * scale + h/2 },
        };
        _ = C.SDL_RenderLines(
            renderer,
            &pts,
            pts.len,
        );

    }

    for (cuts) |cut| {
        const pair = cut.calcCoords(vertices[0],vertices[1],vertices[2]);


        
        const p0 = mvd(m, pair[0], offset);
        const p1 = mvd(m, pair[1], offset);
        const pts: [2]C.SDL_FPoint = .{
            .{ .x = p0[0] * scale + w/2, .y = p0[1] * scale + h/2 },
            .{ .x = p1[0] * scale + w/2, .y = p1[1] * scale + h/2 },
        };
        _ = C.SDL_RenderLines(
            renderer,
            &pts,
            pts.len,
        );

    }

}

pub fn drawSlider(renderer: *C.SDL_Renderer, x: f32, y: f32, w: f32, h: f32, value: f32) void {
    _ = C.SDL_RenderFillRect(
        renderer, 
        &.{
            .x = x,
            .y = y,
            .w = w * value,
            .h = h,
        },
    );
    const pts: [5]C.SDL_FPoint = .{
        .{ .x = x, .y = y },
        .{ .x = x + w, .y = y },
        .{ .x = x + w, .y = y + h },
        .{ .x = x, .y = y + h },
        .{ .x = x, .y = y },
    };
    _ = C.SDL_RenderLines(
        renderer,
        &pts,
        pts.len,
    );
}