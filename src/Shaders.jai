
// TODO for now I'm just calling glGetUniformLocation every time, but I probably shouldnt be
Shader :: struct {
    program: u32;
    vertex: string;
    fragment: string;
    uniforms: ShaderUniforms;
}

// TODO I need to auto create shaders with all their uniforms and defaults
// TODO then I can allow textures in passes to have uniform names, and assign them like
/*

GLint baseImageLoc = glGetUniformLocation(program, "baseImage");
GLint normalMapLoc = glGetUniformLocation(program, "normalMap");
GLint shadowMapLoc = glGetUniformLocation(program, "shadowMap");

glUseProgram(program);
glUniform1i(baseImageLoc, 0); // Texture unit 0 is for base images.
glUniform1i(normalMapLoc, 2); // Texture unit 2 is for normal maps.
glUniform1i(shadowMapLoc, 4); // Texture unit 4 is for shadow maps.

// When rendering an object with this program.
glActiveTexture(GL_TEXTURE0 + 0);
glBindTexture(GL_TEXTURE_2D, object1BaseImage);
glBindSampler(0, linearFiltering);
glActiveTexture(GL_TEXTURE0 + 2);
glBindTexture(GL_TEXTURE_2D, object1NormalMap);
glBindSampler(2, linearFiltering); // Same filtering as before
glActiveTexture(GL_TEXTURE0 + 4);
glBindTexture(GL_TEXTURE_2D, shadowMap);
glBindSampler(4, depthComparison); // Special sampler for depth comparisons.

*/

operator == :: (a: Shader, b: Shader) -> bool {
    return a.vertex.data == b.vertex.data && a.fragment.data == b.fragment.data;
}

initialize_shader :: (shader: *Shader) {
    if shader.program > 0 {
        return;
    }

    make_shader_object :: (shader: string, shader_type: GLenum) -> GLuint, bool #must {
        shader_object := glCreateShader(shader_type);

		length: GLint = xx shader.count;
        glShaderSource(shader_object, 1, *shader.data, *length);
        glCompileShader(shader_object);

        success: GLint;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);

        if !success {
            message: [512] u8;
            glGetShaderInfoLog(shader_object, 512, null, message.data);
            print("Shader compile error: %\n", to_string(message.data));
            return 0, false;
        }

        return shader_object, true;
    }

    shader_v, success_v := make_shader_object(shader.vertex, GL_VERTEX_SHADER);
    defer glDeleteShader(shader_v);
    if !success_v {
        print("Could not initialized vertex shader.\n");
    }
    shader_f, success_f := make_shader_object(shader.fragment, GL_FRAGMENT_SHADER);
    defer glDeleteShader(shader_f);
    if !success_f {
        print("Could not initialized fragment shader.\n");
    }
    shader.program = glCreateProgram();

    if !success_v || !success_f || !shader.program {
        shader.program = 0;
        print("Failure initalizing shader.\n");
        assert(false, "Failure initializing shader.");
    }

    glAttachShader(shader.program, shader_v);
    glAttachShader(shader.program, shader_f);
    glLinkProgram(shader.program);

    success: GLint;
    glGetProgramiv(shader.program, GL_LINK_STATUS, *success);

    if !success {
        shader.program = 0;
        message: [512] u8;
        glGetProgramInfoLog(shader.program, 512, null, message.data);
        print("Shader error: %\n", to_string(message.data));
        assert(false, "Shader error.");
    }
}

destroy_shader :: (shader: Shader) {
    free(shader.vertex);
    free(shader.fragment);
    // free(shader.uniforms);
    glDeleteProgram(shader.program);
}

