Geometry :: struct {
    vao_: GLuint;
    vbo_: GLuint;
    ebo_: GLuint;

    vertices: [..] float32;
    indices: [..] u32;
    attributes: [..] Attribute;
    aabb: AABB3;
}

// this is also the alignment order that the loader will force the attributes into
Attribute :: enum {
    Position;
    Normal;
    Texcoord;
    Texcoord3;
    Color;
    JointIndices;
    JointWeights;
    Float;
}

SerializedGeometryHash :: struct {
    hash: u32;
    size: s64;
}

SerializedGeometry :: struct {
    validity_hash: SerializedGeometryHash;
    geometry: [..] *Geometry;
}

create_geometry :: (vertices: [] float32, indices: [] u32, attributes: [] Attribute, should_upload: bool = true) -> *Geometry {
    for i: 1..attributes.count - 1 {
        assert(attributes[i] >= attributes[i - 1], "Cannot create geometry with misordered attributes.");
    }

    geometry := New(Geometry);

    array_copy(*geometry.vertices, vertices);
    array_copy(*geometry.indices, indices);
    array_copy(*geometry.attributes, attributes);

    geometry.aabb = calculate_aabb(geometry);

    if should_upload {
        upload(geometry);
    }

    return geometry;
}

create_geometries :: (vertices: [] float32, indices: [] u32, attributes: [] Attribute, should_upload: bool = true) -> [..] *Geometry {
    for i: 1..attributes.count - 1 {
        assert(attributes[i] >= attributes[i - 1], "Cannot create geometry with misordered attributes.");
    }

    geometries: [..] *Geometry;
    array_reserve(*geometries, 1);

    array_add(*geometries, create_geometry(vertices, indices, attributes, should_upload));

    return geometries;
}

load_serialized_geometry :: (serialized_path: string, hash_files: [$N] string, fallback: () -> *Geometry, should_upload: bool = true) -> *Geometry, bool {
    geometry := New(Geometry);
    geometry_raw, success := read_serialized(serialized_path, hash_files, Geometry);

    geometry.* = geometry_raw;

    if success {
        geometry.vao_ = 0;
        geometry.vbo_ = 0;
        geometry.ebo_ = 0;

        if should_upload {
            upload(geometry);
        }

        return geometry, true;
    }

    free(geometry);
    geometry = fallback();
    if should_upload {
        upload(geometry);
    }

    write_serialized(serialized_path, hash_files, geometry);
    return geometry, true;
}

load_serialized_geometries :: (serialized_path: string, hash_files: [$N] string, fallback: () -> [..] *Geometry, should_upload: bool = true) -> [..] *Geometry, bool {
    geometries, success := read_serialized(serialized_path, hash_files, [..] *Geometry);

    if success {
        for geometry: geometries {
            geometry.vao_ = 0;
            geometry.vbo_ = 0;
            geometry.ebo_ = 0;
        }

        if should_upload {
            for geometry: geometries {
                upload(geometry);
            }
        }

        return geometries, true;
    }

    geometries = fallback();
    if should_upload {
        for geometry: geometries {
            upload(geometry);
        }
    }

    write_serialized(serialized_path, hash_files, geometries);
    return geometries, true;
}

load_geometry :: (path: string, should_upload: bool = true) -> *Geometry, bool {
    geometries, success := load_geometries(path, should_upload);
    defer array_free(geometries);
    if !success {
        return null, false;
    }

    assert(geometries.count == 1, "You cannot load more than 1 geometry with the load_geometry function. Memory leak!");
    return geometries[0], true;
}

