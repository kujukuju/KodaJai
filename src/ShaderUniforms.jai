
UNIFORM_LENGTH :: 32;

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
    ShadowTexture;
}

ShaderUniform :: struct {
    name: FixedString(UNIFORM_LENGTH);
    ownership: bool = true;
    type: ShaderUniformType;
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
        shadow_texture: Texture;
    }
}

ShaderUniforms :: struct {
    fixed: [16] ShaderUniform = ---;
    fixed_count: int;
    uniforms: [..] ShaderUniform;
}


for_expansion :: (uniforms: *ShaderUniforms, body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .REVERSE));

    for i: 0..get_count(uniforms) - 1 {
        #if flags & .POINTER {
            `it: *ShaderUniform = *(uniforms.*[i]);
        } else {
            `it: ShaderUniform = uniforms.*[i];
        }

        `it_index := i;

        #insert body;
    }
}

operator [] :: (uniforms: ShaderUniforms, index: int) -> ShaderUniform {
    if uniforms.uniforms.data {
        return uniforms.uniforms[index];
    } else {
        return uniforms.fixed[index];
    }
}

operator *[] :: (uniforms: *ShaderUniforms, index: int) -> *ShaderUniform {
    if uniforms.uniforms.data {
        return *uniforms.uniforms[index];
    } else {
        return *uniforms.fixed[index];
    }
}

equals :: (a: ShaderUniforms, b: ShaderUniforms) -> bool {
    if get_count(a) != get_count(b) {
        return false;
    }

    for i: 0..get_count(a) - 1 {
        a_copy := a[i];
        a_copy.ownership = false;

        b_copy := b[i];
        b_copy.ownership = false;

        if memcmp(*a_copy, *b_copy, size_of(ShaderUniform)) != 0 {
            return false;
        }
    }

    return true;
}

get_uniform_type :: (type: u32, size: int) -> ShaderUniformType {
    if size == 1 {
        if type == {
            case GL_FLOAT;
                return .Float1;
            case GL_FLOAT_VEC2;
                return .Float2;
            case GL_FLOAT_VEC3;
                return .Float3;
            case GL_FLOAT_VEC4;
                return .Float4;
            case GL_INT;
                return .Int1;
            case GL_INT_VEC2;
                return .Int2;
            case GL_INT_VEC3;
                return .Int3;
            case GL_INT_VEC4;
                return .Int4;
            case GL_UNSIGNED_INT;
                return .UInt1;
            case GL_UNSIGNED_INT_VEC2;
                return .UInt2;
            case GL_UNSIGNED_INT_VEC3;
                return .UInt3;
            case GL_UNSIGNED_INT_VEC4;
                return .UInt4;
            case GL_FLOAT_MAT2;
                return .Mat2;
            case GL_FLOAT_MAT3;
                return .Mat3;
            case GL_FLOAT_MAT4;
                return .Mat4;
            case GL_SAMPLER_2D;
                return .Texture;
            case GL_SAMPLER_2D_ARRAY;
                return .TextureArray;
            case GL_SAMPLER_3D;
                return .Texture3;
            case GL_SAMPLER_CUBE;
                return .CubemapTexture;
            case GL_SAMPLER_2D_SHADOW;
                return .ShadowTexture;
        }
    } else {
        if type == {
            case GL_FLOAT;
                return .Float1N;
            case GL_FLOAT_VEC2;
                return .Float2N;
            case GL_FLOAT_VEC3;
                return .Float3N;
            case GL_FLOAT_VEC4;
                return .Float4N;
            case GL_INT;
                return .Int1N;
            case GL_INT_VEC2;
                return .Int2N;
            case GL_INT_VEC3;
                return .Int3N;
            case GL_INT_VEC4;
                return .Int4N;
            case GL_UNSIGNED_INT;
                return .UInt1N;
            case GL_UNSIGNED_INT_VEC2;
                return .UInt2N;
            case GL_UNSIGNED_INT_VEC3;
                return .UInt3N;
            case GL_UNSIGNED_INT_VEC4;
                return .UInt4N;
            case GL_FLOAT_MAT2;
                return .Mat2N;
            case GL_FLOAT_MAT3;
                return .Mat3N;
            case GL_FLOAT_MAT4;
                return .Mat4N;
        }
    }

    assert(false, "Unknown uniform type. % %\n", type, size);
    return .Float1;
}

get_count :: (uniforms: ShaderUniforms) -> int {
    if uniforms.uniforms.data {
        return uniforms.uniforms.count;
    }
    return uniforms.fixed_count;
}

copy :: (uniforms: ShaderUniforms) -> ShaderUniforms {
    copied: ShaderUniforms;

    if uniforms.uniforms.data {
        array_copy(*copied.uniforms, uniforms.uniforms);
    } else {
        copied.fixed = uniforms.fixed;
        copied.fixed_count = uniforms.fixed_count;
    }

    return copied;
}

// operator == :: (a: ShaderUniforms, b: ShaderUniforms) -> bool {
//     return a.uniforms.data == b.uniforms.data;
// }

get :: (uniforms: *ShaderUniforms, name: FixedString(UNIFORM_LENGTH)) -> *ShaderUniform {
    for *uniform: uniforms {
        if uniform.name == name {
            return uniform;
        }
    }

    return null;
}

get :: (uniforms: *ShaderUniforms, name: string) -> *ShaderUniform {
    assert(name.count <= UNIFORM_LENGTH, "Cannot have uniforms with more than % characters.\n", UNIFORM_LENGTH);
    for *uniform: uniforms {
        if uniform.name == name {
            return uniform;
        }
    }

    return null;
}

set :: (uniforms: *ShaderUniforms, created: ShaderUniform) {
    for i: 0..get_count(uniforms) - 1 {
        if uniforms.*[i].name == created.name {
            if uniforms.*[i].ownership {
                destroy(uniforms.*[i]);
            }
            uniforms.*[i] = created;
            return;
        }
    }

    if uniforms.uniforms.data {
        array_add(*uniforms.uniforms, created);
    } else if uniforms.fixed_count == uniforms.fixed.count {
        array_reserve(*uniforms.uniforms, uniforms.fixed.count * 2);
        array_add(*uniforms.uniforms, ..uniforms.fixed);
        array_add(*uniforms.uniforms, created);
    } else {
        uniforms.fixed[uniforms.fixed_count] = created;
        uniforms.fixed_count += 1;
    }
}

set :: (uniforms: *ShaderUniforms, name: string, value: $T) {
    assert(name.count <= UNIFORM_LENGTH, "Cannot have uniforms with more than % characters.\n", UNIFORM_LENGTH);
    set(uniforms, create_fixed_string(name, UNIFORM_LENGTH), value);
}

set :: (uniforms: *ShaderUniforms, name: FixedString(UNIFORM_LENGTH), value: $T) {
    created := create_uniform(name, value);
    set(uniforms, created);
}

has_uniform :: (uniforms: ShaderUniforms, name: string) -> bool {
    for i: 0..get_count(uniforms) - 1 {
        if to_string(*uniforms[i].name) == name {
            return true;
        }
    }

    return false;
}

create_uniform :: (name: string, value: $T) -> ShaderUniform {
    return create_uniform(create_fixed_string(name, UNIFORM_LENGTH), value);
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float1;
    uniform.float1 = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float1N;
    uniform.float1n = array_copy(value);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [2] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float2;
    uniform.float2 = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [2] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float2N;
    uniform.float2n = array_copy(value);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: Vector2) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float2;
    uniform.float2 = value.component;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] Vector2) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float2N;
    uniform.float2n = array_copy_memory(value, [2] float);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: Vector3) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float3;
    uniform.float3 = value.component;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] Vector3) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float3N;
    uniform.float3n = array_copy_memory(value, [3] float);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [3] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float3;
    uniform.float3 = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [3] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float3N;
    uniform.float3n = array_copy(value);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: Vector4) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float4;
    uniform.float4 = value.component;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] Vector4) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float4N;
    uniform.float4n = array_copy_memory(value, [4] float);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: Color) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float4;
    uniform.float4 = value.component;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] Color) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float4N;
    uniform.float4n = array_copy_memory(value, [4] float);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [4] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float4;
    uniform.float4 = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [4] float) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Float4N;
    uniform.float4n = array_copy(value);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: s64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int1;
    uniform.int1 = xx value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] s64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int1N;
    uniform.int1n = NewArray(value.count, s32, initialized = false);
    for i: 0..uniform.int1n.count - 1 {
        uniform.int1n[i] = xx value[i];
    }
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int1;
    uniform.int1 = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int1N;
    uniform.int1n = array_copy(value);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: Point2) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int2;
    uniform.int2[0] = xx value.x;
    uniform.int2[1] = xx value.y;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] Point2) -> ShaderUniform {
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

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [2] s64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int2;
    uniform.int2[0] = xx value[0];
    uniform.int2[1] = xx value[1];
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [2] s64) -> ShaderUniform {
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

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [2] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int2;
    uniform.int2 = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [2] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int2N;
    uniform.int2n = array_copy(value);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: Point3) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int3;
    uniform.int3[0] = xx value.x;
    uniform.int3[1] = xx value.y;
    uniform.int3[2] = xx value.z;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] Point3) -> ShaderUniform {
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

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [3] s64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int3;
    uniform.int3[0] = xx value[0];
    uniform.int3[1] = xx value[1];
    uniform.int3[2] = xx value[2];
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [3] s64) -> ShaderUniform {
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

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [3] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int3;
    uniform.int3 = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [3] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int3N;
    uniform.int3n = array_copy(value);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: Point4) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int4;
    uniform.int4 = .[cast(s32) value.x, cast(s32) value.y, cast(s32) value.z, cast(s32) value.w];
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] Point4) -> ShaderUniform {
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

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [4] s64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int4;
    uniform.int4[0] = xx value[0];
    uniform.int4[1] = xx value[1];
    uniform.int4[2] = xx value[2];
    uniform.int4[3] = xx value[3];
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [4] s64) -> ShaderUniform {
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

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [4] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int4;
    uniform.int4 = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [4] s32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Int4N;
    uniform.int4n = array_copy(value);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt1;
    uniform.uint1 = xx value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt1N;
    uniform.uint1n = NewArray(value.count, u32, initialized = false);
    for i: 0..uniform.uint1n.count - 1 {
        uniform.uint1n[i] = xx value[i];
    }
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt1;
    uniform.uint1 = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt1N;
    uniform.uint1n = array_copy(value);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [2] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt2;
    uniform.uint2[0] = xx value[0];
    uniform.uint2[1] = xx value[1];
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [2] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt2N;
    uniform.uint2n = NewArray(value.count, [2] u32, initialized = false);
    for i: 0..uniform.uint2n.count - 1 {
        uniform.uint2n[i][0] = xx value[i][0];
        uniform.uint2n[i][1] = xx value[i][1];
    }
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [2] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt2;
    uniform.uint2 = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [2] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt2N;
    uniform.uint2n = array_copy(value);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [3] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt3;
    uniform.uint3[0] = xx value[0];
    uniform.uint3[1] = xx value[1];
    uniform.uint3[2] = xx value[2];
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [3] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt3N;
    uniform.uint3n = NewArray(value.count, [3] u32, initialized = false);
    for i: 0..uniform.uint3n.count - 1 {
        uniform.uint3n[i][0] = xx value[i][0];
        uniform.uint3n[i][1] = xx value[i][1];
        uniform.uint3n[i][2] = xx value[i][2];
    }
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [3] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt3;
    uniform.uint3 = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [3] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt3N;
    uniform.uint3n = array_copy(value);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [4] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt4;
    uniform.uint4[0] = xx value[0];
    uniform.uint4[1] = xx value[1];
    uniform.uint4[2] = xx value[2];
    uniform.uint4[3] = xx value[3];
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [4] u64) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt4N;
    uniform.uint4n = NewArray(value.count, [4] u32, initialized = false);
    for i: 0..uniform.uint4n.count - 1 {
        uniform.uint4n[i][0] = xx value[i][0];
        uniform.uint4n[i][1] = xx value[i][1];
        uniform.uint4n[i][2] = xx value[i][2];
        uniform.uint4n[i][3] = xx value[i][3];
    }
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [4] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt4;
    uniform.uint4 = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] [4] u32) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .UInt4N;
    uniform.uint4n = array_copy(value);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: Matrix2) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Mat2;
    uniform.mat2 = value.floats;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] Matrix2) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Mat2N;
    uniform.mat2n = array_copy_memory(value, [4] float);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: Matrix3) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Mat3;
    uniform.mat3 = value.floats;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] Matrix3) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Mat3N;
    uniform.mat3n = array_copy_memory(value, [9] float);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: Matrix4) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Mat4;
    uniform.mat4 = value.floats;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: [] Matrix4) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Mat4N;
    uniform.mat4n = array_copy_memory(value, [16] float);
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: Texture) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    // TODO implies shadow texture needs its own type
    uniform.type = ifx value.shadow then .ShadowTexture else .Texture;
    uniform.texture = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: TextureArray) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .TextureArray;
    uniform.texture_array = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: Texture3) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .Texture3;
    uniform.texture3 = value;
    return uniform;
}

create_uniform :: (name: FixedString(UNIFORM_LENGTH), value: CubemapTexture) -> ShaderUniform {
    uniform: ShaderUniform;
    uniform.name = name;
    uniform.type = .CubemapTexture;
    uniform.cubemap_texture = value;
    return uniform;
}

// this apparently doesnt work, you have to use a texture2darray or a texture3d depending on how you want it to function
// create_uniform :: (name: string, value: [] Texture) -> ShaderUniform {
//     uniform: ShaderUniform;
//     uniform.name = create_fixed_string(name, 64);
//     uniform.type = .TextureN;
//     uniform.uint1n = NewArray(value.count, u32, initialized = false);
//     for i: 0..value.count - 1 {
//         uniform.uint1n[i] = value[i].buffer;
//     }
//     return uniform;
// }

destroy :: (uniforms: ShaderUniforms) {
    for uniform: uniforms {
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
