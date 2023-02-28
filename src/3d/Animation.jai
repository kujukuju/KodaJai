
Animation :: struct {
    name: string;
    joint_count: int;
    frames: [..] AnimationFrame;
}

AnimationFrame :: struct {
    frame: int;
    joints: [..] Matrix4;
}

load_animation :: (path: string) -> [..] Animation, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        empty: [..] Animation;
        return empty, false;
    }

    if ends_with(path, ".glb") {
        animations, success := load_animation_glb(file);
        if !success {
            empty: [..] Animation;
            return empty, false;
        }

        return animations, true;
    } else if ends_with(path, ".gltf") {
        animations, success := load_animation_gltf(file, path);
        if !success {
            empty: [..] Animation;
            return empty, false;
        }

        return animations, true;
    } else {
        print("Unknown file type. %\n", path);
        empty: [..] Animation;
        return empty, false;
    }
}

#scope_file

load_animation_glb :: (file: string) -> [..] Animation, bool {
    json, binary, json_memory, valid := load_glb(file);
    defer free(json_memory);
    if !valid {
        empty: [..] Animation;
        return empty, false;
    }

    animations, success := load_animation_gltf_data(json, binary);
    return animations, success;
}

load_animation_gltf :: (file: string, path: string) -> [..] Animation, bool {
    json, binary, json_memory, valid := load_gltf(file, path);
    defer free(json_memory);
    if !valid {
        empty: [..] Animation;
        return empty, false;
    }

    animations, success := load_animation_gltf_data(json, binary);
    return animations, success;
}

load_animation_gltf_data :: (json: GltfJson, binary: [] u8) -> [..] Animation, bool {
    animations: [..] Animation;

    buffers := get_buffers(json, binary);
    defer array_free(buffers);

    bufferviews := get_bufferviews(json, buffers);
    defer array_free(bufferviews);

    accessors := get_accessors(json, bufferviews);
    defer array_free(accessors);

    

    inverse_binds: [..] Matrix4;
}

#scope_export
