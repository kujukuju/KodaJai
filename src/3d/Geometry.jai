Geometry :: struct {
    vao_: GLuint;
    vbo_: GLuint;
    ebo_: GLuint;

    name: string;
    vertices: [..] float32;
    indices: [..] u32;
    aabb: AABB3;
    has_normal: bool; // TODO these should be enums I guess for #complete
    has_texcoord: bool;
    has_color: bool;
}

SerializedGeometryHash :: struct {
    modtime: S128;
    size: s64;
}

SerializedGeometry :: struct {
    validity_hash: SerializedGeometryHash;
    geometry: [..] *Geometry;
}

load_or_save_serialized_geometry :: (serialized_path: string, path: string) -> [..] *Geometry, bool {
    cache_modtime, cache_size, cache_data_read_success := file_modtime_and_size(path);
    if !cache_data_read_success {
        empty: [..] *Geometry;
        return empty, false;
    }

    file, success := read_entire_file(serialized_path, log_errors = false);
    defer free(file);

    if success {
        view: [] u8;
        view.data = file.data;
        view.count = file.count;
        
        hash := deserialize_geometry_hash(view);
        if hash.modtime == cache_modtime || hash.size == cache_size {
            print("Skipping file read. Reading serialized.\n");

            return deserialize_geometry(view), true;
        }
    }

    print("Reading raw files. Not serialized.\n");

    // if you've made it to this point, the serialized file is no longer valid for some reason
    geometry, geometry_success := load_geometry(path);
    if !geometry_success {
        print("Could not load files.\n%\n%\n", serialized_path, path);
        empty: [..] *Geometry;
        return empty, false;
    }

    serialized: SerializedGeometry;
    serialized.validity_hash.modtime = cache_modtime;
    serialized.validity_hash.size = cache_size;
    serialized.geometry = geometry;

    bytes := serialize_geometry(serialized);
    defer array_free(bytes);

    write_entire_file(serialized_path, bytes.data, bytes.count);

    return geometry, true;
}

load_serialized_geometry :: (path: string) -> [..] *Geometry, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        empty: [..] *Geometry;
        return empty, false;
    }

    view: [] u8;
    view.data = file.data;
    view.count = file.count;

    return deserialize_geometry(view), true;
}

load_geometry :: (path: string) -> [..] *Geometry, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        empty: [..] *Geometry;
        return empty, false;
    }

    if ends_with(path, ".obj") {
        geometries, success := load_geometry_obj(file);
        if !success {
            empty: [..] *Geometry;
            return empty, false;
        }

        return geometries, true;
    } else if ends_with(path, ".glb") {
        geometries, success := load_geometry_glb(file);
        if !success {
            empty: [..] *Geometry;
            return empty, false;
        }

        return geometries, true;
    } else if ends_with(path, ".gltf") {
        geometries, success := load_geometry_gltf(file, path);
        if !success {
            empty: [..] *Geometry;
            return empty, false;
        }

        return geometries, true;
    } else {
        print("Unknown file type. %\n", path);
        empty: [..] *Geometry;
        return empty, false;
    }
}

deserialize_geometry_hash :: (bytes: [] u8) -> SerializedGeometryHash {
    hash: SerializedGeometryHash;

    index: int;
    serializer.read(bytes, *index, *hash);

    return hash;
}

deserialize_geometry :: (bytes: [] u8) -> [..] *Geometry {
    serialized: SerializedGeometry;

    index: int;
    serializer.read(bytes, *index, *serialized);

    for geometry: serialized.geometry {
        gen_geometry(geometry);
    }

    return serialized.geometry;
}

serialize_geometry :: (geometry: SerializedGeometry) -> [..] u8 {
    bytes: [..] u8;
    serializer.write(*bytes, geometry);

    return bytes;
}

destroy :: (geometry: *Geometry) {
    glDeleteBuffers(1, *geometry.ebo_);
    glDeleteBuffers(1, *geometry.vbo_);
    glDeleteVertexArrays(1, *geometry.vao_);

    free(geometry.name);
    array_free(geometry.vertices);
    array_free(geometry.indices);
    free(geometry);
}

get_indices :: (geometry: Geometry) -> [..] int {
    indices: [..] int;
    array_reserve(*indices, geometry.indices.count);

    for index: geometry.indices {
        array_add(*indices, xx index);
    }

    return indices;
}