apply_uniforms :: (shader: *Shader, uniforms: ShaderUniforms) {
    for uniform: uniforms.uniforms {
        existing := shader.uniforms[uniform.name];
        shader.uniforms[uniform.name] = uniform;
        
        if existing.name {
            shader.uniforms[uniform.name].location = existing.location;
        }
    }

    print_stack_trace();

    // the uniforms stay in order for the shaders uniforms, so after we apply all the uniforms we can lookup the texture indices by iterating over them in order
    for uniform: uniforms.uniforms {
        texture_index: u32;

        for *shader_uniform: shader.uniforms.uniforms {
            if shader_uniform.location == -1 {
                break;
            }

            if uniform.name == shader_uniform.name {
                // TODO this could be improved if I force uniform names to be less than a certain size, and use fixed strings
                location := glGetUniformLocation(shader.program, temp_c_string(uniform.name));
                print("Shader location is % %\n", uniform.name, location);
                shader_uniform.location = location;
                if location == -1 {
                    break;
                }

                for uniform: uniforms.uniforms {
                    print("Binding % %\n", uniform.name, uniform.type);
                    if #complete uniform.type == {
                        case .Float1;
                            glUniform1f(location, uniform.float1);
                        case .Float1N;
                            glUniform1fv(location, xx uniform.float1n.count, uniform.float1n.data);
                        case .Float2;
                            glUniform2f(location, uniform.float2[0], uniform.float2[1]);
                        case .Float2N;
                            glUniform2fv(location, xx uniform.float2n.count, cast(*float) uniform.float2n.data);
                        case .Float3;
                            glUniform3f(location, uniform.float3[0], uniform.float3[1], uniform.float3[2]);
                        case .Float3N;
                            glUniform3fv(location, xx uniform.float3n.count, cast(*float) uniform.float3n.data);
                        case .Float4;
                            glUniform4f(location, uniform.float4[0], uniform.float4[1], uniform.float4[2], uniform.float4[3]);
                        case .Float4N;
                            glUniform4fv(location, xx uniform.float4n.count, cast(*float) uniform.float4n.data);
                        case .Int1;
                            glUniform1i(location, uniform.int1);
                        case .Int1N;
                            glUniform1iv(location, xx uniform.int1n.count, uniform.int1n.data);
                        case .Int2;
                            glUniform2i(location, uniform.int2[0], uniform.int2[1]);
                        case .Int2N;
                            glUniform2iv(location, xx uniform.int2n.count, cast(*s32) uniform.int2n.data);
                        case .Int3;
                            glUniform3i(location, uniform.int3[0], uniform.int3[1], uniform.int3[2]);
                        case .Int3N;
                            glUniform3iv(location, xx uniform.int3n.count, cast(*s32) uniform.int3n.data);
                        case .Int4;
                            glUniform4i(location, uniform.int4[0], uniform.int4[1], uniform.int4[2], uniform.int4[3]);
                        case .Int4N;
                            glUniform4iv(location, xx uniform.int4n.count, cast(*s32) uniform.int4n.data);
                        case .UInt1;
                            glUniform1ui(location, uniform.uint1);
                        case .UInt1N;
                            glUniform1uiv(location, xx uniform.uint1n.count, uniform.uint1n.data);
                        case .UInt2;
                            glUniform2ui(location, uniform.uint2[0], uniform.uint2[1]);
                        case .UInt2N;
                            glUniform2uiv(location, xx uniform.uint2n.count, cast(*u32) uniform.uint2n.data);
                        case .UInt3;
                            glUniform3ui(location, uniform.uint3[0], uniform.uint3[1], uniform.uint3[2]);
                        case .UInt3N;
                            glUniform3uiv(location, xx uniform.uint3n.count, cast(*u32) uniform.uint3n.data);
                        case .UInt4;
                            glUniform4ui(location, uniform.uint4[0], uniform.uint4[1], uniform.uint4[2], uniform.uint4[3]);
                        case .UInt4N;
                            glUniform4uiv(location, xx uniform.uint4n.count, cast(*u32) uniform.uint4n.data);
                        case .Mat2;
                            glUniformMatrix2fv(location, 1, false, cast(*float) uniform.mat2.data);
                        case .Mat2N;
                            glUniformMatrix2fv(location, xx uniform.mat2n.count, false, cast(*float) uniform.mat2n.data);
                        case .Mat3;
                            glUniformMatrix3fv(location, 1, false, cast(*float) uniform.mat3.data);
                        case .Mat3N;
                            glUniformMatrix3fv(location, xx uniform.mat3n.count, false, cast(*float) uniform.mat3n.data);
                        case .Mat4;
                        print("Value %\n", uniform.mat4);
                            glUniformMatrix4fv(location, 1, false, cast(*float) uniform.mat4.data);
                        case .Mat4N;
                            glUniformMatrix4fv(location, xx uniform.mat4n.count, false, cast(*float) uniform.mat4n.data);
                        case .Texture;
                            glActiveTexture(GL_TEXTURE0 + texture_index);
                            glBindTexture(GL_TEXTURE_2D, uniform.uint1);
                            glUniform1ui(location, texture_index);

                            texture_index += 1;
                        case .TextureN;
                            // TODO no allocations
                            texture_values := NewArray(uniform.uint1n.count, u32, initialized = false);
                            defer array_free(texture_values);

                            for i: 0..uniform.uint1n.count - 1 {
                                glActiveTexture(GL_TEXTURE0 + texture_index);
                                glBindTexture(GL_TEXTURE_2D, uniform.uint1);
                                texture_values[i] = texture_index;

                                texture_index += 1;
                            }
                            glUniform1uiv(location, xx texture_values.count, texture_values.data);
                    }
                }
            } else {
                if shader_uniform.type == {
                    case .Texture;
                        texture_index += 1;
                    case .TextureN;
                        texture_index += cast(u32) shader_uniform.uint1n.count;
                }
            }
        }
    }

    // TODO is it important to set back glActiveTexture(GL_TEXTURE0); here?
}