load_geometries :: (path: string, should_upload: bool = true) -> [..] *Geometry, bool {
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

        if should_upload {
            for geometry: geometries {
                upload(geometry);
            }
        }

        return geometries, true;
    } else if ends_with(path, ".glb") {
        geometries, success := load_geometry_glb(file);
        if !success {
            empty: [..] *Geometry;
            return empty, false;
        }

        if should_upload {
            for geometry: geometries {
                upload(geometry);
            }
        }

        return geometries, true;
    } else if ends_with(path, ".gltf") {
        geometries, success := load_geometry_gltf(file, path);
        if !success {
            empty: [..] *Geometry;
            return empty, false;
        }

        if should_upload {
            for geometry: geometries {
                upload(geometry);
            }
        }

        return geometries, true;
    } else {
        print("Unknown file type. %\n", path);
        empty: [..] *Geometry;
        return empty, false;
    }
}

// TODO remove this, if youre directly serializing or deserializing things it shouldnt have anything to do with a hash
deserialize_geometry :: (bytes: [] u8, should_upload: bool = true) -> *Geometry {
    geometry := New(Geometry);

    index: int;
    serializer.read(bytes, *index, geometry);
    geometry.vao_ = 0;
    geometry.vbo_ = 0;
    geometry.ebo_ = 0;

    if should_upload {
        upload(geometry);
    }

    return geometry;
}

serialize_geometry :: (geometry: *Geometry) -> [..] u8 {
    bytes: [..] u8;
    serializer.write(*bytes, geometry.*);

    print("wrote % bytes for geometry.\n", bytes.count);

    return bytes;
}

upload :: (geometry: *Geometry) {
    assert(koda.initialized, "Attempting to gen geometry without the window being initialized.");

    if geometry.vao_ {
        return;
    }

    glGenVertexArrays(1, *geometry.vao_);
    glGenBuffers(1, *geometry.vbo_);
    glGenBuffers(1, *geometry.ebo_);

    glBindVertexArray(geometry.vao_);

    if geometry.vertices.count != geometry.vertices.allocated || geometry.indices.count != geometry.indices.allocated {
        print("Warning: Uploaded a geometry to the gpu with additional allocated buffer space. % > % ... % > %\n", geometry.vertices.allocated, geometry.vertices.count, geometry.indices.allocated, geometry.indices.count);
    }

    glBindBuffer(GL_ARRAY_BUFFER, geometry.vbo_);
    glBufferData(GL_ARRAY_BUFFER, geometry.vertices.allocated * size_of(float32), geometry.vertices.data, GL_DYNAMIC_DRAW);  

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, geometry.ebo_);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, geometry.indices.allocated * size_of(u32), geometry.indices.data, GL_DYNAMIC_DRAW);

    total_float_size := cast(u32) get_attribute_stride(geometry.attributes);

    current_attribute: u32;
    float_offset: s32;

    for attribute: geometry.attributes {
        attribute_size := cast(s32) get_attribute_size(attribute);
        glEnableVertexAttribArray(current_attribute);
        glVertexAttribPointer(current_attribute, attribute_size, GL_FLOAT, GL_FALSE, size_of(float32) * total_float_size, cast(*void) (size_of(float32) * float_offset));

        current_attribute += 1;
        float_offset += attribute_size;
    }

    glBindVertexArray(0);
}

append_data :: (geometry: *Geometry, vertices: [] float32, indices: [] u32) {
    array_add(*geometry.vertices, ..vertices);
    array_add(*geometry.indices, ..indices);

    // TODO glBufferSubData

    upload_append(geometry, vertices.count, indices.count);
}

