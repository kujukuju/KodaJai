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

load_or_save_serialized_geometry :: (serialized_path: string, path: string) -> [..] *Geometry, bool {
    file, success := read_entire_file(serialized_path, log_errors = false);
    defer free(file);
    if !success {
        geometry, success := load_geometry(path);
        if !success {
            print("Could not load files.\n%\n%\n", serialized_path, path);
            empty: [..] *Geometry;
            return empty, false;
        }

        bytes := serialize_geometry(geometry);
        write_entire_file(serialized_path, bytes.data, bytes.count);

        return geometry, true;
    }

    view: [] u8;
    view.data = file.data;
    view.count = file.count;

    return deserialized_geometry(view), true;
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

    return deserialized_geometry(view), true;
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

deserialized_geometry :: (bytes: [] u8) -> [..] *Geometry {
    geometry: [..] *Geometry;

    index: int;
    serializer.read(bytes, *index, *geometry);

    for geo: geometry {
        gen_geometry(geo);
    }

    return geometry;
}

serialize_geometry :: (geometry: [..] *Geometry) -> [..] u8 {
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

// bad bad bad
load_geometry_obj :: (file: string) -> [..] *Geometry, bool {
    object_sections := split(file, "o ");
    // assert(object_sections.count == 2, "Cannot have more than 1 object.");

    // TODO need to fix obj to match the new geometry struct of potentially not having texcoords or normals

    vertices: [..] Vector3;
    normals: [..] Vector3;
    texture_coords: [..] Vector2;

    defer array_free(vertices);
    defer array_free(normals);
    defer array_free(texture_coords);

    set_aabb := false;

    // TODO
    geometry := New(Geometry);
    geometry.has_normal = true;
    geometry.has_texcoord = true;
    // TODO
    // geometry.has_color = true;

    vertex_offset := 0;
    normal_offset := 0;
    texture_coord_offset := 0;

    for index: 1..object_sections.count - 1 {
        object_section := object_sections[index];

        vertex_offset += vertices.count;
        normal_offset += normals.count;
        texture_coord_offset += texture_coords.count;

        vertices.count = 0;
        normals.count = 0;
        texture_coords.count = 0;

        lines := split(object_section, "\n");
        for line, index: lines {
            if index == 0 {
                geometry.name = copy_string(line);
            } else if starts_with(line, "v ") {
                subline := slice(line, 2, line.count - 2);

                vertex := split(subline, " ");
                x := string_to_float(vertex[0]);
                y := string_to_float(vertex[1]);
                z := string_to_float(vertex[2]);

                array_add(*vertices, .{x, y, z});
            } else if starts_with(line, "vt ") {
                subline := slice(line, 3, line.count - 3);

                texture_coord := split(subline, " ");
                x := string_to_float(texture_coord[0]);
                y := 1.0 - string_to_float(texture_coord[1]);

                array_add(*texture_coords, .{x, y});
            } else if starts_with(line, "vn ") {
                subline := slice(line, 3, line.count - 3);

                normal := split(subline, " ");
                x := string_to_float(normal[0]);
                y := string_to_float(normal[1]);
                z := string_to_float(normal[2]);

                array_add(*normals, .{x, y, z});
            } else if starts_with(line, "f ") {
                subline := slice(line, 2, line.count - 2);

                faces_chunks := split(subline, " ");
                assert(faces_chunks.count == 3, "Must be triangularized.");

                for faces_chunk: faces_chunks {
                    face_info := split(faces_chunk, "/");

                    // TODO fix normal and texcoords
                    vertex_stride := 8;
                    array_add(*geometry.indices, cast(u32) (geometry.vertices.count / vertex_stride));

                    // array_add(*geometry.vertices, ..vertices[string_to_int(face_info[0]) - vertex_offset - 1].component);
                    position := vertices[string_to_int(face_info[0]) - vertex_offset - 1];
                    array_add(*geometry.vertices, position.x);
                    array_add(*geometry.vertices, position.y);
                    array_add(*geometry.vertices, position.z);

                    if !set_aabb {
                        set_aabb = true;
                        geometry.aabb.lower = position;
                        geometry.aabb.upper = position;
                    } else {
                        geometry.aabb.lower = min(geometry.aabb.lower, position);
                        geometry.aabb.upper = max(geometry.aabb.upper, position);
                    }

                    if normals.count > 0 {
                        // array_add(*geometry.vertices, ..normals[string_to_int(face_info[2]) - normal_offset - 1].component);
                        normal := normals[string_to_int(face_info[2]) - normal_offset - 1];
                        array_add(*geometry.vertices, normal.x);
                        array_add(*geometry.vertices, normal.y);
                        array_add(*geometry.vertices, normal.z);
                    } else {
                        array_add(*geometry.vertices, 0, 0, 0);
                    }

                    if texture_coords.count > 0 {
                        // array_add(*geometry.vertices, ..texture_coords[string_to_int(face_info[1]) - texture_coord_offset - 1].component);
                        texcoord := texture_coords[string_to_int(face_info[1]) - texture_coord_offset - 1];
                        array_add(*geometry.vertices, texcoord.x);
                        array_add(*geometry.vertices, texcoord.y);
                    } else {
                        array_add(*geometry.vertices, 0, 0);
                    }
                }
            }
        }
    }

    gen_geometry(geometry);

    list: [..] *Geometry;
    array_resize(*list, 1);
    list[0] = geometry;

    return list, true;
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
                print("% %\n", color_accessor.view.count / size_of(float32) / 4, vertex_count);
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