use_shader :: (shader: *Shader) {
    if !shader.program {
        initialize_shader(shader);

        if !shader.program {
            print("Cannot use shader. You must initialized it first.\n");
            assert(false, "Cannot use uninitialized shader.");
            return;
        }
    }

    if koda.active_program == shader.program {
        return;
    }

    glUseProgram(shader.program);
    koda.active_program = shader.program;
}

#scope_file

// is_fixed_array_of_type :: (array_type: Type, type: Type) -> bool {
//     potential_array_info := cast(*Type_Info) array_type;
//     if potential_array_info.type == .ARRAY {
//         array_info := cast(*Type_Info_Array) potential_array_info;
//         array_type := << cast(*Type) *array_info.element_type;

//         if array_info.array_type == .FIXED && array_type == type {
//             return true;
//         } else {
//             return false;
//         }
//     } else {
//         return false;
//     }
// }

// is_fixed_array_of_type :: ($array_type: Type, $type: Type) -> bool {
//     potential_array_info :: cast(*Type_Info) array_type;
//     #if potential_array_info.type == .ARRAY {
//         array_info :: cast(*Type_Info_Array) potential_array_info;
//         array_type :: << cast(*Type) *array_info.element_type;

//         #if array_info.array_type == .FIXED && array_type == type {
//             return true;
//         } else {
//             return false;
//         }
//     } else {
//         return false;
//     }
// }

// get_fixed_array_count :: (type: Type) -> int {
//     array_info := cast(*Type_Info_Array) type;
//     return array_info.array_count;
// }

// get_fixed_array_count :: ($type: Type) -> int {
//     array_info :: cast(*Type_Info_Array) type;
//     return array_info.array_count;
// }

// get_uniform :: (shader: *Shader, name: string) -> *ShaderUniform {
//     for i: 0..shader.uniforms.count - 1 {
//         if shader.uniforms[i].name == name {
//             return *shader.uniforms[i];
//         }
//     }

//     return null;
// }