upload_append :: (geometry: *Geometry, float_count: int, index_count: int) {
    glBindVertexArray(geometry.vao_);

    buffer_size: s32;

    glBindBuffer(GL_ARRAY_BUFFER, geometry.vbo_);
    glGetBufferParameteriv(GL_ARRAY_BUFFER, GL_BUFFER_SIZE, *buffer_size);
    if buffer_size >= geometry.vertices.allocated * size_of(float32) {
        // the data fits inside the currently allocated array, so just sub buffer it
        byte_size := float_count * size_of(float32);
        float_offset := geometry.vertices.count - float_count;
        byte_offset := float_offset * size_of(float32);
        glBufferSubData(GL_ARRAY_BUFFER, byte_offset, byte_size, geometry.vertices.data + float_offset);
    } else {
        glBufferData(GL_ARRAY_BUFFER, geometry.vertices.allocated * size_of(float32), geometry.vertices.data, GL_STATIC_DRAW);  
    }

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, geometry.ebo_);
    glGetBufferParameteriv(GL_ELEMENT_ARRAY_BUFFER, GL_BUFFER_SIZE, *buffer_size);
    if buffer_size >= geometry.indices.allocated * size_of(u32) {
        byte_size := index_count * size_of(u32);
        index_offset := geometry.indices.count - index_count;
        byte_offset := index_offset * size_of(u32);
        glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, byte_offset, byte_size, geometry.indices.data + index_offset);
    } else {
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, geometry.indices.allocated * size_of(u32), geometry.indices.data, GL_STATIC_DRAW);
    }

    glBindVertexArray(0);
}

unload :: (geometry: *Geometry) {
    glDeleteBuffers(1, *geometry.ebo_);
    glDeleteBuffers(1, *geometry.vbo_);
    glDeleteVertexArrays(1, *geometry.vao_);
    
    geometry.ebo_ = 0;
    geometry.vbo_ = 0;
    geometry.vao_ = 0;
}

destroy :: (geometry: *Geometry) {
    glDeleteBuffers(1, *geometry.ebo_);
    glDeleteBuffers(1, *geometry.vbo_);
    glDeleteVertexArrays(1, *geometry.vao_);

    array_free(geometry.vertices);
    array_free(geometry.indices);
    array_free(geometry.attributes);
    free(geometry);
}

// this could be better if it uses the triangles created by the source geometry,
// finds the nearest geometry vertex projection into a triangle,
// and interpolates the vertex data?
// but interpolation doesn't work for indices so that'll have to be lookup-able
copy_nearby_vertex_data :: (geometry: *Geometry, source: Geometry, copy_attributes: [] Attribute) {
    source_tree: BoundingTree(*float) = create_bounding_tree(*float);
    defer free_bounding_tree(source_tree);

    source_stride := get_attribute_stride(source);

    i := 0;
    while i < source.vertices.count {
        source_start: *float = source.vertices.data + i;
        position: Vector3 = (cast(*Vector3) source_start).*;

        position_aabb := AABB3.{position, position};

        create_proxy(*source_tree, position_aabb, source_start);

        i += source_stride;
    }

    copy_stride := 0;
    for source_attribute: source.attributes {
        if array_find(copy_attributes, source_attribute) {
            copy_stride += get_attribute_size(source_attribute);
        }
    }

    old_stride := get_attribute_stride(geometry);
    old_vertex_count := geometry.vertices.count / old_stride;
    new_stride := old_stride + copy_stride;
    new_vertices: [..] float;
    array_resize(*new_vertices, new_stride * old_vertex_count);

    OFFSET :: 0.1;

    i = 0;
    while i < geometry.vertices.count {
        geometry_start: *float = geometry.vertices.data + i;
        geometry_position: Vector3 = (cast(*Vector3) geometry_start).*;

        new_index := i / old_stride * new_stride;
        memcpy(new_vertices.data + new_index, geometry.vertices.data + i, old_stride * size_of(float));

        QueryData :: struct {
            radius: float;
            position: Vector3;
            best_vertex: *Vector3;
        }

        query_data: QueryData;
        query_data.radius = 0;
        query_data.position = geometry_position;

        while !query_data.best_vertex {
            query_data.radius += OFFSET;
            position_aabb := AABB3.{geometry_position - query_data.radius, geometry_position + query_data.radius};

            query(*source_tree, position_aabb, (value: *float, query_data: *QueryData) -> bool {
                source_position: Vector3 = (cast(*Vector3) value).*;

                current_distance := distance(query_data.position, source_position);
                if current_distance <= query_data.radius {
                    if !query_data.best_vertex {
                        query_data.best_vertex = cast(*Vector3) value;
                        return true;
                    }

                    if current_distance < distance(query_data.position, query_data.best_vertex.*) {
                        query_data.best_vertex = cast(*Vector3) value;
                        return true;
                    }
                }

                return true;
            }, *query_data);
        }

        best_vertex_data := cast(*float) query_data.best_vertex;

        geoemtry_current_offset := old_stride;
        source_attribute_offset := 0;
        for source_attribute: source.attributes {
            attribute_size := get_attribute_size(source_attribute);

            if array_find(copy_attributes, source_attribute) {
                memcpy(new_vertices.data + new_index + geoemtry_current_offset, best_vertex_data + source_attribute_offset, attribute_size * size_of(float));
                geoemtry_current_offset += attribute_size;
            }

            source_attribute_offset += attribute_size;
        }

        i += old_stride;
    }

    for source_attribute: source.attributes {
        if array_find(copy_attributes, source_attribute) {
            add_attribute(geometry, source_attribute);
        }
    }

    array_free(geometry.vertices);
    geometry.vertices = new_vertices;
}