get_vertices :: (geometry: Geometry, preserve_faces: bool = false) -> [..] Vector3 {
    vertices: [..] Vector3;

    stride := 3;
    if geometry.has_normal {
        stride += 3;
    }
    if geometry.has_texcoord {
        stride += 2;
    }
    if geometry.has_color {
        stride += 4;
    }

    if preserve_faces {
        array_reserve(*vertices, geometry.indices.count);
    } else {
        array_reserve(*vertices, geometry.vertices.count / stride);
    }

    if preserve_faces {
        for geometry.indices {
            x := geometry.vertices[it * stride];
            y := geometry.vertices[it * stride + 1];
            z := geometry.vertices[it * stride + 2];

            array_add(*vertices, .{x, y, z});
        }
    } else {
        i := 0;
        while i < geometry.vertices.count {
            defer i += stride;

            x := geometry.vertices[i];
            y := geometry.vertices[i + 1];
            z := geometry.vertices[i + 2];

            array_add(*vertices, .{x, y, z});
        }
    }

    return vertices;
}

#scope_module

load_geometry_obj :: (file: string) -> [..] *Geometry, bool {
    // returns the index of the newline
    get_until_newline :: (file: string, index: int) -> int, string {
        current: string;
        current.data = file.data + index;
        initial_index := index;
        while index < file.count && file[index] != #char "\n" {
            index += 1;
        }

        current.count = index - initial_index;

        return index, current;
    }

    get_until_space_or_newline :: (file: string, index: int) -> int, string {
        current: string;
        current.data = file.data + index;
        initial_index := index;
        while index < file.count && file[index] != #char " " && file[index] != #char "\n" {
            index += 1;
        }

        current.count = index - initial_index;

        return index, current;
    }

    get_until_slash :: (file: string, index: int) -> int, string {
        current: string;
        current.data = file.data + index;
        initial_index := index;
        while index < file.count && file[index] != #char "/" {
            index += 1;
        }

        current.count = index - initial_index;

        return index, current;
    }

    vertices: [..] Vector3;
    texcoords: [..] Vector2;
    normals: [..] Vector3;

    defer array_free(vertices);
    defer array_free(texcoords);
    defer array_free(normals);

    vertex_offset: int;
    texcoord_offset: int;
    normal_offset: int;

    geometries: [..] *Geometry;
    geometry: *Geometry;

    set_aabb := false;

    index := 0;
    while index < file.count {
        if index + 1 < file.count && file[index] == #char "o" && file[index + 1] == #char " " {
            geometry = New(Geometry);
            array_add(*geometries, geometry);

            set_aabb = false;

            vertex_offset += vertices.count;
            texcoord_offset += texcoords.count;
            normal_offset += normals.count;

            vertices.count = 0;
            texcoords.count = 0;
            normals.count = 0;

            temp_name: string;
            index, temp_name = get_until_newline(file, index + 2);
            geometry.name = copy_string(temp_name);
        } else if index + 1 < file.count && file[index] == #char "v" && file[index + 1] == #char " " {
            x_string: string;
            y_string: string;
            z_string: string;

            index, x_string = get_until_space_or_newline(file, index + 2);
            index, y_string = get_until_space_or_newline(file, index + 1);
            index, z_string = get_until_space_or_newline(file, index + 1);

            x_value := string_to_float(x_string);
            y_value := string_to_float(y_string);
            z_value := string_to_float(z_string);

            array_add(*vertices, .{x_value, y_value, z_value});
        } else if index + 2 < file.count && file[index] == #char "v" && file[index + 1] == #char "t" && file[index + 2] == #char " " {
            x_string: string;
            y_string: string;

            index, x_string = get_until_space_or_newline(file, index + 3);
            index, y_string = get_until_space_or_newline(file, index + 1);

            x_value := string_to_float(x_string);
            y_value := string_to_float(y_string);

            array_add(*texcoords, .{x_value, y_value});
        } else if index + 2 < file.count && file[index] == #char "v" && file[index + 1] == #char "n" && file[index + 2] == #char " " {
            x_string: string;
            y_string: string;
            z_string: string;

            index, x_string = get_until_space_or_newline(file, index + 3);
            index, y_string = get_until_space_or_newline(file, index + 1);
            index, z_string = get_until_space_or_newline(file, index + 1);

            x_value := string_to_float(x_string);
            y_value := string_to_float(y_string);
            z_value := string_to_float(z_string);

            array_add(*normals, .{x_value, y_value, z_value});
        } else if index + 1 < file.count && file[index] == #char "f" && file[index + 1] == #char " " {
            v1_string: string;
            vn1_string: string;
            vt1_string: string;

            v2_string: string;
            vn2_string: string;
            vt2_string: string;

            v3_string: string;
            vn3_string: string;
            vt3_string: string;

            index, v1_string = get_until_slash(file, index + 2);
            index, vt1_string = get_until_slash(file, index + 1);
            index, vn1_string = get_until_space_or_newline(file, index + 1);

            index, v2_string = get_until_slash(file, index + 1);
            index, vt2_string = get_until_slash(file, index + 1);
            index, vn2_string = get_until_space_or_newline(file, index + 1);

            index, v3_string = get_until_slash(file, index + 1);
            index, vt3_string = get_until_slash(file, index + 1);
            index, vn3_string = get_until_space_or_newline(file, index + 1);

            stride := 3;
            if normals.count > 0 {
                stride += 3;
            }
            if texcoords.count > 0 {
                stride += 2;
            }

            vert_index := cast(u32) (geometry.vertices.count / stride);
            array_add(*geometry.indices, vert_index, vert_index + 1, vert_index + 2);

            v1_value := string_to_int(v1_string);
            array_add(*geometry.vertices, ..vertices[v1_value - vertex_offset - 1].component);
            if normals.count > 0 {
                vn1_value := string_to_int(vn1_string);
                array_add(*geometry.vertices, ..normals[vn1_value - normal_offset - 1].component);
            }
            if texcoords.count > 0 {
                vt1_value := string_to_int(vt1_string);
                array_add(*geometry.vertices, ..texcoords[vt1_value - texcoord_offset - 1].component);
            }

            v2_value := string_to_int(v2_string);
            array_add(*geometry.vertices, ..vertices[v2_value - vertex_offset - 1].component);
            if normals.count > 0 {
                vn2_value := string_to_int(vn2_string);
                array_add(*geometry.vertices, ..normals[vn2_value - normal_offset - 1].component);
            }
            if texcoords.count > 0 {
                vt2_value := string_to_int(vt2_string);
                array_add(*geometry.vertices, ..texcoords[vt2_value - texcoord_offset - 1].component);
            }

            v3_value := string_to_int(v3_string);
            array_add(*geometry.vertices, ..vertices[v3_value - vertex_offset - 1].component);
            if normals.count > 0 {
                vn3_value := string_to_int(vn3_string);
                array_add(*geometry.vertices, ..normals[vn3_value - normal_offset - 1].component);
            }
            if texcoords.count > 0 {
                vt3_value := string_to_int(vt3_string);
                array_add(*geometry.vertices, ..texcoords[vt3_value - texcoord_offset - 1].component);
            }

            if !set_aabb {
                set_aabb = true;
                geometry.aabb.lower = vertices[v1_value - vertex_offset - 1];
                geometry.aabb.upper = vertices[v1_value - vertex_offset - 1];
                geometry.aabb.lower = min(geometry.aabb.lower, vertices[v2_value - vertex_offset - 1]);
                geometry.aabb.upper = max(geometry.aabb.upper, vertices[v2_value - vertex_offset - 1]);
                geometry.aabb.lower = min(geometry.aabb.lower, vertices[v3_value - vertex_offset - 1]);
                geometry.aabb.upper = max(geometry.aabb.upper, vertices[v3_value - vertex_offset - 1]);
            } else {
                geometry.aabb.lower = min(geometry.aabb.lower, vertices[v1_value - vertex_offset - 1]);
                geometry.aabb.upper = max(geometry.aabb.upper, vertices[v1_value - vertex_offset - 1]);
                geometry.aabb.lower = min(geometry.aabb.lower, vertices[v2_value - vertex_offset - 1]);
                geometry.aabb.upper = max(geometry.aabb.upper, vertices[v2_value - vertex_offset - 1]);
                geometry.aabb.lower = min(geometry.aabb.lower, vertices[v3_value - vertex_offset - 1]);
                geometry.aabb.upper = max(geometry.aabb.upper, vertices[v3_value - vertex_offset - 1]);
            }
        }

        // skip to next newline
        while index < file.count && file[index] != #char "\n" {
            index += 1;
        }

        // move actually to the next line
        if index < file.count && file[index] == #char "\n" {
            index += 1;
        }
    }

    for geometry: geometries {
        geometry.has_normal = normals.count > 0;
        geometry.has_texcoord = texcoords.count > 0;
    }

    if geometries.count == 0 {
        return geometries, false;
    }

    for geometry: geometries {
        gen_geometry(geometry);
    }

    return geometries, true;
}

