
#scope_module

GltfJson :: struct {
    GltfJsonAsset :: struct {
        copyright: *string;
        generator: *string;
        version: string;
        minVersion: *string;
    }

    GltfJsonExtensions :: struct {
        GltfJsonLights :: struct {
            GltfJsonLight :: struct {
                color: [3] float;
                intensity: float;
                type: string;
                name: string;
                extras: *JsonGeneric;
            }

            lights: [..] GltfJsonLight;
        }

        KHR_lights_punctual: *GltfJsonLights;
    }

    GltfJsonBuffer :: struct {
        uri: *string;
        byteLength: int;
        name: *string;
    }

    GltfJsonBufferView :: struct {
        buffer: int;
        byteOffset: int = 0;
        byteLength: int;
        byteStride: *int;
        target: *int;
        name: *string;
    }

    GltfJsonScene :: struct {
        nodes: *[..] int;
        name: *string;
    }

    GltfJsonAccessor :: struct {
        GltfJsonComponentType :: enum int {
            S8 :: 5120;
            U8 :: 5121;
            S16 :: 5122;
            U16 :: 5123;
            U32 :: 5125;
            F32 :: 5126;
        }

        bufferView: *int;
        byteOffset: int = 0;
        componentType: GltfJsonComponentType;
        normalized: bool = false;
        count: int;
        type: string;
        max: *[..] float;
        min: *[..] float;
        sparse: *struct {
            count: int;
            indices: struct {
                bufferView: int;
                byteOffset: int = 0;
                componentType: GltfJsonComponentType;
            };
            values: struct {
                bufferView: int;
                byteOffset: int = 0;
            };
        };
        name: *string;
    }

    GltfJsonImage :: struct {
        uri: *string;
        mimeType: *string;
        bufferView: *int;
        name: *string;
    }

    GltfJsonSampler :: struct {
        magFilter: int = 9729;
        minFilter: int = 9729;
        wrapS: int = 0x2901;
        wrapT: int = 0x2901;
        name: *string;
    }

    GltfJsonTexture :: struct {
        sampler: *int;
        source: *int;
        name: *string;
    }

    GltfJsonMaterial :: struct {
        name: *string;
        extensions: *JsonGeneric;
        extras: *JsonGeneric;
        pbrMetallicRoughness: *struct {
            baseColorFactor: [4] float = .[1, 1, 1, 1];
            baseColorTexture: *struct {
                index: int;
                texCoord: int = 0;
            };
            metallicFactor: float = 1.0;
            roughnessFactor: float = 1.0;
            metallicRoughnessTexture: *struct {
                index: int;
                texCoord: int = 0;
            };
        };
        normalTexture: *struct {
            index: int;
            texCoord: int = 0;
            scale: float = 1.0;
        };
        occlusionTexture: *struct {
            index: int;
            texCoord: int = 0;
            strength: float = 1.0;
        };
        emissiveTexture: *struct {
            index: int;
            texCoord: int = 0;
        };
        emissiveFactor: [3] float = .[0, 0, 0];
        alphaMode: string = "OPAQUE";
        alphaCutoff: float = 0.5;
        doubleSided: bool = false;
    }

    GltfJsonMesh :: struct {
        GltfJsonMeshPrimitive :: struct {
            attributes: JsonGeneric;
            indices: *int;
            material: *int;
            mode: int = 4;
            targets: *[..] JsonGeneric;
        };
        primitives: [..] GltfJsonMeshPrimitive;
        weights: [..] float;
        name: string;
        extensions: *JsonGeneric;
        extras: *JsonGeneric;
    }

    GltfJsonNode :: struct {
        GltfJsonExtensions :: struct {
            GltfJsonLight :: struct {
                light: int;
            }

            KHR_lights_punctual: *GltfJsonLight;
        }

        camera: *int;
        children: *[..] int;
        skin: *int;
        matrix: *[16] float;
        mesh: *int;
        rotation: [4] float = .[0, 0, 0, 1];
        scale: [3] float = .[1, 1, 1];
        translation: [3] float = .[0, 0, 0];
        weights: *[..] float;
        name: *string;
        extensions: *GltfJsonExtensions;
        extras: *JsonGeneric;
    }

    GltfJsonSkin :: struct {
        inverseBindMatrices: *int;
        skeleton: *int;
        joints: [..] int;
        name: *string;
    }

    GltfJsonAnimation :: struct {
        GltfJsonAnimationChannel :: struct {
            GltfJsonAnimationChannelTarget :: struct {
                node: *int;
                path: string;
            }

            sampler: int;
            target: GltfJsonAnimationChannelTarget;
        }

        GltfJsonAnimationSampler :: struct {
            input: int;
            interpolation: string = "LINEAR";
            output: int;
        }

        channels: [..] GltfJsonAnimationChannel;
        samplers: [..] GltfJsonAnimationSampler;
        name: *string;
    }

    asset: GltfJsonAsset;
    scene: int;
    extensions: *GltfJsonExtensions;
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
    skins: *[..] GltfJsonSkin;
    animations: *[..] GltfJsonAnimation;
}

