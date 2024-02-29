ShaderUniformType :: enum {
    Float1;
    Float1N;
    Float2;
    Float2N;
    Float3;
    Float3N;
    Float4;
    Float4N;
    Int1;
    Int1N;
    Int2;
    Int2N;
    Int3;
    Int3N;
    Int4;
    Int4N;
    UInt1;
    UInt1N;
    UInt2;
    UInt2N;
    UInt3;
    UInt3N;
    UInt4;
    UInt4N;
    Mat2;
    Mat2N;
    Mat3;
    Mat3N;
    Mat4;
    Mat4N;
    Texture;
    TextureArray;
    Texture3;
    CubemapTexture;
}

ShaderUniform :: struct {
    name: *u8;
    ownership: bool = true;
    type: ShaderUniformType;
    location: s32;
    union {
        float1: float;
        float1n: [] float;
        float2: [2] float;
        float2n: [] [2] float;
        float3: [3] float;
        float3n: [] [3] float;
        float4: [4] float;
        float4n: [] [4] float;
        int1: s32;
        int1n: [] s32;
        int2: [2] s32;
        int2n: [] [2] s32;
        int3: [3] s32;
        int3n: [] [3] s32;
        int4: [4] s32;
        int4n: [] [4] s32;
        uint1: u32;
        uint1n: [] u32;
        uint2: [2] u32;
        uint2n: [] [2] u32;
        uint3: [3] u32;
        uint3n: [] [3] u32;
        uint4: [4] u32;
        uint4n: [] [4] u32;
        mat2: [4] float;
        mat2n: [] [4] float;
        mat3: [9] float;
        mat3n: [] [9] float;
        mat4: [16] float;
        mat4n: [] [16] float;
        texture: Texture;
        texture_array: TextureArray;
        texture3: Texture3;
        cubemap_texture: CubemapTexture;
    }
}

ShaderUniforms :: struct {
    uniforms: [..] ShaderUniform;
}

operator == :: (a: ShaderUniforms, b: ShaderUniforms) -> bool {
    return a.uniforms.data == b.uniforms.data;
}

operator [] :: (uniforms: ShaderUniforms, name: *u8) -> *ShaderUniform {
    name_string := to_string(name);

    for *uniform: uniforms.uniforms {
        if to_string(uniform.name) == name_string {
            return uniform;
        }
    }

    return null;
}

// TODO can optimize this by set_or_create method that won't delete memory, for example for animation

operator *[] :: (uniforms: *ShaderUniforms, name: *u8) -> *ShaderUniform {
    name_string := to_string(name);

    for i: 0..uniforms.uniforms.count - 1 {
        if to_string(uniforms.uniforms[i].name) == name_string {
            if uniforms.uniforms[i].ownership {
                destroy(uniforms.uniforms[i]);
            }
            return *uniforms.uniforms[i];
            
        }
    }

    return array_add(*uniforms.uniforms);
}

has_uniform :: (uniforms: ShaderUniforms, name: string) -> bool {
    for i: 0..uniforms.uniforms.count - 1 {
        if to_string(uniforms.uniforms[i].name) == name {
            return true;
        }
    }

    return false;
}

// is there a use case for non compile time uniform names?

create_uniform :: ($name: *u8, value: float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float1;
    uniform.float1 = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float1N;
    uniform.float1n = array_copy(value);
    return uniform;
}

create_uniform :: ($name: *u8, value: [2] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float2;
    uniform.float2 = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [2] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float2N;
    uniform.float2n = array_copy(value);
    return uniform;
}

create_uniform :: ($name: *u8, value: Vector2) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float2;
    uniform.float2 = value.component;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] Vector2) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float2N;
    uniform.float2n = array_copy_memory(value, [2] float);
    return uniform;
}

create_uniform :: ($name: *u8, value: Vector3) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float3;
    uniform.float3 = value.component;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] Vector3) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float3N;
    uniform.float3n = array_copy_memory(value, [3] float);
    return uniform;
}

create_uniform :: ($name: *u8, value: [3] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float3;
    uniform.float3 = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [3] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float3N;
    uniform.float3n = array_copy(value);
    return uniform;
}

create_uniform :: ($name: *u8, value: Vector4) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float4;
    uniform.float4 = value.component;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] Vector4) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float4N;
    uniform.float4n = array_copy_memory(value, [4] float);
    return uniform;
}

create_uniform :: ($name: *u8, value: Color) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float4;
    uniform.float4 = value.component;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] Color) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float4N;
    uniform.float4n = array_copy_memory(value, [4] float);
    return uniform;
}

create_uniform :: ($name: *u8, value: [4] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float4;
    uniform.float4 = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [4] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float4N;
    uniform.float4n = array_copy(value);
    return uniform;
}

create_uniform :: ($name: *u8, value: s64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int1;
    uniform.int1 = xx value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] s64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int1N;
    uniform.int1n = NewArray(value.count, s32, initialized = false);
    for i: 0..uniform.int1n.count - 1 {
        uniform.int1n[i] = xx value[i];
    }
    return uniform;
}

