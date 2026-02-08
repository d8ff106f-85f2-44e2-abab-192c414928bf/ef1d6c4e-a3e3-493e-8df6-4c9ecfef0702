# Mesh Slicing Acceleration Demo

(falling asleep, typing key points first, polish wording when I wake up with a clearer head)

## Optimization Approach

Key idea:
- only sliding along plane needs to be smooth for operator examining flaws in the mesh
- changing plane orientation is an infrequent and deliberate action
- we can do as much precomputation of acceleration structure during plane orientation change
- just rotate all coordinates to parallel to plane and sort by plane distance, 
  then it's just a simple 1D lookup, no need for fancy hierarichal structure
- pre-rotating the coordinate system also greatly simplifies the triangle intersection test,
  such that one could even use an index-based lookup data structure 

With 5M tets in a 100x100x100 cubic mesh:
- Per-orientation precomputation takes about 1 sec for optimized builds, 5 sec for debug builds
- Per-slice live computation gets to about 150fps for optimized builds, 60 for debug builds

(SDL's line render func is really slow, prolly should've started with the SDL GPU API instead if I had time.)

Memory layout:

```
vertex table
||       |       |       ||       |       |       |          ||         |        |        |        ||
||       |       |       ||       |       |       |          ||         |        |        |        ||
|| src x | src y | src z || rot x | rot y | rot z | rot rank || sort id | sort x | sort y | sort z ||
||       |       |       ||       |       |       |          ||         |        |        |        ||
||       |       |       ||       |       |       |          ||         |        |        |        ||

tetrahedrons table
||             |     |     ||             |          ||             |          ||
||             |     |     ||             |          ||             |          ||
|| v0 v1 v2 v3 | min | max || min_sort id | min_sort || max_sort id | max_sort ||
||             |     |     ||             |          ||             |          ||
||             |     |     ||             |          ||             |          ||
```
(TODO: actually explaining the index pointers, where data are memcpy'd and sorted inplace etc)

(TODO: talk about my approach with bit-twiddling look-up-table for fast triangle case detection)


## Deliverables Checklist

Not completed:
- model loader -- omitted due to time constraint, 
  instead use a runtime-generated mesh of equivalent density (5 millionn tets in a 100^3 cube) to benchmark perf

Completed:
- slice visualizer and plane input (slider, and reorient at runtime), also with model zoom and rotation interaction
- algorithmic performance -- the optimized culling and edge calculation algorithm runs about 150fps on my i5-1245U laptop for optimized build, and about 60fps for debug build with asserts (benchmark.zig). With graphics is a bit slower, see next section.
- triangle intersection test and drawing -- stores three u32 indices and two weight fraction floats, instead of the naive six-floats vertex list.

Partially complete:
- web demo -- aside from the model loader not implemented, with the 5M tets equiv runtime-generated mesh I ran into out-of-memory issues which I couldn't quite figure out how to configure Emscripten's build options to overcome in time.
  So sadly the web version had to be limited to 40k tets. Use the native builds for accurate perforance evals instead.
- rendering performance -- uses SDL's very slow line-render function, which ate away quite some of the performance gained by my alg
- "clean code" -- not enough time, had to hurriedly shove the benchmark code into the SDL boilerplate as ugly global variables.

Future wishlist
- SIMD and cache optimization: need to rethink some of the data structure. 
  Matrix multiply is negligible while sorting is the main bottleneck, 
  data access with parallel arrays makes swaps during sorting less than ideal,
  but homogeneous arrays are needed for quick memcpy for the sorting steps so it's a tradeoff
- Proj requirement did not explicitly say the model needs to be rendered, just the cuts. Still, a 3D modeling software that do not render its models may be considered by some as not being entirely useful for their purpose.
- Actually benchmark perf rigorously.
- have a fleeting feeling that there might be some uncaught less-than-or-equal vs greater-than inconsistencies that might cause edge cases of weird popping when near thresholds of vertices just barely touching the slice plane to the limits of f32 precision. Need to closely comb through each instance to prove the equalities are watertight.


## Acknowledgements
- Castholm helped me with getting Emscripten to work. And also for adapting the SDL package for Zig in the first place.