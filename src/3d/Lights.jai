
DirectionalLight :: struct {
    dir: Vector3;
    color: Vector3;
    intensity: float;
    shadow: bool;
}

PointLight :: struct {
    position: Vector3;
    color: Vector3;
    intensity: float;
    shadow: bool;
    static: bool;
}

load_lights :: (path: string) -> [..] DirectionalLight, [..] PointLight, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        empty_dirs: [..] DirectionalLight;
        empty_points: [..] PointLight;
        return empty_dirs, empty_points, false;
    }

    if ends_with(path, ".glb") {
        dirs, points, success := load_lights_glb(file);
        if !success {
            empty_dirs: [..] DirectionalLight;
            empty_points: [..] PointLight;
            return empty_dirs, empty_points, false;
        }

        return dirs, points, true;
    } else if ends_with(path, ".gltf") {
        dirs, points, success := load_lights_gltf(file, path);
        if !success {
            empty_dirs: [..] DirectionalLight;
            empty_points: [..] PointLight;
            return empty_dirs, empty_points, false;
        }

        return dirs, points, true;
    } else {
        print("Unknown file type. %\n", path);
        empty_dirs: [..] DirectionalLight;
        empty_points: [..] PointLight;
        return empty_dirs, empty_points, false;
    }
}

#scope_file

load_lights_glb :: (file: string) -> [..] DirectionalLight, [..] PointLight, bool {
    json, binary, json_memory, valid := load_glb(file);
    defer free(json_memory);
    if !valid {
        empty_dirs: [..] DirectionalLight;
        empty_points: [..] PointLight;
        return empty_dirs, empty_points, false;
    }

    dirs, points, data_success := load_lights_gltf_data(json);
    return dirs, points, data_success;
}

load_lights_gltf :: (file: string, path: string) -> [..] DirectionalLight, [..] PointLight, bool {
    json, binary, json_memory, valid := load_gltf(file, path);
    defer free(json_memory);
    if !valid {
        empty_dirs: [..] DirectionalLight;
        empty_points: [..] PointLight;
        return empty_dirs, empty_points, false;
    }

    dirs, points, data_success := load_lights_gltf_data(json);
    return dirs, points, data_success;
}

// assumes that the extra property of "shadow" will mark the shadow value
load_lights_gltf_data :: (json: GltfJson) -> [..] DirectionalLight, [..] PointLight, bool {
    dirs: [..] DirectionalLight;
    points: [..] PointLight;

    lights: [] GltfJson.GltfJsonExtensions.GltfJsonLights.GltfJsonLight;
    if json.extensions && json.extensions.KHR_lights_punctual {
        lights = json.extensions.KHR_lights_punctual.lights;
    } else {
        print("no extension\n");
        return dirs, points, false; 
    }

    for node: json.nodes {
        if node.extensions && node.extensions.KHR_lights_punctual {
            light_index := node.extensions.KHR_lights_punctual.light;
            assert(light_index < lights.count, "Found index for light that doesn't exist.\n");

            translation: Vector3;
            translation.component = node.translation;
            rotation: Quaternion;
            rotation.component = node.rotation;
            scaled: Vector3;
            scaled.component = node.scale;

            light := lights[light_index];
            color: Vector3;
            color.component = light.color;
            intensity := light.intensity;
            shadow := false;
            static := false;

            if light.extras {
                assert(light.extras.type == .Object);

                light_shadow := get(light.extras, "shadow");
                if light_shadow {
                    assert(light_shadow.type == .Boolean);
                    shadow = light_shadow.boolean;
                }

                light_static := get(light.extras, "static");
                if light_static {
                    assert(light_static.type == .Boolean);
                    static = light_static.boolean;
                }
            }

            if light.type == {
                case "directional";
                    transform := make_translation_matrix4(translation);
                    transform = rotate(transform, rotation);
                    transform = scale(transform, scaled);
                    transform = transpose(inverse(transform));

                    directional := DirectionalLight.{
                        dir = normalize(transform_vector(transform, .{0, 0, -1})),
                        color = color,
                        intensity = intensity,
                        shadow = shadow,
                    };
                    array_add(*dirs, directional);

                case "point";
                    point := PointLight.{
                        position = translation,
                        color = color,
                        intensity = intensity,
                        shadow = shadow,
                        static = static,
                    };
                    array_add(*points, point);
                case;
                    light_name := ifx node.name then node.name.* else "";
                    assert(false, tprint("Found unknown type of light. % %\n", light.type, light_name));
            }
        }
    }

    return dirs, points, true;
}
