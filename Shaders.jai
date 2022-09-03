Shader :: struct {
    vertex: string;
    fragment: string;
    uniforms: [..] ShaderUniform;
    program: GLuint;
}

ShaderUniform :: struct {
    name: string;
    location: GLint;
    type: Type;
    data: *void;
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
    return a.vertex == b.vertex && a.fragment == b.fragment;
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
    for uniform: shader.uniforms {
        free(uniform.name);
    }
    glDeleteProgram(shader.program);
}

get_uniform :: (shader: Shader, name: string, data: *$T) #modify modify_require_shader_uniform(T) {
    uniform := get_uniform(shader, name);
    if !uniform {
        return;
    }

    if uniform.type != T {
        print("Shader uniform of different type. % %\n", uniform.type, T);
        return;
    }

    #if #run T == u32 {
        memcpy(data, uniform.data, size_of(u32));
    } else #if #run T == s32 {
        memcpy(data, uniform.data, size_of(s32));
    } else #if #run T == Vector2 {
        memcpy(data, uniform.data, size_of(Vector2));
    } else #if #run T == Vector3 {
        memcpy(data, uniform.data, size_of(Vector3));
    } else #if #run T == Vector4 {
        memcpy(data, uniform.data, size_of(Vector4));
    } else #if #run T == Point2 {
        memcpy(data, uniform.data, size_of(Point2));
    } else #if #run T == Point3 {
        memcpy(data, uniform.data, size_of(Point3));
    } else #if #run T == Point4 {
        memcpy(data, uniform.data, size_of(Point4));
    } else #if #run T == Color {
        memcpy(data, uniform.data, size_of(Color));
    } else #if #run T == Matrix2 {
        memcpy(data, uniform.data, size_of(Matrix2));
    } else #if #run T == Matrix3 {
        memcpy(data, uniform.data, size_of(Matrix3));
    } else #if #run T == Matrix4 {
        memcpy(data, uniform.data, size_of(Matrix4));
    } else #if #run is_fixed_array_of_type(T, Vector3) {
        array_count :: #run get_fixed_array_count(T);
        memcpy(data, uniform.data, size_of(Vector3) * array_count);
    } else {
        print("Shader uniform unhandled type. %\n", T);
        assert(false, "Shader uniform unhandled type.");
    }
}

set_uniform :: (shader: *Shader, name: string, data: $T) #modify modify_require_shader_uniform(T) {
    if !shader.program {
        initialize_shader(shader);
    }

    if !shader.program {
        return;
    }

    uniform := get_uniform(shader, name);
    if !uniform {
        location := glGetUniformLocation(shader.program, temp_c_string(name));
        if location == -1 {
            return;
        }

        uniform = array_add(*shader.uniforms);
        uniform.location = location;
        uniform.name = copy_string(name);
        uniform.type = T;
        uniform.data = alloc(size_of(T));
    }

    #if #run T == u32 {
        memcpy(uniform.data, *data, size_of(u32));
    } else #if #run T == u64 {
        memcpy(uniform.data, *data, size_of(u64));
    } else #if #run T == s32 {
        memcpy(uniform.data, *data, size_of(s32));
    } else #if #run T == s64 {
        memcpy(uniform.data, *data, size_of(s64));
    } else #if #run T == float32 {
        memcpy(uniform.data, *data, size_of(float32));
    } else #if #run T == float64 {
        memcpy(uniform.data, *data, size_of(float64));
    } else #if #run T == Vector2 {
        memcpy(uniform.data, *data, size_of(Vector2));
    } else #if #run T == Vector3 {
        memcpy(uniform.data, *data, size_of(Vector3));
    } else #if #run T == Vector4 {
        memcpy(uniform.data, *data, size_of(Vector4));
    } else #if #run T == Point2 {
        memcpy(uniform.data, *data, size_of(Point2));
    } else #if #run T == Point3 {
        memcpy(uniform.data, *data, size_of(Point3));
    } else #if #run T == Point4 {
        memcpy(uniform.data, *data, size_of(Point4));
    } else #if #run T == Color {
        memcpy(uniform.data, *data, size_of(Color));
    } else #if #run T == Matrix2 {
        memcpy(uniform.data, *data, size_of(Matrix2));
    } else #if #run T == Matrix3 {
        memcpy(uniform.data, *data, size_of(Matrix3));
    } else #if #run T == Matrix4 {
        memcpy(uniform.data, *data, size_of(Matrix4));
    } else #if #run is_fixed_array_of_type(T, Vector3) {
        count :: #run get_fixed_array_count(T);
        memcpy(uniform.data, *data, size_of(Vector3) * count);
    } else {
        print("Shader uniform unhandled type. %\n", T);
        assert(false, "Shader uniform unhandled type.");
    }

    if koda.active_program == shader.program {
        apply_uniform(uniform.location, data);
    }
}

