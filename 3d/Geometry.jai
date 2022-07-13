Geometry :: struct {
    vao_: GLuint;
    vbo_: GLuint;
    ebo_: GLuint;

    name: string;
    vertices: [..] GeometryVertex;
    vertex_indices: [..] u32;
}

free :: (geometry: *Geometry) {
    glDeleteBuffers(1, *geometry.ebo_);
    glDeleteBuffers(1, *geometry.vbo_);
    glDeleteVertexArrays(1, *geometry.vao_);

    free(geometry.name);
    array_free(geometry.vertices);
    array_free(geometry.vertex_indices);
}

load_or_save_serialized_geometry :: (serialized_path: string, obj_path: string) -> Geometry, bool {
    if !file_exists(serialized_path) {
    }

    file, success := read_entire_file(serialized_path);
    defer free(file);
    if !success {
        // TODO should be load_multiple_obj
        geometry, success := load_single_obj(obj_path);
        if !success {
            return .{}, false;
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

load_serialized_geometry :: (path: string) -> Geometry, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        return .{}, false;
    }

    view: [] u8;
    view.data = file.data;
    view.count = file.count;

    return deserialized_geometry(view), true;
}

deserialized_geometry :: (bytes: [] u8) -> Geometry {
    geometry: Geometry;

    index: int;
    serializer.read(bytes, *index, *geometry);

    gen_geometry(*geometry);

    return geometry;
}

serialize_geometry :: (geometry: Geometry) -> [..] u8 {
    bytes: [..] u8;
    serializer.write(*bytes, geometry);

    return bytes;
}

load_multiple_obj :: (path: string) -> [..] Geometry, bool {
    assert(false, "TODO");
}

load_single_obj :: (path: string) -> Geometry, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        return .{}, false;
    }

    object_sections := split(file, "o ");
    // assert(object_sections.count == 2, "Cannot have more than 1 object.");

    vertices: [..] Vector3;
    normals: [..] Vector3;
    texture_coords: [..] Vector2;

    defer array_free(vertices);
    defer array_free(normals);
    defer array_free(texture_coords);

    geometry: Geometry;

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

                array_add(*vertices, xyz(x, y, z));
            } else if starts_with(line, "vt ") {
                subline := slice(line, 3, line.count - 3);

                texture_coord := split(subline, " ");
                x := string_to_float(texture_coord[0]);
                y := 1.0 - string_to_float(texture_coord[1]);

                array_add(*texture_coords, xy(x, y));
            } else if starts_with(line, "vn ") {
                subline := slice(line, 3, line.count - 3);

                normal := split(subline, " ");
                x := string_to_float(normal[0]);
                y := string_to_float(normal[1]);
                z := string_to_float(normal[2]);

                array_add(*normals, xyz(x, y, z));
            } else if starts_with(line, "f ") {
                subline := slice(line, 2, line.count - 2);

                faces_chunks := split(subline, " ");
                assert(faces_chunks.count == 3, "Must be triangularized.");

                for faces_chunk: faces_chunks {
                    face_info := split(faces_chunk, "/");

                    array_add(*geometry.vertex_indices, xx geometry.vertices.count);
                    vertex := array_add(*geometry.vertices);

                    vertex.position = vertices[string_to_int(face_info[0]) - vertex_offset - 1];

                    if texture_coords.count > 0 {
                        vertex.texture_coord = texture_coords[string_to_int(face_info[1]) - texture_coord_offset - 1];
                    }
                    
                    if normals.count > 0 {
                        vertex.normal = normals[string_to_int(face_info[2]) - normal_offset - 1];
                    }
                }
            }
        }
    }

    gen_geometry(*geometry);

    return geometry, true;
}

#scope_module

gen_geometry :: (geometry: *Geometry) {
    glGenVertexArrays(1, *geometry.vao_);
    glGenBuffers(1, *geometry.vbo_);
    glGenBuffers(1, *geometry.ebo_);
  
    glBindVertexArray(geometry.vao_);

    glBindBuffer(GL_ARRAY_BUFFER, geometry.vbo_);
    glBufferData(GL_ARRAY_BUFFER, geometry.vertices.count * size_of(GeometryVertex), geometry.vertices.data, GL_STATIC_DRAW);  

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, geometry.ebo_);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, geometry.vertex_indices.count * size_of(u32), geometry.vertex_indices.data, GL_STATIC_DRAW);

    // vertex positions
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(GeometryVertex), cast(*void) 0);
    // vertex normals
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, size_of(GeometryVertex), cast(*void) size_of(Vector3));
    // vertex texture coords
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, size_of(GeometryVertex), cast(*void) (size_of(Vector3) + size_of(Vector3)));

    glBindVertexArray(0);
}

#scope_file

#import "String";
#import "GL";