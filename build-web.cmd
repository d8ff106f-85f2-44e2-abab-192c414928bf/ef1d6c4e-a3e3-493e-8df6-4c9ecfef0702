set emsdk_dir=..\emsdk
%emsdk_dir%\emsdk activate latest && (
    embuilder build sysroot && embuilder build emdawnwebgpu && (
        zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseFast --sysroot %emsdk_dir%\upstream\emscripten\cache\sysroot
    )
)