load_geometry_glb :: (file: string) -> [..] *Geometry, bool {
    json, binary, json_memory, valid := load_glb(file);
    defer free(json_memory);
    if !valid {
        empty: [..] *Geometry;
        return empty, false;
    }

    geometries, data_success := load_geometry_gltf_data(json, binary);
    return geometries, data_success;
}

load_geometry_gltf :: (file: string, path: string) -> [..] *Geometry, bool {
    json, binary, json_memory, valid := load_gltf(file, path);
    defer free(json_memory);
    if !valid {
        empty: [..] *Geometry;
        return empty, false;
    }

    geometries, data_success := load_geometry_gltf_data(json, binary);
    return geometries, data_success;
}

load_geometry_gltf_data :: (json: GltfJson, binary: [] u8) -> [..] *Geometry, bool {
    // im going to choose to load all this data as a single geometry but I feel like that's wrong
    geometries: [..] *Geometry;

    buffers: [..] [] u8;
    defer array_free(buffers);
    offset := 0;
    for buffer: json.buffers {
        current := array_add(*buffers);
        current.data = binary.data + offset;
        current.count = buffer.byteLength;

        offset += buffer.byteLength;
    }

    bufferviews: [..] [] u8;
    defer array_free(bufferviews);
    for bufferview: json.bufferViews {
        buffer_index := bufferview.buffer;

        current := array_add(*bufferviews);
        current.data = buffers[buffer_index].data + bufferview.byteOffset;
        current.count = bufferview.byteLength;
    }

    AccessorInfo :: struct {
        view: [] u8;
        type: string;
        component_type: GltfJson.GltfJsonAccessor.GltfJsonComponentType;
        min: [] float;
        max: [] float;
    }
    accessors: [..] AccessorInfo;
    defer array_free(accessors);
    for accessor: json.accessors {
        assert(!accessor.sparse, "The GLTF loader does not yet support sparse buffers.");

        if !accessor.bufferView {
            continue;
        }

        current := array_add(*accessors);
        current.type = accessor.type;
        current.component_type = accessor.componentType;
        current.view.data = bufferviews[<< accessor.bufferView].data + accessor.byteOffset;

        if accessor.type == "SCALAR" {
            current.view.count = accessor.count * get_gltf_stride(current.component_type);
        } else if accessor.type == "VEC2" {
            current.view.count = accessor.count * get_gltf_stride(current.component_type) * 2;
        } else if accessor.type == "VEC3" {
            current.view.count = accessor.count * get_gltf_stride(current.component_type) * 3;
        } else if accessor.type == "VEC4" {
            current.view.count = accessor.count * get_gltf_stride(current.component_type) * 4;
        } else if accessor.type == "MAT4" {
            current.view.count = accessor.count * get_gltf_stride(current.component_type) * 16;
        } else {
            print("Cannot process this accessor type. %\n", accessor.type);
            assert(false, "Cannot process this accessor type.");
        }

        if accessor.min {
            current.min = << accessor.min;
        }
        if accessor.max {
            current.max = << accessor.max;
        }
    }

    for mesh: json.meshes {
        for primitive: mesh.primitives {
            if !is_valid_primitive(primitive) {
                continue;
            }
            
            position_accessor_object := primitive.attributes["POSITION"];

            geometry := New(Geometry);
            array_add(*geometries, geometry);

            assert(position_accessor_object.type == .Integer, "The position accessor type must be an integer.");
            position_accessor_index := position_accessor_object.integer;
            index_accessor_index := << primitive.indices;

            normal_accessor_generic := primitive.attributes["NORMAL"];
            assert(!normal_accessor_generic || normal_accessor_generic.type == .Integer, "If there is a normal accessor the type must be an integer.");
            texcoord_accessor_generic := primitive.attributes["TEXCOORD_0"];
            assert(!texcoord_accessor_generic || texcoord_accessor_generic.type == .Integer, "If there is a texcoord accessor the type must be an integer.");
            color_accessor_generic := primitive.attributes["COLOR_0"];
            assert(!color_accessor_generic || color_accessor_generic.type == .Integer, "If there is a color accessor the type must be an integer.");

            has_normal := !!normal_accessor_generic;
            has_texcoord := !!texcoord_accessor_generic;
            has_color := !!color_accessor_generic;

            geometry.has_normal = has_normal;
            geometry.has_texcoord = has_texcoord;
            geometry.has_color = has_color;

            index_accessor := accessors[index_accessor_index];
            assert(index_accessor.type == "SCALAR", "The indices access must be a scalar type.");
            index_type := index_accessor.component_type;

            // holy shit there has to be a better way to do this without writing a complex #insert thing
            if #complete index_type == {
                case .S8;
                    index_count := index_accessor.view.count;
                    array_reserve(*geometry.indices, index_count);
                    index_data := cast(*s8) index_accessor.view.data;
                    for 0..index_count - 1 {
                        index := cast(u32) << (index_data + it);
                        array_add(*geometry.indices, index);
                    }

                case .U8;
                    index_count := index_accessor.view.count;
                    array_reserve(*geometry.indices, index_count);
                    index_data := cast(*u8) index_accessor.view.data;
                    for 0..index_count - 1 {
                        index := cast(u32) << (index_data + it);
                        array_add(*geometry.indices, index);
                    }

                case .S16;
                    index_count := index_accessor.view.count / size_of(s16);
                    array_reserve(*geometry.indices, index_count);
                    index_data := cast(*s16) index_accessor.view.data;
                    for 0..index_count - 1 {
                        index := cast(u32) << (index_data + it);
                        array_add(*geometry.indices, index);
                    }

                case .U16;
                    index_count := index_accessor.view.count / size_of(u16);
                    array_reserve(*geometry.indices, index_count);
                    index_data := cast(*u16) index_accessor.view.data;
                    for 0..index_count - 1 {
                        index := cast(u32) << (index_data + it);
                        array_add(*geometry.indices, index);
                    }

                case .U32;
                    index_count := index_accessor.view.count / size_of(u32);
                    array_reserve(*geometry.indices, index_count);
                    index_data := cast(*u32) index_accessor.view.data;
                    for 0..index_count - 1 {
                        index := cast(u32) << (index_data + it);
                        array_add(*geometry.indices, index);
                    }

                case .F32;
                    assert(false, "Invalid index component type.");
            }

            position_accessor := accessors[position_accessor_index];
            assert(position_accessor.type == "VEC3", "The position access must be a vec3 type.");
            assert(position_accessor.component_type == .F32, "The position component type must be float32.");
            memcpy(*geometry.aabb.lower, position_accessor.min.data, size_of(type_of(geometry.aabb.lower)));
            memcpy(*geometry.aabb.upper, position_accessor.max.data, size_of(type_of(geometry.aabb.upper)));

            vertex_count := position_accessor.view.count / size_of(float32) / 3;

            position_data := cast(*float32) position_accessor.view.data;
            normal_data: *float32;
            texcoord_data: *float32;
            color_data: *float32;

            reserve_count := geometry.vertices.count;
            reserve_count += vertex_count * 3;
            if has_normal {
                normal_accessor := accessors[normal_accessor_generic.integer];
                assert(normal_accessor.type == "VEC3", "The normal access must be a vec3 type.");
                assert(normal_accessor.view.count / size_of(float32) / 3 == vertex_count, "There must be as many normals as vertices.");
                assert(normal_accessor.component_type == .F32, "The normal component type must be float32.");
                reserve_count += vertex_count * 3;

                normal_data = cast(*float32) normal_accessor.view.data;
            }
            if has_texcoord {
                texcoord_accessor := accessors[texcoord_accessor_generic.integer];
                assert(texcoord_accessor.type == "VEC2", "The texcoord access must be a vec2 type.");
                assert(texcoord_accessor.view.count / size_of(float32) / 2 == vertex_count, "There must be as many texcoords as vertices.");
                assert(texcoord_accessor.component_type == .F32, "The texcoord component type must be float32.");
                reserve_count += vertex_count * 2;
                
                texcoord_data = cast(*float32) texcoord_accessor.view.data;
            }
            if has_color {
                color_accessor := accessors[color_accessor_generic.integer];
                assert(color_accessor.type == "VEC4", "The color access must be a vec4 type.");
                assert(color_accessor.view.count / size_of(float32) / 4 == vertex_count, "There must be as many colors as vertices.");
                assert(color_accessor.component_type == .F32, "The color component type must be float32.");
                reserve_count += vertex_count * 4;
                
                color_data = cast(*float32) color_accessor.view.data;
            }

            array_reserve(*geometry.vertices, reserve_count);

            for i: 0..vertex_count - 1 {
                array_add(*geometry.vertices, position_data[i * 3]);
                array_add(*geometry.vertices, position_data[i * 3 + 1]);
                array_add(*geometry.vertices, position_data[i * 3 + 2]);

                if has_normal {
                    array_add(*geometry.vertices, normal_data[i * 3]);
                    array_add(*geometry.vertices, normal_data[i * 3 + 1]);
                    array_add(*geometry.vertices, normal_data[i * 3 + 2]);
                }

                if has_texcoord {
                    array_add(*geometry.vertices, texcoord_data[i * 2]);
                    array_add(*geometry.vertices, texcoord_data[i * 2 + 1]);
                }

                if has_color {
                    array_add(*geometry.vertices, color_data[i * 4]);
                    array_add(*geometry.vertices, color_data[i * 4 + 1]);
                    array_add(*geometry.vertices, color_data[i * 4 + 2]);
                    array_add(*geometry.vertices, color_data[i * 4 + 3]);
                }
            }
        }
    }

    for geometry: geometries {
        gen_geometry(geometry);
    }

    return geometries, true;
}