use_shader :: (shader: *Shader) {
    if koda.active_program == shader.program {
        return;
    }

    if !shader.program {
        initialize_shader(shader);

        if !shader.program {
            print("Cannot use shader. You must initialized it first.\n");
            assert(false, "Cannot used initialized shader.");
            return;
        }
    }

    glUseProgram(shader.program);
    koda.active_program = shader.program;

    for uniform: shader.uniforms {
        apply_uniform(uniform.location, uniform.data, uniform.type);
    }
}

#scope_file

is_fixed_array_of_type :: (array_type: Type, type: Type) -> bool {
    potential_array_info := cast(*Type_Info) array_type;
    if potential_array_info.type == .ARRAY {
        array_info := cast(*Type_Info_Array) potential_array_info;
        array_type := << cast(*Type) *array_info.element_type;

        if array_info.array_type == .FIXED && array_type == type {
            return true;
        } else {
            return false;
        }
    } else {
        return false;
    }
}

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

get_fixed_array_count :: (type: Type) -> int {
    array_info := cast(*Type_Info_Array) type;
    return array_info.array_count;
}

// get_fixed_array_count :: ($type: Type) -> int {
//     array_info :: cast(*Type_Info_Array) type;
//     return array_info.array_count;
// }

get_uniform :: (shader: *Shader, name: string) -> *ShaderUniform {
    for i: 0..shader.uniforms.count - 1 {
        if shader.uniforms[i].name == name {
            return *shader.uniforms[i];
        }
    }

    return null;
}

get_uniform :: (shader: Shader, name: string) -> ShaderUniform, bool #must {
    for i: 0..shader.uniforms.count - 1 {
        if shader.uniforms[i].name == name {
            return shader.uniforms[i], true;
        }
    }

    return .{}, false;
}

apply_uniform :: (location: GLint, data: *void, type: Type) {
    if type == u32 {
        value := << cast(*u32) data;
        apply_uniform(location, value);
    } else if type == u64 {
        value := << cast(*u64) data;
        apply_uniform(location, value);
    } else if type == s32 {
        value := << cast(*s32) data;
        apply_uniform(location, value);
    } else if type == s64 {
        value := << cast(*s64) data;
        apply_uniform(location, value);
    } else if type == float32 {
        value := << cast(*float32) data;
        apply_uniform(location, value);
    } else if type == float64 {
        value := << cast(*float64) data;
        apply_uniform(location, value);
    } else if type == Vector2 {
        value := << cast(*Vector2) data;
        apply_uniform(location, value);
    } else if type == Vector3 {
        value := << cast(*Vector3) data;
        apply_uniform(location, value);
    } else if type == Vector4 {
        value := << cast(*Vector4) data;
        apply_uniform(location, value);
    } else if type == Point2 {
        value := << cast(*Point2) data;
        apply_uniform(location, value);
    } else if type == Point3 {
        value := << cast(*Point3) data;
        apply_uniform(location, value);
    } else if type == Point4 {
        value := << cast(*Point4) data;
        apply_uniform(location, value);
    } else if type == Color {
        value := << cast(*Color) data;
        apply_uniform(location, value);
    } else if type == Matrix2 {
        value := << cast(*Matrix2) data;
        apply_uniform(location, value);
    } else if type == Matrix3 {
        value := << cast(*Matrix3) data;
        apply_uniform(location, value);
    } else if type == Matrix4 {
        value := << cast(*Matrix4) data;
        apply_uniform(location, value);
    } else if is_fixed_array_of_type(type, Vector3) {
        count := get_fixed_array_count(type);
        value := cast(*Vector3) data;
        apply_array_uniform(location, value, xx count);
    } else {
        print("Shader uniform unhandled type. %\n", type);
        assert(false, "Shader uniform unhandled type.");
    }
}