rotate_vertices :: (geometry: *Geometry, axis: Vector3, radians: float) {
    transform := rotation_matrix(Matrix4, make_rotation_quaternion(axis, radians));
    stride := get_attribute_stride(geometry);

    for geometry.indices {
        x := geometry.vertices[it * stride];
        y := geometry.vertices[it * stride + 1];
        z := geometry.vertices[it * stride + 2];

        point := transform_point(transform, .{x, y, z});

        geometry.vertices[it * stride] = point.x;
        geometry.vertices[it * stride + 1] = point.y;
        geometry.vertices[it * stride + 2] = point.z;
    }
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

    stride := get_attribute_stride(geometry);

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

get_attribute_stride :: (geometry: Geometry) -> int {
    return get_attribute_stride(geometry.attributes);
}

get_attribute_stride :: (attributes: [] Attribute) -> int {
    stride := 0;
    for attribute: attributes {
        stride += get_attribute_size(attribute);
    }
    return stride;
}

get_attribute_size :: (attribute: Attribute) -> int {
    if #complete attribute == {
        case .Position;
            return 3;
        case .Normal;
            return 3;
        case .Texcoord;
            return 2;
        case .Texcoord3;
            return 3;
        case .Color;
            return 4;
        case .JointIndices;
            return 4;
        case .JointWeights;
            return 4;
        case .Float;
            return 1;
    }
}

add_attribute :: (geometry: *Geometry, attribute: Attribute) {
    attribute_value := cast(int) attribute;

    for i: 0..geometry.attributes.count - 1 {
        current_value := cast(int) geometry.attributes[i];
        if attribute_value <= current_value {
            array_insert_at(*geometry.attributes, attribute, i);
            return;
        }
    }

    array_add(*geometry.attributes, attribute);
}

matches_attributes :: (geometry: Geometry, required: [] Attribute) -> bool {
    return matches_attributes(geometry.attributes, required);
}

matches_attributes :: (attributes: [] Attribute, required: [] Attribute) -> bool {
    if attributes.count != required.count {
        return false;
    }

    for i: 0..attributes.count - 1 {
        if attributes[i] != required[i] {
            return false;
        }
    }

    return true;
}

matches_attributes :: (geometry: Geometry, required: ..Attribute) -> bool {
    return matches_attributes(geometry.attributes, ..required);
}

matches_attributes :: (attributes: [] Attribute, required: ..Attribute) -> bool {
    if attributes.count != required.count {
        return false;
    }

    for i: 0..attributes.count - 1 {
        if attributes[i] != required[i] {
            return false;
        }
    }

    return true;
}

has_attribute :: (geometry: Geometry, attribute: Attribute) -> bool {
    return has_attribute(geometry.attributes, attribute);
}

