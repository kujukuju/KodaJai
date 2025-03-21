
Geometry :: struct {
    vao_: GLuint;
    vbo_: GLuint;
    ebo_: GLuint;

    vertices: [..] float32;
    indices: [..] u32;
    attributes: [..] Attribute;
    aabb: AABB3;
    bounding_sphere: Sphere;
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
    Vector2;
    Vector3;
    Vector4;
    Integer;
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
    geometry.bounding_sphere = calculate_bounding_sphere(get_vertices(geometry));

    if should_upload {
        upload(geometry);
    }

    return geometry;
}

// create_geometries :: (vertices: [] float32, indices: [] u32, attributes: [] Attribute, should_upload: bool = true) -> [..] *Geometry {
//     for i: 1..attributes.count - 1 {
//         assert(attributes[i] >= attributes[i - 1], "Cannot create geometry with misordered attributes.");
//     }

//     geometries: [..] *Geometry;
//     array_reserve(*geometries, 1);

//     array_add(*geometries, create_geometry(vertices, indices, attributes, should_upload));

//     return geometries;
// }

create_geometry :: (geometry: *Geometry, should_upload: bool = true) -> *Geometry {
    result := New(Geometry);
    array_copy(*result.vertices, geometry.vertices);
    array_copy(*result.indices, geometry.indices);
    array_copy(*result.attributes, geometry.attributes);
    result.aabb = geometry.aabb;
    result.bounding_sphere = geometry.bounding_sphere;

    if should_upload {
        upload(result);
    }

    return result;
}

create_geometry :: (geometries: [] *Geometry, should_upload: bool = true) -> *Geometry {
    if geometries.count > 0 {
        for i: 1..geometries.count - 1 {
            assert(matches_attributes(geometries[i].attributes, geometries[0].attributes), "You cannot merge geometries with different attributes.\n");
        }
    }

    total_vertices: int;
    total_indices: int;
    for geometry: geometries {
        total_vertices += geometry.vertices.count;
        total_indices += geometry.indices.count;
    }

    result := New(Geometry);
    array_reserve(*result.vertices, total_vertices);
    array_reserve(*result.indices, total_indices);
    if geometries.count > 0 {
        array_copy(*result.attributes, geometries[0].attributes);

        result.aabb = geometries[0].aabb;
        for i: 1..geometries.count - 1 {
            result.aabb = merge(result.aabb, geometries[i].aabb);
        }
    }

    result.vertices.count = 0;
    result.indices.count = 0;
    for geometry: geometries {
        index_offset := cast(u32) (result.vertices.count / get_attribute_stride(geometry));

        memcpy(result.vertices.data + result.vertices.count, geometry.vertices.data, geometry.vertices.count * size_of(float32));
        result.vertices.count += geometry.vertices.count;

        // untested because it was wrong before, idk how it ever worked if it ever did
        for i: 0..geometry.indices.count - 1 {
            (result.indices.data + result.indices.count + i).* = geometry.indices[i] + index_offset;
        }
        result.indices.count += geometry.indices.count;
    }

    result.bounding_sphere = calculate_bounding_sphere(get_vertices(result));

    if should_upload {
        upload(result);
    }

    return result;
}

load_geometry :: (path: string, should_upload: bool = true) -> *Geometry, bool {
    geometries, success := load_geometries(path, false);
    assert(success, "Could not load geometry.\n");
    defer array_free(geometries);
    if !success {
        return null, false;
    }

    if geometries.count > 1 {
        print("Warning: You're loading more than 1 geometry from a single file. The result of this should be serialized.\n");
        merged := create_geometry(geometries, should_upload);

        for geometry: geometries {
            destroy(geometry);
        }

        return merged, true;
    }

    if should_upload {
        upload(geometries[0]);
    }

    return geometries[0], true;
}

