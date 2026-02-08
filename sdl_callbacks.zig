const C = @import("sdl_imports.zig").C;

var fully_initialized = false;

const window_w = 640;
const window_h = 480;
var window: *C.SDL_Window = undefined;
var renderer: *C.SDL_Renderer = undefined;

pub fn sdlAppInit(appstate: ?*?*anyopaque, argv: [][*:0]u8) !C.SDL_AppResult {
    _ = appstate;
    _ = argv;

    try errify(C.SDL_Init(C.SDL_INIT_VIDEO));
    // defer C.SDL_Quit();

    errify(C.SDL_SetHint(C.SDL_HINT_RENDER_LINE_METHOD, "2")) catch {};

    try errify(C.SDL_CreateWindowAndRenderer("game window", window_w, window_h, 0, @ptrCast(&window), @ptrCast(&renderer)));
    errdefer C.SDL_DestroyWindow(window);
    errdefer C.SDL_DestroyRenderer(renderer);

    fully_initialized = true;
    errdefer comptime unreachable;

    return C.SDL_APP_CONTINUE;
}


pub fn sdlAppIterate(appstate: ?*anyopaque) !C.SDL_AppResult {
    _ = appstate;

    try errify(C.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xff));
    try errify(C.SDL_RenderClear(renderer));

    try errify(C.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff));
    try errify(C.SDL_RenderDebugText(renderer, 0, 0, "hello world?"));

    try errify(C.SDL_RenderPresent(renderer));
    
    return C.SDL_APP_CONTINUE;
}

pub fn sdlAppEvent(appstate: ?*anyopaque, event: *C.SDL_Event) !C.SDL_AppResult {
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

pub fn sdlAppQuit(appstate: ?*anyopaque, result: anyerror!C.SDL_AppResult) void {
    _ = appstate;
    _ = result catch {};

    if (fully_initialized) {
        C.SDL_DestroyRenderer(renderer);
        C.SDL_DestroyWindow(window);
        fully_initialized = false;
    }
}

/// Converts the return value of an SDL function to an error union.
inline fn errify(value: anytype) error{SdlError}!switch (@typeInfo(@TypeOf(value))) {
    .bool => void,
    .pointer, .optional => @TypeOf(value.?),
    .int => |info| switch (info.signedness) {
        .signed => @TypeOf(@max(0, value)),
        .unsigned => @TypeOf(value),
    },
    else => @compileError("unerrifiable type: " ++ @typeName(@TypeOf(value))),
} {
    return switch (@typeInfo(@TypeOf(value))) {
        .bool => if (!value) error.SdlError,
        .pointer, .optional => value orelse error.SdlError,
        .int => |info| switch (info.signedness) {
            .signed => if (value >= 0) @max(0, value) else error.SdlError,
            .unsigned => if (value != 0) value else error.SdlError,
        },
        else => comptime unreachable,
    };
}