GltfAccessorInfo :: struct {
    view: [] u8;
    type: string;
    component_type: GltfJson.GltfJsonAccessor.GltfJsonComponentType;
    stride: int;
    min: [] float;
    max: [] float;
}

load_glb :: (file: string) -> GltfJson, [] u8, *u8, bool {
    GltfHeader :: struct {
        magic: u32;
        version: u32;
        length: u32;
    }

    GltfChunkType :: enum u32 {
        JSON :: 0x4E4F534A;
        BINARY :: 0x004E4942;
    }

    GltfChunkHeader :: struct {
        chunk_length: u32;
        chunk_type: GltfChunkType;
    }

    gltf_header := cast(*GltfHeader) file.data;
    
    if gltf_header.magic != 0x46546C67 {
        return .{}, .[], null, false;
    }

    if gltf_header.version != 2 {
        print("Cannot load gltf version %.\n", gltf_header.version);
        return .{}, .[], null, false;
    }

    json: GltfJson = ---;
    json_memory: *u8;
    json_valid: bool;

    binary: [] u8;

    chunk_pointer := file.data + size_of(GltfHeader);
    while chunk_pointer < cast(*u8) gltf_header + gltf_header.length {
        chunk_header := cast(*GltfChunkHeader) chunk_pointer;
        chunk_pointer += size_of(GltfChunkHeader);

        assert(chunk_header.chunk_length % 4 == 0, "The next chunk start isn't aligned to a 4 byte boundary. I'm not handling this correctly.");

        if chunk_header.chunk_type == {
            case .JSON;
                json_chunk: string;
                json_chunk.data = chunk_pointer;
                json_chunk.count = chunk_header.chunk_length;
                json, json_memory, json_valid = json_parse(json_chunk, GltfJson, keep_strings_in_place = true);

            case .BINARY;
                binary.data = chunk_pointer;
                binary.count = chunk_header.chunk_length;
        }

        chunk_pointer += chunk_header.chunk_length;
    }

    if !json_valid {
        print("Could not parse gltf json.\n");
        return .{}, .[], null, false;
    }
    
    if !binary {
        print("No glb buffer found.\n");
        return .{}, .[], null, false;
    }

    return json, binary, json_memory, true;
}

load_gltf :: (file: string, path: string) -> GltfJson, [] u8, *u8, bool {
    // TODO path is probably unecessary
    root_path: string;
    root_path.data = path.data;
    for i: 0..path.count - 1 {
        if path[i] == #char "/" || path[i] == #char "\\" {
            root_path.count = i + 1;
        }
    }

    assert(root_path.count > 0, "Could not find the root path for the gltf file.");

    assert(ends_with(path, ".gltf"), "You must select the gltf file to load a gltf.");
    if !ends_with(path, ".gltf") {
        return .{}, .[], null, false;
    }

    gltf_file, gltf_success := read_entire_file(path);
    if !gltf_success {
        print("Could not read gltf file.\n");
        return .{}, .[], null, false;
    }

    json: GltfJson = ---;
    json_memory: *u8;
    json_valid: bool;

    json, json_memory, json_valid = json_parse(gltf_file, GltfJson, keep_strings_in_place = true);
    if !json_valid {
        print("Could not parse gltf json.\n");
        return .{}, .[], null, false;
    }

    if json.buffers.count != 1 || !json.buffers[0].uri {
        print("No gltf buffer found.\n");
        return .{}, .[], null, false;
    }

    binary_file_path := sprint("%/%", root_path, << json.buffers[0].uri);
    defer free(binary_file_path);
    binary_file, binary_success := read_entire_file(binary_file_path);
    if !binary_success {
        print("Could not read gltf binary file.\n");
        return .{}, .[], null, false;
    }

    binary: [] u8;
    binary.data = binary_file.data;
    binary.count = binary_file.count;

    return json, binary, json_memory, true;
}