// get_uniform :: (shader: Shader, name: string) -> ShaderUniform, bool #must {
//     for i: 0..shader.uniforms.count - 1 {
//         if shader.uniforms[i].name == name {
//             return shader.uniforms[i], true;
//         }
//     }

//     return .{}, false;
// }

// apply_uniform :: (location: GLint, data: *void, type: Type) {
//     if type == u32 {
//         value := << cast(*u32) data;
//         apply_single_uniform(location, value);
//     } else if type == u64 {
//         value := << cast(*u64) data;
//         apply_single_uniform(location, value);
//     } else if type == s32 {
//         value := << cast(*s32) data;
//         apply_single_uniform(location, value);
//     } else if type == s64 {
//         value := << cast(*s64) data;
//         apply_single_uniform(location, value);
//     } else if type == float32 {
//         value := << cast(*float32) data;
//         apply_single_uniform(location, value);
//     } else if type == float64 {
//         value := << cast(*float64) data;
//         apply_single_uniform(location, value);
//     } else if type == Vector2 {
//         value := << cast(*Vector2) data;
//         apply_single_uniform(location, value);
//     } else if type == Vector3 {
//         value := << cast(*Vector3) data;
//         apply_single_uniform(location, value);
//     } else if type == Vector4 {
//         value := << cast(*Vector4) data;
//         apply_single_uniform(location, value);
//     } else if type == Point2 {
//         value := << cast(*Point2) data;
//         apply_single_uniform(location, value);
//     } else if type == Point3 {
//         value := << cast(*Point3) data;
//         apply_single_uniform(location, value);
//     } else if type == Point4 {
//         value := << cast(*Point4) data;
//         apply_single_uniform(location, value);
//     } else if type == Color {
//         value := << cast(*Color) data;
//         apply_single_uniform(location, value);
//     } else if type == Matrix2 {
//         value := << cast(*Matrix2) data;
//         apply_single_uniform(location, value);
//     } else if type == Matrix3 {
//         value := << cast(*Matrix3) data;
//         apply_single_uniform(location, value);
//     } else if type == Matrix4 {
//         value := << cast(*Matrix4) data;
//         apply_single_uniform(location, value);
//     } else if is_fixed_array_of_type(type, Vector2) {
//         count := get_fixed_array_count(type);
//         value := cast(*Vector2) data;
//         apply_array_uniform(location, value, xx count);
//     } else if is_fixed_array_of_type(type, Vector3) {
//         count := get_fixed_array_count(type);
//         value := cast(*Vector3) data;
//         apply_array_uniform(location, value, xx count);
//     } else {
//         print("Shader uniform unhandled type. %\n", type);
//         assert(false, "Shader uniform unhandled type.");
//     }
// }

// apply_array_uniform :: (location: GLint, value: *$T, count: u32) #modify modify_require_shader_uniform(T) {
//     #if #run T == u32 {
//         glUniform1uiv(location, count, value);
//     } else #if #run T == u64 {
//         assert(false, "u64 not supported for array uniform types.");
//     } else #if #run T == s32 {
//         glUniform1iv(location, count, value);
//     } else #if #run T == s64 {
//         assert(false, "s64 not supported for array uniform types.");
//     } else #if #run T == float32 {
//         glUniform1fv(location, count, value);
//     } else #if #run T == Vector2 {
//         glUniform2fv(location, count, cast(*float) value);
//     } else #if #run T == Vector3 {
//         glUniform3fv(location, count, cast(*float) value);
//     } else #if #run T == Vector4 {
//         glUniform4fv(location, count, cast(*float) value);
//     } else #if #run T == Point2 {
//         glUniform2iv(location, count, cast(*s32) value);
//     } else #if #run T == Point3 {
//         glUniform3iv(location, count, cast(*s32) value);
//     } else #if #run T == Point4 {
//         glUniform4iv(location, count, cast(*s32) value);
//     } else #if #run T == Color {
//         glUniform4fv(location, count, cast(*float) value);
//     } else #if #run T == Matrix2 {
//         glUniformMatrix2fv(location, count, true, cast(*float) value);
//     } else #if #run T == Matrix3 {
//         glUniformMatrix3fv(location, count, true, cast(*float) value);
//     } else #if #run T == Matrix4 {
//         glUniformMatrix4fv(location, count, true, cast(*float) value);
//     } else {
//         print("Shader uniform array unhandled type. %\n", T);
//         assert(false, "Shader uniform array unhandled type.");
//     }
// }

