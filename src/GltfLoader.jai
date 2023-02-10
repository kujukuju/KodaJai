
#scope_module

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
        copyright: *string;
        generator: *string;
        version: string;
        minVersion: *string;
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
        magFilter: *int;
        minFilter: *int;
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
    }

    GltfJsonNode :: struct {
        camera: *int;
        children: *[..] int;
        skin: *int;
        matrix: [16] float = .[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
        mesh: *int;
        rotation: [4] float = .[0, 0, 0, 1];
        scale: [3] float = .[1, 1, 1];
        translation: [3] float = .[0, 0, 0];
        weights: *[..] float;
        name: *string;
    }
}

load_glb :: (file: string) -> GltfJson, [] u8, *u8, bool {
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
    defer free(json_memory);

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
    defer free(json_memory);

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

is_valid_primitive :: (primitive: GltfJson.GltfJsonMesh.GltfJsonMeshPrimitive) -> bool {
    // needs to match model code
    if !primitive.indices {
        return false;
    }

    position_accessor_object := primitive.attributes["POSITION"];
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