create_uniform :: ($name: *u8, value: s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int1;
    uniform.int1 = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int1N;
    uniform.int1n = array_copy(value);
    return uniform;
}

create_uniform :: ($name: *u8, value: Point2) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int2;
    uniform.int2[0] = xx value.x;
    uniform.int2[1] = xx value.y;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] Point2) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int2N;
    uniform.int2n = NewArray(value.count, [2] s32, initialized = false);
    for i: 0..uniform.int2n.count - 1 {
        uniform.int2n[i][0] = xx value[i].x;
        uniform.int2n[i][1] = xx value[i].y;
    }
    return uniform;
}

create_uniform :: ($name: *u8, value: [2] s64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int2;
    uniform.int2[0] = xx value[0];
    uniform.int2[1] = xx value[1];
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [2] s64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int2N;
    uniform.int2n = NewArray(value.count, [2] s32, initialized = false);
    for i: 0..uniform.int2n.count - 1 {
        uniform.int2n[i][0] = xx value[i][0];
        uniform.int2n[i][1] = xx value[i][1];
    }
    
    return uniform;
}

create_uniform :: ($name: *u8, value: [2] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int2;
    uniform.int2 = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [2] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int2N;
    uniform.int2n = array_copy(value);
    return uniform;
}

create_uniform :: ($name: *u8, value: Point3) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int3;
    uniform.int3[0] = xx value.x;
    uniform.int3[1] = xx value.y;
    uniform.int3[2] = xx value.z;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] Point3) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int3N;
    uniform.int3n = NewArray(value.count, [3] s32, initialized = false);
    for i: 0..uniform.int3n.count - 1 {
        uniform.int3n[i][0] = xx value[i].x;
        uniform.int3n[i][1] = xx value[i].y;
        uniform.int3n[i][2] = xx value[i].z;
    }
    return uniform;
}

create_uniform :: ($name: *u8, value: [3] s64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int3;
    uniform.int3[0] = xx value[0];
    uniform.int3[1] = xx value[1];
    uniform.int3[2] = xx value[2];
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [3] s64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int3N;
    uniform.int3n = NewArray(value.count, [3] s32, initialized = false);
    for i: 0..uniform.int3n.count - 1 {
        uniform.int3n[i][0] = xx value[i][0];
        uniform.int3n[i][1] = xx value[i][1];
        uniform.int3n[i][2] = xx value[i][2];
    }
    return uniform;
}

create_uniform :: ($name: *u8, value: [3] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int3;
    uniform.int3 = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [3] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int3N;
    uniform.int3n = array_copy(value);
    return uniform;
}

create_uniform :: ($name: *u8, value: Point4) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int4;
    uniform.int4 = value.component;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] Point4) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int4N;
    uniform.int4n = NewArray(value.count, [4] s32, initialized = false);
    for i: 0..uniform.int4n.count - 1 {
        uniform.int4n[i][0] = xx value[i].x;
        uniform.int4n[i][1] = xx value[i].y;
        uniform.int4n[i][2] = xx value[i].z;
        uniform.int4n[i][3] = xx value[i].w;
    }
    return uniform;
}

create_uniform :: ($name: *u8, value: [4] s64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int4;
    uniform.int4[0] = xx value[0];
    uniform.int4[1] = xx value[1];
    uniform.int4[2] = xx value[2];
    uniform.int4[3] = xx value[3];
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [4] s64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int4N;
    uniform.int4n = NewArray(value.count, [4] s32, initialized = false);
    for i: 0..uniform.int4n.count - 1 {
        uniform.int4n[i][0] = xx value[i][0];
        uniform.int4n[i][1] = xx value[i][1];
        uniform.int4n[i][2] = xx value[i][2];
        uniform.int4n[i][3] = xx value[i][3];
    }
    return uniform;
}

create_uniform :: ($name: *u8, value: [4] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int4;
    uniform.int4 = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [4] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int4N;
    uniform.int4n = array_copy(value);
    return uniform;
}

create_uniform :: ($name: *u8, value: u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt1;
    uniform.uint1 = xx value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt1N;
    uniform.uint1n = NewArray(value.count, u32, initialized = false);
    for i: 0..uniform.uint1n.count - 1 {
        uniform.uint1n[i] = xx value[i];
    }
    return uniform;
}

create_uniform :: ($name: *u8, value: u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt1;
    uniform.uint1 = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt1N;
    uniform.uint1n = array_copy(value);
    return uniform;
}

create_uniform :: ($name: *u8, value: [2] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt2;
    uniform.uint2[0] = xx value[0];
    uniform.uint2[1] = xx value[1];
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [2] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt2N;
    uniform.uint2n = NewArray(value.count, u32, initialized = false);
    for i: 0..uniform.uint2n.count - 1 {
        uniform.uint2n[i][0] = xx value[i][0];
        uniform.uint2n[i][1] = xx value[i][1];
    }
    return uniform;
}