load_geometries :: (path: string, should_upload: bool = true) -> [..] *Geometry, bool {
    file, success := read_entire_file(path);
    assert(success, "Could not load geometry.\n");
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
// deserialize_geometry :: (bytes: [] u8, should_upload: bool = true) -> *Geometry {
//     geometry: *Geometry;
//     serializer_read(bytes, *geometry);
//     geometry.vao_ = 0;
//     geometry.vbo_ = 0;
//     geometry.ebo_ = 0;

//     if should_upload {
//         upload(geometry);
//     }

//     return geometry;
// }

// serialize_geometry :: (geometry: *Geometry) -> [..] u8 {
//     bytes: [..] u8;
//     serializer_write(*bytes, geometry);

//     print("wrote % bytes for geometry.\n", bytes.count);

//     return bytes;
// }

upload :: (geometry: *Geometry) {
    assert(koda.initialized, "Attempting to gen geometry without the window being initialized.");

    if geometry.vao_ {
        print("Warning: Trying to upload a geometry that's already uploaded.\n");
        print_stack_trace();
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
    glBufferData(GL_ARRAY_BUFFER, geometry.vertices.allocated * size_of(float32), geometry.vertices.data, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, geometry.ebo_);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, geometry.indices.allocated * size_of(u32), geometry.indices.data, GL_STATIC_DRAW);

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
    if !geometry.vao_ {
        return;
    }

    glDeleteBuffers(1, *geometry.ebo_);
    glDeleteBuffers(1, *geometry.vbo_);
    glDeleteVertexArrays(1, *geometry.vao_);

    geometry.ebo_ = 0;
    geometry.vbo_ = 0;
    geometry.vao_ = 0;
}

destroy :: (geometry: *Geometry) {
    if geometry.vao_ {
        glDeleteBuffers(1, *geometry.ebo_);
        glDeleteBuffers(1, *geometry.vbo_);
        glDeleteVertexArrays(1, *geometry.vao_);
    }

    array_free(geometry.vertices);
    geometry.vertices.data = null;
    geometry.vertices.count = 0;
    array_free(geometry.indices);
    geometry.indices.data = null;
    geometry.indices.count = 0;
    array_free(geometry.attributes);
    geometry.attributes.data = null;
    geometry.attributes.count = 0;
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

        query_position := geometry_position;
        query_radius := 0.0;
        best_vertex: *Vector3;

        while !best_vertex {
            query_radius += OFFSET;
            position_aabb := AABB3.{query_position - query_radius, query_position + query_radius};

            for value: query(*source_tree, position_aabb) {
                source_position: Vector3 = (cast(*Vector3) value).*;

                current_distance := distance(query_position, source_position);
                if current_distance <= query_radius {
                    if !best_vertex {
                        best_vertex = cast(*Vector3) value;
                        continue;
                    }

                    if current_distance < distance(query_position, best_vertex.*) {
                        best_vertex = cast(*Vector3) value;
                        continue;
                    }
                }
            }
        }

        best_vertex_data := cast(*float) best_vertex;

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

get_indices :: (geometry: Geometry, $T: Type = int) -> [..] T {
    indices: [..] T;
    indices.allocator = temp;

    array_reserve(*indices, geometry.indices.count);

    for index: geometry.indices {
        array_add(*indices, xx index);
    }

    return indices;
}

GeometryVertices :: struct (preserve_faces: bool) {
    geometry: Geometry;
}

get_vertices :: (geometry: Geometry, $preserve_faces: bool = false) -> GeometryVertices(preserve_faces) {
    return GeometryVertices(preserve_faces).{geometry};
}

for_expansion :: (wrapper: GeometryVertices($preserve_faces), body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .REVERSE));

    stride := get_attribute_stride(wrapper.geometry);

    #if preserve_faces {
        for i: 0..wrapper.geometry.indices.count - 1 {
            #if flags & .POINTER {
                `it := cast(*Vector3) (wrapper.geometry.vertices.data + wrapper.geometry.indices[i] * stride);
            } else {
                `it := (cast(*Vector3) (wrapper.geometry.vertices.data + wrapper.geometry.indices[i] * stride)).*;
            }

            `it_index := i;

            #insert body;
        }
    } else {
        for i: 0..wrapper.geometry.vertices.count / stride - 1 {
            #if flags & .POINTER {
                `it := cast(*Vector3) (wrapper.geometry.vertices.data + i * stride);
            } else {
                `it := (cast(*Vector3) (wrapper.geometry.vertices.data + i * stride)).*;
            }

            `it_index := i;

            #insert body;
        }
    }
}

