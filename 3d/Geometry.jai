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

load_or_save_serialized_geometry :: (serialized_path: string, path: string) -> Geometry, bool {
    file, success := read_entire_file(serialized_path, log_errors = false);
    defer free(file);
    if !success {
        geometry, success := load_geometry(path);
        if !success {
            print("Could not load files.\n%\n%\n", serialized_path, path);
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

load_geometry :: (path: string) -> Geometry, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        return .{}, false;
    }

    if ends_with(path, ".obj") {
        geometry, success := load_obj(path);
        if !success {
            return .{}, false;
        }

        return geometry, true;
    } else if ends_with(path, ".glb") {
        print("loadin?\n");
        geometry, success := load_glb(path);
        if !success {
            return .{}, false;
        }

        return geometry, true;
    } else if ends_with(path, ".gltf") {
        assert(false, "Does not currently support gltf. Has to be binary glb.");
        return .{}, false;
    } else {
        print("Unknown file type. %\n", path);
        return .{}, false;
    }
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

#scope_module

load_obj :: (path: string) -> Geometry, bool {
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

load_glb :: (path: string) -> Geometry, bool {
    GltfHeader :: struct {
        magic: u32;
        version: u32;
        length: u32;
    }

    GltfChunkHeader :: struct {
        chunk_length: u32;
        chunk_type: GltfChunkType;
    }

    GltfChunkType :: enum u32 {
        JSON :: 0x4E4F534A;
        BINARY :: 0x004E4942;
    }

    GltfJson :: struct {
        asset: GltfJsonAsset;
        scene: int;
        buffers: [..] GltfJsonBuffer;
        bufferViews: [..] GltfJsonBufferView;
        scenes: [..] GltfJsonScene;
        accessors: [..] GltfJsonAccessor;
        images: [..] GltfJsonImage;
        samplers: [..] GltfJsonSampler;
        textures: [..] GltfJsonTexture;
        materials: [..] GltfJsonMaterial;
        meshes: [..] GltfJsonMesh;
        nodes: [..] GltfJsonNode;

        GltfJsonAsset :: struct {
            copyright: string;
            generator: string;
            version: string;
            minVersion: string;
        }

        GltfJsonBuffer :: struct {
            uri: string;
            byteLength: int;
            name: string;
        }

        GltfJsonBufferView :: struct {
            buffer: int;
            byteOffset: int = 0;
            byteLength: int;
            byteStride: int;
            target: int;
            name: string;
        }

        GltfJsonScene :: struct {
            nodes: [..] int;
            name: string;
        }

        GltfJsonAccessor :: struct {
            bufferView: int;
            byteOffset: int = 0;
            componentType: int;
            normalized: bool = false;
            count: int;
            type: string;
            max: [..] float;
            min: [..] float;
            sparse: struct {
                count: int;
                indices: struct {
                    bufferView: int;
                    byteOffset: int = 0;
                    componentType: int;
                };
                values: struct {
                    bufferView: int;
                    byteOffset: int = 0;
                };
            };
        }

        GltfJsonImage :: struct {
            uri: string;
            mimeType: string;
            bufferView: int;
            name: string;
        }

        GltfJsonSampler :: struct {
            magFilter: int;
            minFilter: int;
            wrapS: int = 0x2901;
            wrapT: int = 0x2901;
            name: string;
        }

        GltfJsonTexture :: struct {
            sampler: int;
            source: int;
            name: string;
        }

        GltfJsonMaterial :: struct {
            name: string;
            pbrMetallicRoughness: struct {
                baseColorFactor: [4] int = .[1, 1, 1, 1];
                baseColorTexture: struct {
                    index: int;
                    texCoord: int = 0;
                };
                metallicFactor: float;
                roughnessFactor: float;
                metallicRoughnessTexture: struct {
                    index: int;
                    texCoord: int = 0;
                };
            };
            normalTexture: struct {
                index: int;
                texCoord: int = 0;
                scale: float = 1.0;
            };
            occlusionTexture: struct {
                index: int;
                texCoord: int = 0;
                strength: float = 1.0;
            };
            emissiveTexture: struct {
                index: int;
                texCoord: int = 0;
            };
            emissiveFactor: [3] float = .[0, 0, 0];
            alphaMode: string = "OPAQUE";
            alphaCutoff: float = 0.5;
            doubleSided: bool = false;
        }

        GltfJsonMesh :: struct {
            primitives: [..] struct {
                attributes: JSON_Value;
                indices: int;
                material: int;
                mode: int = 4;
                targets: [..] JSON_Value;
            };
            weights: [..] float;
            name: string;
        }

        GltfJsonNode :: struct {
            camera: int;
            children: [..] int;
            skin: int;
            matrix: [16] float = .[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
            mesh: int;
            rotation: [4] float = .[0, 0, 0, 1];
            scale: [3] float = .[1, 1, 1];
            translation: [3] float = .[0, 0, 0];
            weights: [..] float;
            name: string;
        }
    }

    print("loading glb\n");

    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        return .{}, false;
    }

    gltf_header := cast(*GltfHeader) file.data;
    
    if gltf_header.magic != 0x46546C67 {
        return .{}, false;
    }

    if gltf_header.version != 2 {
        print("Cannot load gltf version %.\n", gltf_header.version);
        return .{}, false;
    }

    chunk_pointer := file.data + size_of(GltfHeader);
    while chunk_pointer < cast(*u8) gltf_header + gltf_header.length {
        chunk_header := cast(*GltfChunkHeader) chunk_pointer;
        chunk_pointer += size_of(GltfChunkHeader);

        if chunk_header.chunk_type == {
            case .JSON;
                json: string;
                json.data = chunk_pointer;
                json.count = chunk_header.chunk_length;
                print("JSON:\n%\n\n", json);

            case .BINARY;
                print("Skipping binary.\n");
        }

        chunk_pointer += chunk_header.chunk_length;
    }

    return .{}, false;
}

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