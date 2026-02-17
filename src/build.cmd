deno run build
cd dist
zig build-exe ../wasm-parser.zig -target wasm32-freestanding -fno-entry -rdynamic --import-memory -O ReleaseFast
zig build-exe ../wasm-slicer.zig -target wasm32-freestanding -fno-entry -rdynamic --import-memory -O ReleaseFast