// apply_single_uniform :: (location: GLint, value: $T) #modify modify_require_shader_uniform(T) {
//     #if #run T == u32 {
//         glUniform1ui(location, value);
//     } else #if #run T == u64 {
//         glUniform1ui(location, cast(u32) value);
//     } else #if #run T == s32 {
//         glUniform1i(location, value);
//     } else #if #run T == s64 {
//         glUniform1i(location, cast(s32) value);
//     } else #if #run T == float32 {
//         glUniform1f(location, value);
//     } else #if #run T == float64 {
//         glUniform1f(location, cast(float32) value);
//     } else #if #run T == Vector2 {
//         glUniform2fv(location, 1, cast(*float) *value);
//     } else #if #run T == Vector3 {
//         glUniform3fv(location, 1, cast(*float) *value);
//     } else #if #run T == Vector4 {
//         glUniform4fv(location, 1, cast(*float) *value);
//     } else #if #run T == Point2 {
//         glUniform2iv(location, 1, cast(*s32) *value);
//     } else #if #run T == Point3 {
//         glUniform3iv(location, 1, cast(*s32) *value);
//     } else #if #run T == Point4 {
//         glUniform4iv(location, 1, cast(*s32) *value);
//     } else #if #run T == Color {
//         glUniform4fv(location, 1, cast(*float) *value);
//     } else #if #run T == Matrix2 {
//         glUniformMatrix2fv(location, 1, true, cast(*float) *value);
//     } else #if #run T == Matrix3 {
//         glUniformMatrix3fv(location, 1, true, cast(*float) *value);
//     } else #if #run T == Matrix4 {
//         glUniformMatrix4fv(location, 1, true, cast(*float) *value);
//     } else {
//         print("Shader uniform unhandled type. %\n", T);
//         assert(false, "Shader uniform unhandled type.");
//     }
// }

// modify_require_shader_uniform :: (t: Type) #expand {
//     // TODO try just converting s64 to s32 and u64 to u32 here and see if itll auto cast
//     if t == u8 {
//         `return false, "u8 isn't supported.";
//     } else if t == u16 {
//         `return false, "u16 isn't supported.";
//     } else if t == u32 {
//         `return true;
//     } else if t == u64 {
//         `return true;
//     } else if t == s8 {
//         `return false, "s8 isn't supported.";
//     } else if t == s16 {
//         `return false, "s16 isn't supported.";
//     } else if t == s32 {
//         `return true;
//     } else if t == s64 {
//         `return true;
//     } else if t == float32 {
//         `return true;
//     } else if t == float64 {
//         `return true;
//     } else if t == Vector2 {
//         `return true;
//     } else if t == Vector3 {
//         `return true;
//     } else if t == Vector4 {
//         `return true;
//     } else if t == Point2 {
//         `return true;
//     } else if t == Point3 {
//         `return true;
//     } else if t == Point4 {
//         `return true;
//     } else if t == Color {
//         `return true;
//     } else if t == Matrix2 {
//         `return true;
//     } else if t == Matrix3 {
//         `return true;
//     } else if t == Matrix4 {
//         `return true;
//     } else if is_fixed_array_of_type(t, Vector2) {
//         `return true;
//     } else if is_fixed_array_of_type(t, Vector3) {
//         `return true;
//     }

//     `print("Data type not supported or implemented. %\n", t);
//     `return false, "Data type not supported or implemented.";
// }

#import "Basic";