get_buffers :: (json: GltfJson, binary: [] u8) -> [..] [] u8 {
    buffers: [..] [] u8;
    offset := 0;
    for buffer: json.buffers {
        current := array_add(*buffers);
        current.data = binary.data + offset;
        current.count = buffer.byteLength;

        offset += buffer.byteLength;
    }
    return buffers;
}

get_bufferviews :: (json: GltfJson, buffers: [..] [] u8) -> [..] [] u8 {
    bufferviews: [..] [] u8;
    for bufferview: json.bufferViews {
        buffer_index := bufferview.buffer;

        current := array_add(*bufferviews);
        current.data = buffers[buffer_index].data + bufferview.byteOffset;
        current.count = bufferview.byteLength;
    }
    return bufferviews;
}

get_accessors :: (json: GltfJson, bufferviews: [..] [] u8) -> [..] GltfAccessorInfo {
    accessors: [..] GltfAccessorInfo;
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
            current.stride = get_gltf_stride(current.component_type);
            current.view.count = accessor.count * current.stride;
        } else if accessor.type == "VEC2" {
            current.stride = get_gltf_stride(current.component_type) * 2;
            current.view.count = accessor.count * current.stride;
        } else if accessor.type == "VEC3" {
            current.stride = get_gltf_stride(current.component_type) * 3;
            current.view.count = accessor.count * current.stride;
        } else if accessor.type == "VEC4" {
            current.stride = get_gltf_stride(current.component_type) * 4;
            current.view.count = accessor.count * current.stride;
        } else if accessor.type == "MAT4" {
            current.stride = get_gltf_stride(current.component_type) * 16;
            current.view.count = accessor.count * current.stride;
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

    return accessors;
}

get_accessor_view :: (accessor: GltfAccessorInfo, $type: string) -> [] float #modify {
    return type == "SCALAR";
} {
    assert(accessor.type == type, "Scalar accessor view must be a float.");
    assert(accessor.component_type == .F32, "Scalar accessor view must be an f32.");

    view: [] float;
    view.data = xx accessor.view.data;
    view.count = accessor.view.count / accessor.stride;
    return view;
}

get_accessor_view :: (accessor: GltfAccessorInfo, $type: string) -> [] Vector2 #modify {
    return type == "VEC2";
} {
    assert(accessor.type == type, "Vec2 accessor view must be a vec2.");
    assert(accessor.component_type == .F32, "Vec2 accessor view must be an f32.");

    view: [] Vector2;
    view.data = xx accessor.view.data;
    view.count = accessor.view.count / accessor.stride;
    return view;
}

get_accessor_view :: (accessor: GltfAccessorInfo, $type: string) -> [] Vector3 #modify {
    return type == "VEC3";
} {
    assert(accessor.type == type, "Vec3 accessor view must be a vec3.");
    assert(accessor.component_type == .F32, "Vec3 accessor view must be an f32.");

    view: [] Vector3;
    view.data = xx accessor.view.data;
    view.count = accessor.view.count / accessor.stride;
    return view;
}

get_accessor_view :: (accessor: GltfAccessorInfo, $type: string) -> [] Vector4 #modify {
    return type == "VEC4";
} {
    assert(accessor.type == type, "Vec4 accessor view must be a vec4.");
    assert(accessor.component_type == .F32, "Vec4 accessor view must be an f32.");

    view: [] Vector4;
    view.data = xx accessor.view.data;
    view.count = accessor.view.count / accessor.stride;
    return view;
}

get_accessor_view :: (accessor: GltfAccessorInfo, $type: string) -> [] Quaternion #modify {
    return type == "QUAT";
} {
    assert(accessor.type == "VEC4", "Quat accessor view must be a vec4.");
    assert(accessor.component_type == .F32, "Quat accessor view must be an f32.");

    view: [] Quaternion;
    view.data = xx accessor.view.data;
    view.count = accessor.view.count / accessor.stride;
    return view;
}

