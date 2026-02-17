# React-Three-Fiber Mesh Slicing Acceleration Demo

Video demo:

https://github.com/d8ff106f-85f2-44e2-abab-192c414928bf/ef1d6c4e-a3e3-493e-8df6-4c9ecfef0702/releases/download/r3f-asset/2026-02-17_05-19-55.mp4

## Optimization Approach

### Slicing

- only sliding along plane needs to be smooth for operator examining flaws in the mesh
- changing plane orientation is an infrequent and deliberate action
- we can do as much precomputation of acceleration structure during plane orientation change
- just rotate all coordinates to parallel to plane and sort by plane distance, 
  then it's just a simple 1D lookup, no need for fancy hierarichal structure
- pre-rotating the coordinate system also greatly simplifies the triangle intersection test,
  such that one could even use an index-based lookup data structure 

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

### Parsing

- Parsing reads nodes and elements as a sparse set each indexing into their dense array
- Element node references point to the node dense array indices, not their sparse IDs
- To save memory, parser and slicer are split to two separate modules, each has its own memory space. 
- Parser loads file and computes dense array, which is then copied to the slicer's address space via JS.
- Parser is discarded after completing data transfer to slicer. Only slicer is persistent.

### Rendering

- The initial LineSegments mesh is created with a BufferAttribute that references the slicer's WASM memory directly.
- On update, the slicer is run and then the BufferAttribute is set to require update, with update range set to what's returned from the slicer.