Shader :: struct {
    vertex: string;
    fragment: string;
    uniforms: [..] ShaderUniform;
    active_: bool;
    program_: GLuint;
}

ShaderUniform :: struct {
    name: string;
    location: GLint;
    type: Type;
    data: *void;
}

operator == :: (a: Shader, b: Shader) -> bool {
    return a.vertex == b.vertex && a.fragment == b.fragment;
}

initialize_shader :: (shader: *Shader) {
    if shader.program_ > 0 {
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
    shader.program_ = glCreateProgram();

    if !success_v || !success_f || !shader.program_ {
        shader.program_ = 0;
        print("Failure initalizing shader.\n");
        assert(false, "Failure initializing shader.");
    }

    glAttachShader(shader.program_, shader_v);
    glAttachShader(shader.program_, shader_f);
    glLinkProgram(shader.program_);

    success: GLint;
    glGetProgramiv(shader.program_, GL_LINK_STATUS, *success);

    if !success {
        shader.program_ = 0;
        message: [512] u8;
        glGetProgramInfoLog(shader.program_, 512, null, message.data);
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
    glDeleteProgram(shader.program_);
}

get_uniform :: (shader: *Shader, name: string, data: *$T) #modify modify_require_shader_uniform(T) {
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
    } else {
        print("Shader uniform unhandled type. %\n", T);
        assert(false, "Shader uniform unhandled type.");
    }
}

set_uniform :: (shader: *Shader, name: string, data: $T) #modify modify_require_shader_uniform(T) {
    if !shader.program_ {
        initialize_shader(shader);
    }

    if !shader.program_ {
        return;
    }

    uniform := get_uniform(shader, name);
    if !uniform {
        location := glGetUniformLocation(shader.program_, temp_c_string(name));
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
    } else {
        print("Shader uniform unhandled type. %\n", T);
        assert(false, "Shader uniform unhandled type.");
    }

    if koda.active_program == shader.program_ {
        apply_uniform(uniform.location, data);
    }
}

use_shader :: (shader: Shader) {
    if koda.active_program == shader.program_ {
        return;
    }

    if !shader.program_ {
        print("Cannot use shader. You must initialized it first.\n");
        assert(false, "Cannot used initialized shader.");
        return;
    }

    glUseProgram(shader.program_);
    koda.active_program = shader.program_;

    for uniform: shader.uniforms {
        apply_uniform(uniform.location, uniform.data, uniform.type);
    }
}

#scope_file

get_uniform :: (shader: *Shader, name: string) -> *ShaderUniform {
    for i: 0..shader.uniforms.count - 1 {
        if shader.uniforms[i].name == name {
            return *shader.uniforms[i];
        }
    }

    return null;
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
    } else {
        print("Shader uniform unhandled type. %\n", type);
        assert(false, "Shader uniform unhandled type.");
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
    }

    `return false, "Data type not supported or implemented.";
}

#import "Basic";