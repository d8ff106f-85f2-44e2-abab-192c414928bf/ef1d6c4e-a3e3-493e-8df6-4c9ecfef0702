const std = @import("std");
const sdl_imports = @import("sdl_imports.zig");
const gui = @import("gui.zig");
const core = @import("core.zig");
const C = sdl_imports.C;
const errify = sdl_imports.errify; 

const window_w = 800;
const window_h = 600;


const AppState = struct{
    
    window: *C.SDL_Window,
    renderer: *C.SDL_Renderer,
    allocation: []AppState,
    initialized: bool = false,
    sliderval: f32,
    is_dragging: bool,
    cube_state: Quat,
    edges: []Cut,
    verts: [3][]f32,
    zoom: f32,


    fn init(appstate: *AppState) void {
        appstate.initialized = false;
        appstate.sliderval = 0.1;
        appstate.is_dragging = false;
        appstate.cube_state = Quat.fromTwoVec(.{0,0,1}, .{1,3,-1});
        appstate.zoom = 8;
    }
};

pub fn sdlAppInit(statestore: ?*?*anyopaque, argv: [][*:0]u8) !C.SDL_AppResult {
    _ = argv;
    

    const store = statestore orelse return error.NoStateStore;



    var arena: std.heap.ArenaAllocator = .init(std.heap.c_allocator);
    errdefer arena.deinit();
    const allocator = arena.allocator();

    ns_src = try allocator.alloc(u32, VERT_LENGTH);

    xs_src = try allocator.alloc(f32, VERT_LENGTH);
    ys_src = try allocator.alloc(f32, VERT_LENGTH);
    zs_src = try allocator.alloc(f32, VERT_LENGTH);

    xs_unsorted = try allocator.alloc(f32, VERT_LENGTH);
    ys_unsorted = try allocator.alloc(f32, VERT_LENGTH);
    zs_unsorted = try allocator.alloc(f32, VERT_LENGTH);
    
    rs_unsorted = try allocator.alloc(u32, VERT_LENGTH);

    ns = try allocator.alloc(u32, VERT_LENGTH);

    xs = try allocator.alloc(f32, VERT_LENGTH);
    ys = try allocator.alloc(f32, VERT_LENGTH);
    zs = try allocator.alloc(f32, VERT_LENGTH);

    tets = try allocator.alloc([4]u32, TETS_LENGTH);

    tets_nums_orig = try allocator.alloc(u32, TETS_LENGTH);
    tets_mins_orig = try allocator.alloc(u32, TETS_LENGTH);
    tets_maxs_orig = try allocator.alloc(u32, TETS_LENGTH);
    
    mins_nums = try allocator.alloc(u32, TETS_LENGTH);
    maxs_nums = try allocator.alloc(u32, TETS_LENGTH);
    mins = try allocator.alloc(u32, TETS_LENGTH);
    maxs = try allocator.alloc(u32, TETS_LENGTH);
    pass_buffer = try allocator.alloc(u32, TETS_LENGTH);

    cuts_buffer = try allocator.alloc(Cut, TETS_LENGTH * 4);

    core.generate_dummy_mesh(SIDE_LENGTH, ns_src, xs_src, ys_src, zs_src, tets);


    const starting_plane_eqn: [3]f32 = .{ 1,2,1 };
    recalculate_plane(Quat.fromTwoVec(.{0,0,1}, starting_plane_eqn));


    const state_alloc = try std.heap.c_allocator.alloc(AppState, 1);
    errdefer std.heap.c_allocator.free(state_alloc);

    const appstate = &state_alloc[0];
    appstate.init();
    appstate.allocation = state_alloc;
    appstate.edges = recalculate_cuts(appstate.sliderval);
    appstate.verts = .{xs_src, ys_src, zs_src};
    store.* = appstate;

    try errify(C.SDL_Init(C.SDL_INIT_VIDEO));
    try errify(C.SDL_SetHint(C.SDL_HINT_RENDER_LINE_METHOD, "2"));
    try errify(C.SDL_CreateWindowAndRenderer("game window", window_w, window_h, 0, @ptrCast(&appstate.window), @ptrCast(&appstate.renderer)));
    errdefer C.SDL_DestroyWindow(appstate.window);
    errdefer C.SDL_DestroyRenderer(appstate.renderer);

    appstate.initialized = true;
    errdefer comptime unreachable;


    return C.SDL_APP_CONTINUE;
}

var last_slider_value: f32 = 0;
pub fn sdlAppIterate(stateptr: ?*anyopaque) !C.SDL_AppResult {
    const appstate: *AppState = @alignCast(@ptrCast(stateptr orelse return error.NoStatePtr));

    if (last_slider_value != appstate.sliderval) {
        last_slider_value = appstate.sliderval;
        appstate.edges = recalculate_cuts(appstate.sliderval);
    }

    _ = C.SDL_SetRenderDrawColor(appstate.renderer, 0, 0, 0, 255);
    _ = C.SDL_RenderClear(appstate.renderer);
    _ = C.SDL_SetRenderDrawColor(appstate.renderer, 255, 255, 255, 255);

    gui.drawScene(appstate.renderer, window_w, window_h, appstate.zoom, appstate.cube_state.asMatrix(), appstate.edges, appstate.verts);

    gui.drawSlider(appstate.renderer, 10, 10, window_w-20, 20, appstate.sliderval);

    _ = C.SDL_RenderDebugText(appstate.renderer, 0, 0, "scroll to zoom, drag screen to rotate, drag slider to move plane, press space to reorient plane.");
    _ = C.SDL_RenderPresent(appstate.renderer);
    
    return C.SDL_APP_CONTINUE;
}