gen_geometry :: (geometry: *Geometry) {
    glGenVertexArrays(1, *geometry.vao_);
    glGenBuffers(1, *geometry.vbo_);
    glGenBuffers(1, *geometry.ebo_);

    glBindVertexArray(geometry.vao_);

    glBindBuffer(GL_ARRAY_BUFFER, geometry.vbo_);
    glBufferData(GL_ARRAY_BUFFER, geometry.vertices.count * size_of(float32), geometry.vertices.data, GL_STATIC_DRAW);  

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, geometry.ebo_);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, geometry.indices.count * size_of(u32), geometry.indices.data, GL_STATIC_DRAW);

    total_float_size: u32 = 3;
    if geometry.has_normal {
        total_float_size += 3;
    }
    if geometry.has_texcoord {
        total_float_size += 2;
    }
    if geometry.has_color {
        total_float_size += 4;
    }

    current_attribute: u32;
    float_offset: u32;

    // vertex positions
    glEnableVertexAttribArray(current_attribute);
    glVertexAttribPointer(current_attribute, 3, GL_FLOAT, GL_FALSE, size_of(float32) * total_float_size, cast(*void) float_offset);
    current_attribute += 1;
    float_offset += 3;

    // print("n t c % % %\n", geometry.has_normal, geometry.has_texcoord, geometry.has_color);

    if geometry.has_normal {
        // vertex normals
        glEnableVertexAttribArray(current_attribute);
        glVertexAttribPointer(current_attribute, 3, GL_FLOAT, GL_FALSE, size_of(float32) * total_float_size, cast(*void) (size_of(float32) * float_offset));
        current_attribute += 1;
        float_offset += 3;
    }

    if geometry.has_texcoord {
        // vertex texture coords
        glEnableVertexAttribArray(current_attribute);
        glVertexAttribPointer(current_attribute, 2, GL_FLOAT, GL_FALSE, size_of(float32) * total_float_size, cast(*void) (size_of(float32) * float_offset));
        current_attribute += 1;
        float_offset += 2;
    }

    if geometry.has_color {
        // vertex texture coords
        glEnableVertexAttribArray(current_attribute);
        glVertexAttribPointer(current_attribute, 4, GL_FLOAT, GL_FALSE, size_of(float32) * total_float_size, cast(*void) (size_of(float32) * float_offset));
        current_attribute += 1;
        float_offset += 4;
    }

    glBindVertexArray(0);
}