create_uniform :: ($name: *u8, value: [2] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt2;
    uniform.uint2 = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [2] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt2N;
    uniform.uint2n = array_copy(value);
    return uniform;
}

create_uniform :: ($name: *u8, value: [3] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt3;
    uniform.uint3[0] = xx value[0];
    uniform.uint3[1] = xx value[1];
    uniform.uint3[2] = xx value[2];
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [3] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt3N;
    uniform.uint3n = NewArray(value.count, u32, initialized = false);
    for i: 0..uniform.uint3n.count - 1 {
        uniform.uint3n[i][0] = xx value[i][0];
        uniform.uint3n[i][1] = xx value[i][1];
        uniform.uint3n[i][2] = xx value[i][2];
    }
    return uniform;
}

create_uniform :: ($name: *u8, value: [3] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt3;
    uniform.uint3 = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [3] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt3N;
    uniform.uint3n = array_copy(value);
    return uniform;
}

create_uniform :: ($name: *u8, value: [4] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt4;
    uniform.uint4[0] = xx value[0];
    uniform.uint4[1] = xx value[1];
    uniform.uint4[2] = xx value[2];
    uniform.uint4[3] = xx value[3];
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [4] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt4N;
    uniform.uint4n = NewArray(value.count, u32, initialized = false);
    for i: 0..uniform.uint4n.count - 1 {
        uniform.uint4n[i][0] = xx value[i][0];
        uniform.uint4n[i][1] = xx value[i][1];
        uniform.uint4n[i][2] = xx value[i][2];
        uniform.uint4n[i][3] = xx value[i][3];
    }
    return uniform;
}

create_uniform :: ($name: *u8, value: [4] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt4;
    uniform.uint4 = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] [4] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt4N;
    uniform.uint4n = array_copy(value);
    return uniform;
}

create_uniform :: ($name: *u8, value: Matrix2) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Mat2;
    uniform.mat2 = value.floats;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] Matrix2) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Mat2N;
    uniform.mat2n = array_copy_memory(value, [4] float);
    return uniform;
}

create_uniform :: ($name: *u8, value: Matrix3) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Mat3;
    uniform.mat3 = value.floats;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] Matrix3) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Mat3N;
    uniform.mat3n = array_copy_memory(value, [9] float);
    return uniform;
}

create_uniform :: ($name: *u8, value: Matrix4) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Mat4;
    uniform.mat4 = value.floats;
    return uniform;
}

create_uniform :: ($name: *u8, value: [] Matrix4) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Mat4N;
    uniform.mat4n = array_copy_memory(value, [16] float);
    return uniform;
}

create_uniform :: ($name: *u8, value: Texture) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Texture;
    uniform.texture = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: TextureArray) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .TextureArray;
    uniform.texture_array = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: Texture3) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Texture3;
    uniform.texture3 = value;
    return uniform;
}

create_uniform :: ($name: *u8, value: CubemapTexture) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .CubemapTexture;
    uniform.cubemap_texture = value;
    return uniform;
}

// this apparently doesnt work, you have to use a texture2darray or a texture3d depending on how you want it to function
// create_uniform :: ($name: *u8, value: [] Texture) -> ShaderUniform {
//     uniform: ShaderUniform;
//     uniform.name = name;
//     uniform.type = .TextureN;
//     uniform.uint1n = NewArray(value.count, u32, initialized = false);
//     for i: 0..value.count - 1 {
//         uniform.uint1n[i] = value[i].buffer;
//     }
//     return uniform;
// }

destroy :: (uniforms: ShaderUniforms) {
    for uniform: uniforms.uniforms {
        if uniform.ownership {
            destroy(uniform);
        }
    }
    array_free(uniforms.uniforms);
}

destroy :: (uniform: ShaderUniform) {
    if uniform.type == {
        case .Float1N;
            array_free(uniform.float1n);
        case .Float2N;
            array_free(uniform.float2n);
        case .Float3N;
            array_free(uniform.float3n);
        case .Float4N;
            array_free(uniform.float4n);
        case .Int1N;
            array_free(uniform.int1n);
        case .Int2N;
            array_free(uniform.int2n);
        case .Int3N;
            array_free(uniform.int3n);
        case .Int4N;
            array_free(uniform.int4n);
        case .UInt1N;
            array_free(uniform.uint1n);
        case .UInt2N;
            array_free(uniform.uint2n);
        case .UInt3N;
            array_free(uniform.uint3n);
        case .UInt4N;
            array_free(uniform.uint4n);
        case .Mat2N;
            array_free(uniform.mat2n);
        case .Mat3N;
            array_free(uniform.mat3n);
        case .Mat4N;
            array_free(uniform.mat4n);
    }
}

#scope_file

array_copy_memory :: (arr: [] $T, $N: Type) -> [] N {
    SIZE_T :: #run size_of(T);
    #run assert(#run size_of(T) == size_of(N), "The types must be the same size.");

    copied := NewArray(arr.count, N, initialized = false);
    memcpy(copied.data, arr.data, arr.count * SIZE_T);
    return copied;
}