pub fn sdlAppEvent(stateptr: ?*anyopaque, event: *C.SDL_Event) !C.SDL_AppResult {
    const appstate: *AppState = @alignCast(@ptrCast(stateptr orelse return error.NoStatePtr));

    switch (event.type) {
        C.SDL_EVENT_QUIT => {
            return C.SDL_APP_SUCCESS;
        },
        C.SDL_EVENT_KEY_UP => {
            switch (event.key.scancode) {
                C.SDL_SCANCODE_ESCAPE => return C.SDL_APP_SUCCESS,
                C.SDL_SCANCODE_SPACE => {
                    recalculate_plane(appstate.cube_state);
                    appstate.edges = recalculate_cuts(appstate.sliderval);
                },
                else => {},
            }
        },
        C.SDL_EVENT_MOUSE_BUTTON_DOWN, C.SDL_EVENT_MOUSE_BUTTON_UP => {
            const down = event.type == C.SDL_EVENT_MOUSE_BUTTON_DOWN;
            switch (event.button.button) {
                C.SDL_BUTTON_LEFT => {
                    if (down) {
                        if (10 < event.button.y and event.button.y < 30) {
                            appstate.is_dragging = true;
                        }
                    } else {
                        appstate.is_dragging = false;
                    }
                },
                else => {},
            }
        },
        C.SDL_EVENT_MOUSE_MOTION => if (appstate.is_dragging) {
            appstate.sliderval += (event.motion.xrel / (window_w - 20));
            appstate.sliderval = @max(0, @min(appstate.sliderval, 1));


        } else if (0 != 1 & C.SDL_GetMouseState(null, null)) {
            const rx = event.motion.xrel;
            const ry = event.motion.yrel;
            const rr = rx*rx+ry*ry;
            if (rr > 0) {
                const sens = 16.0 * std.math.pi / 10800.0;
                const rad = @sqrt(rr) * sens;
                appstate.cube_state = ( Quat {
                    .i = @sin(rad/2) * ( ry) / @sqrt(rr),
                    .j = @sin(rad/2) * (-rx) / @sqrt(rr),
                    .k = 0,
                    .l = @cos(rad/2),
                } ).mul(appstate.cube_state);
            }


        },
        C.SDL_EVENT_MOUSE_WHEEL => {
            appstate.zoom += event.wheel.y;
        },
        else => {},
    }

    return C.SDL_APP_CONTINUE;
}

pub fn sdlAppQuit(stateptr: ?*anyopaque, result: anyerror!C.SDL_AppResult) void {
    const appstate: *AppState = @alignCast(@ptrCast(stateptr orelse return));
    _ = result catch {};

    if (appstate.initialized) {
        C.SDL_DestroyRenderer(appstate.renderer);
        C.SDL_DestroyWindow(appstate.window);
        appstate.initialized = false;
    }

    std.heap.c_allocator.free(appstate.allocation);
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









const SIDE_LENGTH = 100;
const NODE_LENGTH = SIDE_LENGTH + 1;
const VERT_LENGTH = NODE_LENGTH * NODE_LENGTH * NODE_LENGTH;
const TETS_LENGTH = SIDE_LENGTH * SIDE_LENGTH * SIDE_LENGTH * 5;

var ns_src: []u32 = undefined;
var xs_src: []f32 = undefined;
var ys_src: []f32 = undefined;
var zs_src: []f32 = undefined;
var xs_unsorted: []f32 = undefined;
var ys_unsorted: []f32 = undefined;
var zs_unsorted: []f32 = undefined;
var rs_unsorted: []u32 = undefined;
var ns: []u32 = undefined;
var xs: []f32 = undefined;
var ys: []f32 = undefined;
var zs: []f32 = undefined;
var tets: [][4]u32 = undefined;
var tets_nums_orig: []u32 = undefined;
var tets_mins_orig: []u32 = undefined;
var tets_maxs_orig: []u32 = undefined;
var mins_nums: []u32 = undefined;
var maxs_nums: []u32 = undefined;
var mins: []u32 = undefined;
var maxs: []u32 = undefined;
var pass_buffer: []u32 = undefined;
var cuts_buffer: []Cut = undefined;


pub const Cut = struct {
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

pub fn recalculate_cuts(frac: f32) []Cut {
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


pub fn recalculate_plane(q: Quat) void {
    const M = q.asMatrix();
    std.debug.print("begin precompute...\n", .{});
    
    @memcpy(xs_unsorted, xs_src);
    @memcpy(ys_unsorted, ys_src);
    @memcpy(zs_unsorted, zs_src);
    
    const t1 = std.time.milliTimestamp();
    
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

    
    const t2 = std.time.milliTimestamp();
    const dt1: f32 = @floatFromInt(t2 - t1);
    std.debug.print("precomputed in {d} sec.\n", .{dt1 / 1000});
}