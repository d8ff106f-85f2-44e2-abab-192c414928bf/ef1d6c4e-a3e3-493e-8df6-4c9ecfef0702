import { createRoot } from 'react-dom/client'
import { Canvas, useFrame } from '@react-three/fiber'
import { OrbitControls } from '@react-three/drei'
import * as THREE from 'three'

let buffer = new Float32Array([0,0,0,0,1,0]);
let position = {};
let geometry = {};

let slicer_wasm = {};
let slicer_data = 0;

let slider_value = 0;
let last_slider_value = 0;
{
    const slider = document.getElementById('slider');
    slider.addEventListener("input", (e)=>slider_value = event.target.value);
    slider_value = slider.value;
}

async function init() {
    
    const file = await (await fetch("core_sample_hybrid_CFD.msh")).blob();
    const file_size = file.size;
    const file_stream = file.stream();

    // const file_stream = upload.files[0].stream();
    // const file_size = upload.files[0].size;


    const parser_memory = new WebAssembly.Memory({
        initial: 17,
        maximum: 65536,
    });

    const parser = await WebAssembly.instantiateStreaming(
        await fetch("wasm-parser.wasm"),
        {
            env: { 
                memory: parser_memory,
                log_node_start: ()=>console.log("parsing nodes..."), 
                log_elem_start: ()=>console.log("parsing elems..."),
            },
        },
    );

    const file_ptr = parser.instance.exports.initMemory(file_size);
    if (file_ptr == 0) {
        console.log("failed to init parser memory");
        return;
    }


    const destination = new Uint8Array(parser_memory.buffer, file_ptr, file_size);
    let offset = 0;
    for await (const chunk of file_stream) {
        destination.set(chunk, offset);
        offset += chunk.length;
    }

    console.log("parsing model...");
    const meta_ptr = parser.instance.exports.parseModel(file_ptr, file_size);
    if (meta_ptr == 0) {
        console.log("failed to parse model");
        return;
    }

    
    const meta = new Uint32Array(parser_memory.buffer, meta_ptr, 7);


    
    const nodes_count = meta[0];
    const elems_count = meta[1];
    const nodes_x_ptr = meta[2];
    const nodes_y_ptr = meta[3];
    const nodes_z_ptr = meta[4];
    const elems_v_ptr = meta[5];
    const nodes_n_ptr = meta[6];

    

    const xs_src = new Float32Array(parser_memory.buffer, nodes_x_ptr, nodes_count);
    const ys_src = new Float32Array(parser_memory.buffer, nodes_y_ptr, nodes_count);
    const zs_src = new Float32Array(parser_memory.buffer, nodes_z_ptr, nodes_count);
    const tets_src = new Uint32Array(parser_memory.buffer, elems_v_ptr, elems_count * 4);
    const ns_src = new Uint32Array(parser_memory.buffer, nodes_n_ptr, nodes_count);

    const slicer_memory = new WebAssembly.Memory({
        initial: 17,
        maximum: 65536,
    });

    const slicer = await WebAssembly.instantiateStreaming(
        await fetch("wasm-slicer.wasm"),
        {
            env: { 
                memory: slicer_memory,
            },
        },
    );


    const data_ptr = slicer.instance.exports.initMemory(nodes_count, elems_count);
    if (data_ptr == 0) {
        console.log("failed to init slicer memory");
        return;
    }

    const data = new Uint32Array(slicer_memory.buffer, data_ptr, 26);

    const ns_dst = new Uint32Array(slicer_memory.buffer, data[1], nodes_count);
    const xs_dst = new Float32Array(slicer_memory.buffer, data[2], nodes_count);
    const ys_dst = new Float32Array(slicer_memory.buffer, data[3], nodes_count);
    const zs_dst = new Float32Array(slicer_memory.buffer, data[4], nodes_count);
    const tets_dst = new Uint32Array(slicer_memory.buffer, data[13], elems_count * 4);

    ns_dst.set(ns_src);
    xs_dst.set(xs_src);
    ys_dst.set(ys_src);
    zs_dst.set(zs_src);
    tets_dst.set(tets_src);

    console.log(ns_dst[0]);
    console.log(xs_dst[0]);
    console.log(ys_dst[0]);
    console.log(zs_dst[0]);

    console.log(ns_dst[nodes_count-1]);
    console.log(xs_dst[nodes_count-1]);
    console.log(ys_dst[nodes_count-1]);
    console.log(zs_dst[nodes_count-1]);

    console.log("reoreinting...");
    slicer.instance.exports.reorient(data_ptr, 0,0,0,1 );

    console.log("reslicing...");
    const cuts = slicer.instance.exports.reslice(data_ptr, slider_value);
    console.log(cuts);

    slicer_data = data_ptr;
    slicer_wasm = slicer;


    buffer = new Float32Array(slicer_memory.buffer, data[0], elems_count * 4 * 6);

    position = new THREE.BufferAttribute( buffer , 3 );
    geometry.setAttribute('position', position);
    const update_start = 0; // f32 at index 0
    const update_count = cuts * 6; // six f32 per cut

    const verts_count = cuts * 2; // two verts per cut
    geometry.setDrawRange(0, verts_count);
    position.clearUpdateRanges();
    position.addUpdateRange(update_start, update_count);
    position.needsUpdate = true;

}

function cuts_useframe(state, dt) {
    if (last_slider_value == slider_value) return;
    last_slider_value = slider_value

    console.log("reslicing...");
    const cuts = slicer_wasm.instance.exports.reslice(slicer_data, slider_value);
    console.log(cuts);


    const update_start = 0; // f32 at index 0
    const update_count = cuts * 6; // six f32 per cut

    const verts_count = cuts * 2; // two verts per cut

    geometry.setDrawRange(0, verts_count);
    position.clearUpdateRanges();
    position.addUpdateRange(update_start, update_count);
    position.needsUpdate = true;

}

function Cuts() {
    useFrame(cuts_useframe);

    const material = new THREE.LineBasicMaterial();
    position = new THREE.BufferAttribute( buffer , 3 );
    geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', position);
    geometry.setDrawRange(0, 2);

    init();
    return <lineSegments geometry={geometry} material={material} />
}

createRoot(document.getElementById("main")).render(
    <Canvas camera={{ position: [0, 0, -100] }}>
        <Cuts />
        <gridHelper />
        <OrbitControls  enableDamping={false} />
    </Canvas>
)