has_attribute :: (attributes: [] Attribute, attribute: Attribute) -> bool {
    for attrib: attributes {
        if attrib == attribute {
            return true;
        }
    }

    return false;
}

calculate_aabb :: (geometry: Geometry) -> AABB3 {
    set_aabb := false;
    aabb := AABB3.{};
    
    stride := get_attribute_stride(geometry);

    for geometry.indices {
        x := geometry.vertices[it * stride];
        y := geometry.vertices[it * stride + 1];
        z := geometry.vertices[it * stride + 2];

        point := Vector3.{x, y, z};

        if !set_aabb {
            set_aabb = true;
            aabb = .{point, point};
        } else {
            aabb.lower = min(aabb.lower, point);
            aabb.upper = max(aabb.upper, point);
        }
    }

    return aabb;
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

    get_until_slash_exit_space_newline :: (file: string, index: int) -> int, string {
        current: string;
        current.data = file.data + index;
        initial_index := index;
        while index < file.count && file[index] != #char "/" {
            index += 1;

            if file[index] == #char " " || file[index] == #char "\n" {
                current.count = 0;
                return initial_index, current;
            }
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
            // geometry.name = copy_string(temp_name);
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

            index, v1_string = get_until_slash_exit_space_newline(file, index + 2);
            index, vt1_string = get_until_slash_exit_space_newline(file, index + 1);
            index, vn1_string = get_until_space_or_newline(file, index + 1);

            index, v2_string = get_until_slash_exit_space_newline(file, index + 1);
            index, vt2_string = get_until_slash_exit_space_newline(file, index + 1);
            index, vn2_string = get_until_space_or_newline(file, index + 1);

            index, v3_string = get_until_slash_exit_space_newline(file, index + 1);
            index, vt3_string = get_until_slash_exit_space_newline(file, index + 1);
            newline_index := get_until_newline(file, index + 1);
            index, vn3_string = get_until_space_or_newline(file, index + 1);

            assert(newline_index == index, "Found a space where a newline was expected. Probably the obj file isn't triangularized.");

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
        add_attribute(geometry, .Position);
        if normals.count > 0 {
            add_attribute(geometry, .Normal);
        }
        if texcoords.count > 0 {
            add_attribute(geometry, .Texcoord);
        }
    }

    if geometries.count == 0 {
        return geometries, false;
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

    buffers := get_buffers(json, binary);
    defer array_free(buffers);

    bufferviews := get_bufferviews(json, buffers);
    defer array_free(bufferviews);

    accessors := get_accessors(json, bufferviews);
    defer array_free(accessors);

    attribute_type_count :: #run enum_count(Attribute);
    attribute_accessors: [attribute_type_count] [..] GltfAccessorInfo;
    for *accessors: attribute_accessors {
        accessors.allocator = temp;
    }

    for mesh: json.meshes {
        for primitive: mesh.primitives {
            if !is_valid_primitive(primitive) {
                continue;
            }

            assert(primitive.attributes.type == .Object, "The attributes entry must be an object type.");

            geometry := New(Geometry);
            array_add(*geometries, geometry);

            for *accessors: attribute_accessors {
                accessors.count = 0;
            }

            attribute_count := 0;

            for attribute_entry: primitive.attributes.object {
                attribute_entry_generic := attribute_entry.value;
                assert(attribute_entry_generic.type == .Integer, "If there is an attribute accessor entry the type must be an integer.");

                attribute_accessor := accessors[attribute_entry_generic.integer];
                attribute_accessor_count := attribute_accessor.view.count / attribute_accessor.stride;

                if attribute_count == 0 {
                    attribute_count = attribute_accessor_count;
                }

                assert(attribute_count == attribute_accessor_count, "Found an attribute with an inconsistent count.");

                if begins_with(attribute_entry.name, "POSITION") {
                    assert(attribute_accessor.type == "VEC3", "The position accessor must be a vec3 type.");
                    assert(attribute_accessor.component_type == .F32, "The position accessor must be a float32.");

                    array_add(*attribute_accessors[cast(int) Attribute.Position], attribute_accessor);
                    memcpy(*geometry.aabb.lower, attribute_accessor.min.data, size_of(type_of(geometry.aabb.lower)));
                    memcpy(*geometry.aabb.upper, attribute_accessor.max.data, size_of(type_of(geometry.aabb.upper)));
                } else if begins_with(attribute_entry.name, "NORMAL") {
                    assert(attribute_accessor.type == "VEC3", "The normal accessor must be a vec3 type.");
                    assert(attribute_accessor.component_type == .F32, "The normal accessor must be a float32.");

                    array_add(*attribute_accessors[cast(int) Attribute.Normal], attribute_accessor);
                } else if begins_with(attribute_entry.name, "TEXCOORD") {
                    assert(attribute_accessor.type == "VEC2", "The texcoord accessor must be a vec2 type.");
                    assert(attribute_accessor.component_type == .F32, "The texcoord accessor must be a float32.");

                    array_add(*attribute_accessors[cast(int) Attribute.Texcoord], attribute_accessor);
                } else if begins_with(attribute_entry.name, "COLOR") {
                    assert(attribute_accessor.type == "VEC4", "The color accessor must be a vec4 type.");
                    assert(attribute_accessor.component_type == .U8 || attribute_accessor.component_type == .U16 ||attribute_accessor.component_type == .F32, "The color accessor must be a u8 or u16 or float32.");

                    array_add(*attribute_accessors[cast(int) Attribute.Color], attribute_accessor);
                } else if begins_with(attribute_entry.name, "JOINTS") {
                    assert(attribute_accessor.type == "VEC4", "The joint indices accessor must be a vec4 type.");
                    assert(attribute_accessor.component_type == .U8 || attribute_accessor.component_type == .U16 || attribute_accessor.component_type == .U32, "The joint indices accessor must be a u8 or u16 or u32.");

                    array_add(*attribute_accessors[cast(int) Attribute.JointIndices], attribute_accessor);
                } else if begins_with(attribute_entry.name, "WEIGHTS") {
                    assert(attribute_accessor.type == "VEC4", "The joint weights accessor must be a vec4 type.");
                    assert(attribute_accessor.component_type == .F32, "The joint weights accessor must be a float32.");

                    array_add(*attribute_accessors[cast(int) Attribute.JointWeights], attribute_accessor);
                } else {
                    print("Found unknown attribute type. %\n", attribute_entry.name);
                    assert(false, "Found unknown attribute type.");
                }
            }

            vertex_count := 0;

            // flatten the accessor attributes into a single array to represent how the vertices are interlaced
            for accessors, attribute_type_value: attribute_accessors {
                attribute_type := cast(Attribute) attribute_type_value;
                for i: 0..accessors.count - 1 {
                    array_add(*geometry.attributes, attribute_type);

                    if attribute_type == .Position {
                        vertex_count = accessors[i].view.count / accessors[i].stride;
                    }
                }
            }

            if primitive.indices {
                index_accessor_index := << primitive.indices;
                index_accessor := accessors[index_accessor_index];
                assert(index_accessor.type == "SCALAR", "The indices access must be a scalar type.");
                component_type := index_accessor.component_type;
                
                // this seems bad
                if #complete component_type == {
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
            } else {
                array_reserve(*geometry.indices, vertex_count);
                geometry.indices.count = vertex_count;
                for index: 0..cast(u32) vertex_count - 1 {
                    array_add(*geometry.indices, index);
                }
            }

            geometry_stride := get_attribute_stride(geometry);
            array_reserve(*geometry.vertices, geometry_stride * attribute_count);

            for i: 0..attribute_count - 1 {
                for accessors, accessor_type_value: attribute_accessors {
                    attribute_type := cast(Attribute) accessor_type_value;

                    for accessor: accessors {
                        if #complete attribute_type == {
                            case .Position;
                                accessor_data := cast(*float32) accessor.view.data;
                                array_add(*geometry.vertices, accessor_data[i * 3], accessor_data[i * 3 + 1], accessor_data[i * 3 + 2]);
                            case .Normal;
                                accessor_data := cast(*float32) accessor.view.data;
                                array_add(*geometry.vertices, accessor_data[i * 3], accessor_data[i * 3 + 1], accessor_data[i * 3 + 2]);
                            case .Texcoord;
                                accessor_data := cast(*float32) accessor.view.data;
                                array_add(*geometry.vertices, accessor_data[i * 2], accessor_data[i * 2 + 1]);
                            case .Texcoord3;
                                accessor_data := cast(*float32) accessor.view.data;
                                array_add(*geometry.vertices, accessor_data[i * 3], accessor_data[i * 3 + 1], accessor_data[i * 3 + 2]);
                            case .Color;
                                if accessor.component_type == {
                                    case .U8;
                                        accessor_data := cast(*u8) accessor.view.data;
                                        array_add(*geometry.vertices, cast(float) accessor_data[i * 4] / 0xff, cast(float) accessor_data[i * 4 + 1] / 0xff, cast(float) accessor_data[i * 4 + 2] / 0xff, cast(float) accessor_data[i * 4 + 3] / 0xff);
                                    case .U16;
                                        accessor_data := cast(*u16) accessor.view.data;
                                        array_add(*geometry.vertices, cast(float) accessor_data[i * 4] / 0xffff, cast(float) accessor_data[i * 4 + 1] / 0xffff, cast(float) accessor_data[i * 4 + 2] / 0xffff, cast(float) accessor_data[i * 4 + 3] / 0xffff);
                                    case .F32;
                                        accessor_data := cast(*float32) accessor.view.data;
                                        array_add(*geometry.vertices, cast(float) accessor_data[i * 4], cast(float) accessor_data[i * 4 + 1], cast(float) accessor_data[i * 4 + 2], cast(float) accessor_data[i * 4 + 3]);
                                    case;
                                        assert(false, "Incorrect color component type.");
                                }
                            case .JointIndices;
                                if accessor.component_type == {
                                    case .U8;
                                        accessor_data := cast(*u8) accessor.view.data;
                                        array_add(*geometry.vertices, cast(float) accessor_data[i * 4], cast(float) accessor_data[i * 4 + 1], cast(float) accessor_data[i * 4 + 2], cast(float) accessor_data[i * 4 + 3]);
                                    case .U16;
                                        accessor_data := cast(*u16) accessor.view.data;
                                        array_add(*geometry.vertices, cast(float) accessor_data[i * 4], cast(float) accessor_data[i * 4 + 1], cast(float) accessor_data[i * 4 + 2], cast(float) accessor_data[i * 4 + 3]);
                                    case .U32;
                                        accessor_data := cast(*u32) accessor.view.data;
                                        array_add(*geometry.vertices, cast(float) accessor_data[i * 4], cast(float) accessor_data[i * 4 + 1], cast(float) accessor_data[i * 4 + 2], cast(float) accessor_data[i * 4 + 3]);
                                    case;
                                        assert(false, "Incorrect joint indices component type.");
                                }
                            case .JointWeights;
                                accessor_data := cast(*float32) accessor.view.data;
                                array_add(*geometry.vertices, accessor_data[i * 4], accessor_data[i * 4 + 1], accessor_data[i * 4 + 2], accessor_data[i * 4 + 3]);
                            case .Float;
                                accessor_data := cast(*float32) accessor.view.data;
                                array_add(*geometry.vertices, accessor_data[i]);
                        }
                    }
                }
            }
        }
    }

    return geometries, true;
}
