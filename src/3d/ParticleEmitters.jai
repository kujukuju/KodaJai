
ParticleEmitter :: struct {
    position: Vector3;
    type: string;
}

load_particle_emitters :: (path: string) -> [..] ParticleEmitter, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        empty: [..] ParticleEmitter;
        return empty, false;
    }

    if ends_with(path, ".glb") {
        emitters, success := load_particle_emitters_glb(file);
        if !success {
            empty: [..] ParticleEmitter;
            return empty, false;
        }

        return emitters, true;
    } else if ends_with(path, ".gltf") {
        emitters, success := load_particle_emitters_gltf(file, path);
        if !success {
            empty: [..] ParticleEmitter;
            return empty, false;
        }

        return emitters, true;
    } else {
        print("Unknown file type. %\n", path);
        empty: [..] ParticleEmitter;
        return empty, false;
    }
}

#scope_file

load_particle_emitters_glb :: (file: string) -> [..] ParticleEmitter, bool {
    json, binary, json_memory, valid := load_glb(file);
    defer free(json_memory);
    if !valid {
        empty: [..] ParticleEmitter;
        return empty, false;
    }

    emitters, data_success := load_particle_emitters_gltf_data(json);
    return emitters, data_success;
}

load_particle_emitters_gltf :: (file: string, path: string) -> [..] ParticleEmitter, bool {
    json, binary, json_memory, valid := load_gltf(file, path);
    defer free(json_memory);
    if !valid {
        empty: [..] ParticleEmitter;
        return empty, false;
    }

    emitters, data_success := load_particle_emitters_gltf_data(json);
    return emitters, data_success;
}

// assumes that the extra property of "shadow" will mark the shadow value
load_particle_emitters_gltf_data :: (json: GltfJson) -> [..] ParticleEmitter, bool {
    emitters: [..] ParticleEmitter;

    for node: json.nodes {
        if node.extras && get(node.extras, "particle") {
            particle_type := get(node.extras, "particle");
            assert(particle_type.type == .String, "Unknown particle extra type.\n");

            position: Vector3;
            position.component = node.translation;

            array_add(*emitters, ParticleEmitter.{
                position = position,
                type = copy_string(particle_type.str),
            });
        }
    }

    return emitters, true;
}