copy_vertices :: (geometry: Geometry, $preserve_faces: bool = false) -> [] Vector3 {
    stride := get_attribute_stride(geometry);

    vertex_count: int;
    if preserve_faces {
        vertex_count = geometry.indices.count;
    } else {
        vertex_count = geometry.vertices.count / stride;
    }

    vertices := NewArray(vertex_count, Vector3);
    for vertex: get_vertices(geometry, preserve_faces) {
        vertices[it_index] = vertex;
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

get_attribute_stride :: (attribute: Attribute) -> int {
    return get_attribute_size(attribute);
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
        case .Vector2;
            return 2;
        case .Vector3;
            return 3;
        case .Vector4;
            return 4;
        case .Integer;
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
    return calculate_aabb(get_vertices(geometry));
}

calculate_bounding_sphere :: (geometry: Geometry) -> Sphere {
    return calculate_bounding_sphere(get_vertices(geometry));
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

    get_until_space_or_slash_or_newline :: (file: string, index: int) -> int, string {
        current: string;
        current.data = file.data + index;
        initial_index := index;
        while index < file.count && file[index] != #char " " && file[index] != #char "/" && file[index] != #char "\n" {
            index += 1;
        }

        current.count = index - initial_index;

        return index, current;
    }

    get_until_slash_exit_space_newline :: (file: string, index: int) -> int, string {
        current: string;
        current.data = file.data + index;
        initial_index := index;
        while index < file.count && file[index] != #char "/" && file[index] != #char " " {
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

    index := 0;
    while index < file.count {
        if index + 1 < file.count && file[index] == #char "o" && file[index + 1] == #char " " {
            geometry = New(Geometry);
            array_add(*geometries, geometry);

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

            index, x_string = get_until_space_or_slash_or_newline(file, index + 2);
            index, y_string = get_until_space_or_slash_or_newline(file, index + 1);
            index, z_string = get_until_space_or_slash_or_newline(file, index + 1);

            x_value := string_to_float(x_string);
            y_value := string_to_float(y_string);
            z_value := string_to_float(z_string);

            array_add(*vertices, .{x_value, y_value, z_value});
        } else if index + 2 < file.count && file[index] == #char "v" && file[index + 1] == #char "t" && file[index + 2] == #char " " {
            x_string: string;
            y_string: string;

            index, x_string = get_until_space_or_slash_or_newline(file, index + 3);
            index, y_string = get_until_space_or_slash_or_newline(file, index + 1);

            x_value := string_to_float(x_string);
            y_value := string_to_float(y_string);

            array_add(*texcoords, .{x_value, y_value});
        } else if index + 2 < file.count && file[index] == #char "v" && file[index + 1] == #char "n" && file[index + 2] == #char " " {
            x_string: string;
            y_string: string;
            z_string: string;

            index, x_string = get_until_space_or_slash_or_newline(file, index + 3);
            index, y_string = get_until_space_or_slash_or_newline(file, index + 1);
            index, z_string = get_until_space_or_slash_or_newline(file, index + 1);

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

            t: string;
            t.data = file.data + index;
            t.count = 20;

            index, v1_string = get_until_space_or_slash_or_newline(file, index + 2);
            if normals.count > 0 && texcoords.count > 0 {
                index, vt1_string = get_until_space_or_slash_or_newline(file, index + 1);
                index, vn1_string = get_until_space_or_slash_or_newline(file, index + 1);
            } else if texcoords.count > 0 {
                index, vt1_string = get_until_space_or_slash_or_newline(file, index + 1);
            } else if normals.count > 0 {
                index, vn1_string = get_until_space_or_slash_or_newline(file, index + 2);
            }

            index, v2_string = get_until_space_or_slash_or_newline(file, index + 1);
            if normals.count > 0 && texcoords.count > 0 {
                index, vt2_string = get_until_space_or_slash_or_newline(file, index + 1);
                index, vn2_string = get_until_space_or_slash_or_newline(file, index + 1);
            } else if texcoords.count > 0 {
                index, vt2_string = get_until_space_or_slash_or_newline(file, index + 1);
            } else if normals.count > 0 {
                index, vn2_string = get_until_space_or_slash_or_newline(file, index + 2);
            }

            index, v3_string = get_until_space_or_slash_or_newline(file, index + 1);
            if normals.count > 0 && texcoords.count > 0 {
                index, vt3_string = get_until_space_or_slash_or_newline(file, index + 1);
                newline_index := get_until_newline(file, index + 1);
                index, vn3_string = get_until_space_or_slash_or_newline(file, index + 1);
                assert(newline_index == index, "Found a space where a newline was expected. Probably the obj file isn't triangularized.");
            } else if texcoords.count > 0 {
                newline_index := get_until_newline(file, index + 1);
                index, vt3_string = get_until_space_or_slash_or_newline(file, index + 1);
                assert(newline_index == index, "Found a space where a newline was expected. Probably the obj file isn't triangularized.");
            } else if normals.count > 0 {
                newline_index := get_until_newline(file, index + 2);
                index, vn3_string = get_until_space_or_slash_or_newline(file, index + 2);
                assert(newline_index == index, "Found a space where a newline was expected. Probably the obj file isn't triangularized.");
            }

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

    for geometry: geometries {
        geometry.aabb = calculate_aabb(geometry);
        geometry.bounding_sphere = calculate_bounding_sphere(geometry);
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

load_geometry_gltf_data :: (
        json: GltfJson,
        binary: [] u8,
        geometry_to_primitive: *[..] *GltfJson.GltfJsonMesh.GltfJsonMeshPrimitive = null,
        geometry_to_mesh: *[..] int = null,
        primitive_to_geometry: *Table(*GltfJson.GltfJsonMesh.GltfJsonMeshPrimitive, int) = null) -> [..] *Geometry, bool {
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

    for *mesh, mesh_index: json.meshes {
        for *primitive: mesh.primitives {
            if !is_valid_primitive(primitive) {
                continue;
            }

            assert(primitive.attributes.type == .Object, "The attributes entry must be an object type.");

            geometry := New(Geometry);
            array_add(*geometries, geometry);

            if geometry_to_primitive then array_add(geometry_to_primitive, primitive);
            if geometry_to_mesh then array_add(geometry_to_mesh, mesh_index);
            if primitive_to_geometry then table_set(primitive_to_geometry, primitive, geometries.count - 1);

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
                    assert(attribute_accessor.type == "VEC3", "The position accessor must be a vec3 type. % %", mesh.name, attribute_accessor.type);
                    assert(attribute_accessor.component_type == .F32, "The position accessor must be a float32. % %", mesh.name, attribute_accessor.component_type);

                    array_add(*attribute_accessors[cast(int) Attribute.Position], attribute_accessor);
                } else if begins_with(attribute_entry.name, "NORMAL") {
                    assert(attribute_accessor.type == "VEC3", "The normal accessor must be a vec3 type. % %", mesh.name, attribute_accessor.type);
                    assert(attribute_accessor.component_type == .F32, "The normal accessor must be a float32. % %", mesh.name, attribute_accessor.component_type);

                    array_add(*attribute_accessors[cast(int) Attribute.Normal], attribute_accessor);
                } else if begins_with(attribute_entry.name, "TEXCOORD") {
                    assert(attribute_accessor.type == "VEC2", "The texcoord accessor must be a vec2 type. % %", mesh.name, attribute_accessor.type);
                    assert(attribute_accessor.component_type == .F32, "The texcoord accessor must be a float32. % %", mesh.name, attribute_accessor.component_type);

                    array_add(*attribute_accessors[cast(int) Attribute.Texcoord], attribute_accessor);
                } else if begins_with(attribute_entry.name, "COLOR") {
                    assert(attribute_accessor.type == "VEC4", "The color accessor must be a vec4 type. % %", mesh.name, attribute_accessor.type);
                    assert(attribute_accessor.component_type == .U8 || attribute_accessor.component_type == .U16 ||attribute_accessor.component_type == .F32, "The color accessor must be a u8 or u16 or float32. % %", mesh.name, attribute_accessor.component_type);

                    array_add(*attribute_accessors[cast(int) Attribute.Color], attribute_accessor);
                } else if begins_with(attribute_entry.name, "JOINTS") {
                    assert(attribute_accessor.type == "VEC4", "The joint indices accessor must be a vec4 type. % %", mesh.name, attribute_accessor.type);
                    assert(attribute_accessor.component_type == .U8 || attribute_accessor.component_type == .U16 || attribute_accessor.component_type == .U32, "The joint indices accessor must be a u8 or u16 or u32. % %", mesh.name, attribute_accessor.component_type);

                    array_add(*attribute_accessors[cast(int) Attribute.JointIndices], attribute_accessor);
                } else if begins_with(attribute_entry.name, "WEIGHTS") {
                    assert(attribute_accessor.type == "VEC4", "The joint weights accessor must be a vec4 type. % %", mesh.name, attribute_accessor.type);
                    assert(attribute_accessor.component_type == .F32, "The joint weights accessor must be a float32. % %", mesh.name, attribute_accessor.component_type);

                    array_add(*attribute_accessors[cast(int) Attribute.JointWeights], attribute_accessor);
                } else {
                    assert(false, "Found unknown attribute type. % %", mesh.name, attribute_entry.name);
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
                            case .Vector2;
                                accessor_data := cast(*float32) accessor.view.data;
                                array_add(*geometry.vertices, accessor_data[i * 2], accessor_data[i * 2 + 1]);
                            case .Vector3;
                                accessor_data := cast(*float32) accessor.view.data;
                                array_add(*geometry.vertices, accessor_data[i * 3], accessor_data[i * 3 + 1], accessor_data[i * 3 + 2]);
                            case .Vector4;
                                accessor_data := cast(*float32) accessor.view.data;
                                array_add(*geometry.vertices, accessor_data[i * 4], accessor_data[i * 4 + 1], accessor_data[i * 4 + 2], accessor_data[i * 4 + 3]);
                            case .Integer;
                                assert(false, "You cannot load an integer as gltf data.\n");
                        }
                    }
                }
            }
        }
    }

    for geometry: geometries {
        geometry.aabb = calculate_aabb(geometry);
        geometry.bounding_sphere = calculate_bounding_sphere(geometry);
    }

    return geometries, true;
}