apply_array_uniform :: (location: GLint, value: *$T, count: u32) #modify modify_require_shader_uniform(T) {
    #if #run T == u32 {
        glUniform1uiv(location, count, value);
    } else #if #run T == u64 {
        assert(false, "u64 not supported for array uniform types.");
    } else #if #run T == s32 {
        glUniform1iv(location, count, value);
    } else #if #run T == s64 {
        assert(false, "s64 not supported for array uniform types.");
    } else #if #run T == float32 {
        glUniform1fv(location, count, value);
    } else #if #run T == Vector2 {
        glUniform2fv(location, count, cast(*float) *value);
    } else #if #run T == Vector3 {
        glUniform3fv(location, count, cast(*float) *value);
    } else #if #run T == Vector4 {
        glUniform4fv(location, count, cast(*float) *value);
    } else #if #run T == Point2 {
        glUniform2iv(location, count, cast(*s32) *value);
    } else #if #run T == Point3 {
        glUniform3iv(location, count, cast(*s32) *value);
    } else #if #run T == Point4 {
        glUniform4iv(location, count, cast(*s32) *value);
    } else #if #run T == Color {
        glUniform4fv(location, count, cast(*float) *value);
    } else #if #run T == Matrix2 {
        glUniformMatrix2fv(location, count, true, cast(*float) *value);
    } else #if #run T == Matrix3 {
        glUniformMatrix3fv(location, count, true, cast(*float) *value);
    } else #if #run T == Matrix4 {
        glUniformMatrix4fv(location, count, true, cast(*float) *value);
    } else {
        print("Shader uniform array unhandled type. %\n", T);
        assert(false, "Shader uniform array unhandled type.");
    }
}

apply_uniform :: (location: GLint, value: $T) #modify modify_require_shader_uniform(T) {
    #if #run T == u32 {
        glUniform1ui(location, value);
    } else #if #run T == u64 {
        glUniform1ui(location, cast(u32) value);
    } else #if #run T == s32 {
        glUniform1i(location, value);
    } else #if #run T == s64 {
        glUniform1i(location, cast(s32) value);
    } else #if #run T == float32 {
        glUniform1f(location, value);
    } else #if #run T == float64 {
        glUniform1f(location, cast(float32) value);
    } else #if #run T == Vector2 {
        glUniform2fv(location, 1, cast(*float) *value);
    } else #if #run T == Vector3 {
        glUniform3fv(location, 1, cast(*float) *value);
    } else #if #run T == Vector4 {
        glUniform4fv(location, 1, cast(*float) *value);
    } else #if #run T == Point2 {
        glUniform2iv(location, 1, cast(*s32) *value);
    } else #if #run T == Point3 {
        glUniform3iv(location, 1, cast(*s32) *value);
    } else #if #run T == Point4 {
        glUniform4iv(location, 1, cast(*s32) *value);
    } else #if #run T == Color {
        glUniform4fv(location, 1, cast(*float) *value);
    } else #if #run T == Matrix2 {
        glUniformMatrix2fv(location, 1, true, cast(*float) *value);
    } else #if #run T == Matrix3 {
        glUniformMatrix3fv(location, 1, true, cast(*float) *value);
    } else #if #run T == Matrix4 {
        glUniformMatrix4fv(location, 1, true, cast(*float) *value);
    } else {
        print("Shader uniform unhandled type. %\n", T);
        assert(false, "Shader uniform unhandled type.");
    }
}

modify_require_shader_uniform :: (t: Type) #expand {
    // TODO try just converting s64 to s32 and u64 to u32 here and see if itll auto cast
    if t == u8 {
        `return false, "u8 isn't supported.";
    } else if t == u16 {
        `return false, "u16 isn't supported.";
    } else if t == u32 {
        `return true;
    } else if t == u64 {
        `return true;
    } else if t == s8 {
        `return false, "s8 isn't supported.";
    } else if t == s16 {
        `return false, "s16 isn't supported.";
    } else if t == s32 {
        `return true;
    } else if t == s64 {
        `return true;
    } else if t == float32 {
        `return true;
    } else if t == float64 {
        `return true;
    } else if t == Vector2 {
        `return true;
    } else if t == Vector3 {
        `return true;
    } else if t == Vector4 {
        `return true;
    } else if t == Point2 {
        `return true;
    } else if t == Point3 {
        `return true;
    } else if t == Point4 {
        `return true;
    } else if t == Color {
        `return true;
    } else if t == Matrix2 {
        `return true;
    } else if t == Matrix3 {
        `return true;
    } else if t == Matrix4 {
        `return true;
    } else if is_fixed_array_of_type(t, Vector3) {
        `return true;
    }

    `print("Data type not supported or implemented. %\n", t);
    `return false, "Data type not supported or implemented.";
}

#import "Basic";