get_accessor_view :: (accessor: GltfAccessorInfo, $type: string) -> [] Matrix4 #modify {
    return type == "MAT4";
} {
    assert(accessor.type == type, "Mat4 accessor view must be a mat4.");
    assert(accessor.component_type == .F32, "Mat4 accessor view must be an f32.");

    view: [] Matrix4;
    view.data = xx accessor.view.data;
    view.count = accessor.view.count / accessor.stride;
    return view;
}

get_texture :: (json: GltfJson, bufferviews: [..] [] u8, texture_index: int) -> Texture {
    json_texture := json.textures[texture_index];

    // this has to do with repeat/clamp/etc
    sampler := json_texture.sampler;
    source := json_texture.source;

    wrap: TextureWrap = .Clamp;
    interp: TextureInterp = .Linear;
    if sampler {
        texture_sampler := json.samplers[<< sampler];
        assert(texture_sampler.wrapS == texture_sampler.wrapT, "Different horizontal and vertical wrap functions are not currently supported.\n");
        if texture_sampler.wrapS == {
            case 0x812f;
                wrap = .Clamp;
            case 0x8370;
                wrap = .MirroredRepeat;
            case 0x2901;
                wrap = .Repeat;
            case;
                assert(false, "Unknown texture wrap function.\n");
        }

        if texture_sampler.magFilter == 9728 {
            // if nearest
            if texture_sampler.minFilter != 9728 && texture_sampler.minFilter != 9984 && texture_sampler.minFilter != 9986 {
                assert(false, tprint("Different mag and min filters are not currently supported. % %\n", texture_sampler.magFilter, texture_sampler.minFilter));
            }
        }
        if texture_sampler.magFilter == 9729 {
            // if linear
            if texture_sampler.minFilter != 9729 && texture_sampler.minFilter != 9985 && texture_sampler.minFilter != 9987 {
                assert(false, tprint("Different mag and min filters are not currently supported. % %\n", texture_sampler.magFilter, texture_sampler.minFilter));
            }
        }

        if texture_sampler.minFilter == {
            case 9728;
                interp = .Nearest;
            case 9729;
                interp = .Linear;
            case 9984;
                interp = .Nearest;
            case 9985;
                interp = .Linear;
            case 9986;
                interp = .NearestMipmap;
            case 9987 ;
                interp = .LinearMipmap;
            case;
                assert(false, tprint("Unhandled texture interp function. %\n", texture_sampler.minFilter));
        }
    }

    json_image := json.images[<< source];

    texture: Texture;
    if json_image.uri {
        texture = load_texture(json_image.uri.*, wrap, interp);
    } else if json_image.bufferView {
        view_index := json_image.bufferView.*;
        buffer_view := bufferviews[view_index];
        texture = create_texture(buffer_view, wrap, interp);
    } else {
        assert(false, "I think you have to have either an image uri or buffer.");
    }

    return texture;
}

is_valid_primitive :: (primitive: GltfJson.GltfJsonMesh.GltfJsonMeshPrimitive) -> bool {
    // needs to match model codes
    position_accessor_object := primitive.attributes[xx "POSITION"];
    if !position_accessor_object {
        return false;
    }

    return true;
}

get_gltf_stride :: (component_type: GltfJson.GltfJsonAccessor.GltfJsonComponentType) -> int {
    if #complete component_type == {
        case .S8;
            return 1;
        case .U8;
            return 1;
        case .S16;
            return 2;
        case .U16;
            return 2;
        case .U32;
            return 4;
        case .F32;
            return 4;
    }
}

get_transform :: (node: GltfJson.GltfJsonNode) -> Matrix4 {
    node_matrix: Matrix4 = ---;

    if node.matrix {
        node_matrix.floats = << node.matrix;
        node_matrix = transpose(node_matrix);
    } else {
        node_translation: Vector3 = ---;
        node_rotation: Quaternion = ---;
        node_scale: Vector3 = ---;

        node_translation.component = node.translation;
        node_rotation.component = node.rotation;
        node_scale.component = node.scale;

        node_matrix = Matrix4Identity;
        node_matrix = translate(node_matrix, node_translation);
        node_matrix = rotate(node_matrix, node_rotation);
        node_matrix = scale(node_matrix, node_scale);
    }

    return node_matrix;
}
