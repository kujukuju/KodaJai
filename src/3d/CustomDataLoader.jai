
CustomData :: struct {
    name: string;
    position: Vector3;
    rotation: Quaternion;
    scale: Vector3;
    properties: [..] [2] string;
}

destroy :: (custom_data: CustomData) {
    free(custom_data.name);
    for property: custom_data.properties {
        free(property[0]);
        free(property[1]);
    }
    array_free(custom_data.properties);
}

load_custom_data :: (path: string) -> [..] CustomData, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        empty: [..] CustomData;
        return empty, false;
    }

    if ends_with(path, ".glb") {
        data, success := load_custom_data_glb(file);
        if !success {
            empty: [..] CustomData;
            return empty, false;
        }

        return data, true;
    } else if ends_with(path, ".gltf") {
        data, success := load_custom_data_gltf(file, path);
        if !success {
            empty: [..] CustomData;
            return empty, false;
        }

        return data, true;
    } else {
        print("Unknown file type. %\n", path);
        empty: [..] CustomData;
        return empty, false;
    }
}

is_valid_property :: (object: JsonObjectEntry) -> bool {
    if object.name == "hops" || object.name == "zen_uv" {
        return false;
    }
    return true;
}

get_property_entry :: (name: string, object: JsonObjectEntry) -> [2] string {
    property: [2] string;
    property[0] = copy_string(object.name);

    if object.value.type == .String {
        property[1] = copy_string(object.value.str);
    } else if object.value.type == .Boolean {
        property[1] = ifx object.value.boolean then copy_string("true") else copy_string("false");
    } else if object.value.type == .Object {
        found_type: string;
        found_name: string;
        print("% %\n", object.name, object.value.object.count);
        for entry: object.value.object {
            assert(entry.value.type == .String, "Found a custom data entry of type Data that didn't contain a string. % % %\n", name, object.name, entry.value.type);
            if entry.value.type == .String && entry.name == "type" {
                found_type = entry.value.str;
            }
            if entry.value.type == .String && entry.name == "name" {
                found_name = entry.value.str;
            }
        }
        assert(found_type == "Object", "Found a custom data entry of type Data that wasn't for an Object. % %\n", name, found_type);

        property[1] = copy_string(found_name);
    } else if object.value.type == .Integer {
        property[1] = sprint("%", object.value.integer);
    } else if object.value.type == .Float {
        property[1] = sprint("%", formatFloat(object.value.number, trailing_width = 24));
    } else {
        assert(false, "Unknown custom data property type. % % %\n", name, property[0], object.value.type);
        return .["", ""];
    }

    return property;
}

#scope_file

load_custom_data_glb :: (file: string) -> [..] CustomData, bool {
    json, binary, json_memory, valid := load_glb(file);
    defer free(json_memory);
    if !valid {
        empty: [..] CustomData;
        return empty, false;
    }

    data, data_success := load_custom_data_gltf_data(json);
    return data, data_success;
}

load_custom_data_gltf :: (file: string, path: string) -> [..] CustomData, bool {
    json, binary, json_memory, valid := load_gltf(file, path);
    defer free(json_memory);
    if !valid {
        empty: [..] CustomData;
        return empty, false;
    }

    data, data_success := load_custom_data_gltf_data(json);
    return data, data_success;
}

// assumes that the extra property of "shadow" will mark the shadow value
load_custom_data_gltf_data :: (json: GltfJson) -> [..] CustomData, bool {
    custom_data: [..] CustomData;

    for node: json.nodes {
        should_skip := !!node.camera;
        should_skip = should_skip || node.children;
        should_skip = should_skip || node.skin;
        should_skip = should_skip || node.mesh;
        should_skip = should_skip || node.weights;
        should_skip = should_skip || !node.extras;
        should_skip = should_skip || node.extras.type != .Object;

        if should_skip {
            continue;
        }

        data: CustomData;
        data.position.component = node.translation;
        data.rotation.component = node.rotation;
        data.scale.component = node.scale;

        if node.name {
            data.name = copy_string(node.name.*);
        }

        for property: node.extras.object {
            name := ifx node.name then node.name.* else "";
            array_add(*data.properties, get_property_entry(name, property));
        }

        array_add(*custom_data, data);
    }

    return custom_data, true;
}
