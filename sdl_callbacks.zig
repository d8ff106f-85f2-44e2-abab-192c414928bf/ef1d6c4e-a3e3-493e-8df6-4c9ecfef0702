const AppState = @This();
window: *C.SDL_Window,
renderer: *C.SDL_Renderer,
allocation: []AppState,
initialized: bool = false,


const std = @import("std");
const sdl_imports = @import("sdl_imports.zig");
const C = sdl_imports.C;
const errify = sdl_imports.errify; 

const window_w = 640;
const window_h = 480;

pub fn sdlAppInit(statestore: ?*?*anyopaque, argv: [][*:0]u8) !C.SDL_AppResult {
    _ = argv;

    const store = statestore orelse return error.NoStateStore;

    const state_alloc = try std.heap.c_allocator.alloc(AppState, 1);
    errdefer std.heap.c_allocator.free(state_alloc);

    const state = &state_alloc[0];
    store.* = state;
    state.allocation = state_alloc;
    state.initialized = false;

    try errify(C.SDL_Init(C.SDL_INIT_VIDEO));
    try errify(C.SDL_SetHint(C.SDL_HINT_RENDER_LINE_METHOD, "2"));
    try errify(C.SDL_CreateWindowAndRenderer("game window", window_w, window_h, 0, @ptrCast(&state.window), @ptrCast(&state.renderer)));
    errdefer C.SDL_DestroyWindow(state.window);
    errdefer C.SDL_DestroyRenderer(state.renderer);

    state.initialized = true;
    errdefer comptime unreachable;

    return C.SDL_APP_CONTINUE;
}


pub fn sdlAppIterate(stateptr: ?*anyopaque) !C.SDL_AppResult {
    const appstate: *AppState = @alignCast(@ptrCast(stateptr orelse return error.NoStatePtr));

    try errify(C.SDL_SetRenderDrawColor(appstate.renderer, 0x00, 0x00, 0x00, 0xff));
    try errify(C.SDL_RenderClear(appstate.renderer));

    try errify(C.SDL_SetRenderDrawColor(appstate.renderer, 0xff, 0xff, 0xff, 0xff));
    try errify(C.SDL_RenderDebugText(appstate.renderer, 0, 0, "hello world?"));

    try errify(C.SDL_RenderPresent(appstate.renderer));
    
    return C.SDL_APP_CONTINUE;
}

pub fn sdlAppEvent(stateptr: ?*anyopaque, event: *C.SDL_Event) !C.SDL_AppResult {
    const appstate: *AppState = @alignCast(@ptrCast(stateptr orelse return error.NoStatePtr));
    _ = appstate;

    switch (event.type) {
        C.SDL_EVENT_QUIT => {
            return C.SDL_APP_SUCCESS;
        },
        C.SDL_EVENT_KEY_UP => {
            switch (event.key.scancode) {
                C.SDL_SCANCODE_ESCAPE => return C.SDL_APP_SUCCESS,
                else => {},
            }
        },
        // C.SDL_EVENT_KEY_DOWN, C.SDL_EVENT_KEY_UP => {
        //     const down = event.type == C.SDL_EVENT_KEY_DOWN;
        //     switch (event.key.scancode) {
        //         C.SDL_SCANCODE_LEFT => phcon.k_left = down,
        //         C.SDL_SCANCODE_RIGHT => phcon.k_right = down,
        //         C.SDL_SCANCODE_LSHIFT => phcon.k_lshift = down,
        //         C.SDL_SCANCODE_SPACE => phcon.k_space = down,
        //         C.SDL_SCANCODE_R => phcon.k_r = down,
        //         C.SDL_SCANCODE_ESCAPE => phcon.k_escape = down,
        //         else => {},
        //     }
        // },
        // C.SDL_EVENT_MOUSE_BUTTON_DOWN, C.SDL_EVENT_MOUSE_BUTTON_UP => {
        //     const down = event.type == C.SDL_EVENT_MOUSE_BUTTON_DOWN;
        //     switch (event.button.button) {
        //         C.SDL_BUTTON_LEFT => phcon.m_left = down,
        //         else => {},
        //     }
        // },
        // C.SDL_EVENT_MOUSE_MOTION => {
        //     phcon.m_xrel += event.motion.xrel;
        // },
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
