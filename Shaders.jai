Shader :: struct {
    vertex: string;
    fragment: string;
    uniforms: [..] ShaderUniform;
    program_: GLuint;
}

ShaderUniform :: struct {
    name: string;
    location: GLint = -1;
    type: ShaderUniformType;
    data: *void;
    size: int;
}

ShaderUniformType :: enum {
    Invalid;
    F1;
    F2;
    F3;
    F4;
    S1;
    S2;
    S3;
    S4;
    U1;
    U2;
    U3;
    U4;
    VF1;
    VF2;
    VF3;
    VF4;
    VS1;
    VS2;
    VS3;
    VS4;
    VU1;
    VU2;
    VU3;
    VU4;
    M2;
    M3;
    M4;
    VM2;
    VM3;
    VM4;
}

operator == :: (a: Shader, b: Shader) -> bool {
    return a.vertex == b.vertex && a.fragment == b.fragment;
}

free :: (shader: Shader) {
    free(shader.vertex);
    free(shader.fragment);
    for uniform: shader.uniforms {
        free(uniform);
    }

    glDeleteProgram(shader.program_);
}

free :: (uniform: ShaderUniform) {
    free(uniform.name);
    free(uniform.data);
}

set_uniform :: (shader: *Shader, name: string, data: $T) {
    #if #run type_info(T).type == .ARRAY {
        assert(false, "Cannot set a uniform array using this function.");
    }

    #if #run T == s64 {
        set_uniform(shader, name, cast(s32) data);
        return;
    }

    size := size_of(T);
    type := get_uniform_type(T);
    set_uniform_data(shader, name, *data, size, type);
}

set_uniform :: (shader: *Shader, name: string, data: [] $T) {
    size := data.count * size_of(T);
    type := get_uniform_array_type(T);
    set_uniform_data(shader, name, data.data, size, type);
}

get_uniform_type :: ($T: Type) -> ShaderUniformType {
    #insert #run () -> string {
        if T == float return "return .F1;";
        if T == Vector2 return "return .F2;";
        if T == Vector3 return "return .F3;";
        if T == Vector4 return "return .F4;";
        if T == Color return "return .F4;";
        if T == s32 return "return .S1;";
        if T == [2] s32 return "return .S2;";
        if T == [3] s32 return "return .S3;";
        if T == [4] s32 return "return .S4;";
        if T == u32 return "return .U1;";
        if T == [2] u32 return "return .U2;";
        if T == [3] u32 return "return .U3;";
        if T == [4] u32 return "return .U4;";
        if T == Matrix2 return "return .M2;";
        if T == Matrix3 return "return .M3;";
        if T == Matrix4 return "return .M4;";
        // print("Invalid uniform type: %\n", T);
        return #string DONE
        assert(false, tprint("Invalid unform type. %", T));
        return .Invalid;
        DONE;
    }();
}

get_uniform_array_type :: ($T: Type) -> ShaderUniformType {
    #insert #run () -> string {
        if T == float return "return .VF1;";
        if T == Vector2 return "return .VF2;";
        if T == Vector3 return "return .VF3;";
        if T == Vector4 return "return .VF4;";
        if T == s32 return "return .VS1;";
        if T == [2] s32 return "return .VS2;";
        if T == [3] s32 return "return .VS3;";
        if T == [4] s32 return "return .VS4;";
        if T == u32 return "return .VU1;";
        if T == [2] u32 return "return .VU2;";
        if T == [3] u32 return "return .VU3;";
        if T == [4] u32 return "return .VU4;";
        if T == Matrix2 return "return .VM2;";
        if T == Matrix3 return "return .VM3;";
        if T == Matrix4 return "return .VM4;";
        
        print("Uniform array type: %\n", T);
        assert(false, "Invalid uniform array type.");
    }();
}

initialize_shader :: (shader: *Shader) -> bool {
    make_shader_object :: (shader: string, shader_type: GLenum) -> GLuint, bool {
        shader_object := glCreateShader(shader_type);

		length: GLint = xx shader.count;
        glShaderSource(shader_object, 1, *shader.data, *length);

        glCompileShader(shader_object);

        success: GLint;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);

        if !success {
            log: [512] u8;
            glGetShaderInfoLog(shader_object, 512, null, log.data);
            print("[Shader] %\n", to_string(log.data));
            return 0, false;
        }

        return shader_object, true;
    }

    shader_v, success_v := make_shader_object(shader.vertex, GL_VERTEX_SHADER);
    shader_f, success_f := make_shader_object(shader.fragment, GL_FRAGMENT_SHADER);
    shader.program_ = glCreateProgram();

    defer glDeleteShader(shader_v);
    defer glDeleteShader(shader_f);

    if !success_v || !success_f || !shader.program_ {
        print("[Shader] Failure initalizing shader. %\n", << shader);
        assert(false);
        // return false;
    }

    glAttachShader(shader.program_, shader_v);
    glAttachShader(shader.program_, shader_f);
    glLinkProgram(shader.program_);

    success: GLint = 0;
    glGetProgramiv(shader.program_, GL_LINK_STATUS, *success);

    if !success {
        log: [512] u8;
        glGetProgramInfoLog(shader.program_, 512, null, log.data);

        print("[Shader] %\n", to_string(log.data));

        assert(false);
        // return false;
    }

    return true;
}

// TODO delete
get_uniform_location :: (shader: Shader, name: *u8) -> GLint {
    location := glGetUniformLocation(shader.program_, name);
    // TODO apparently we don't care if it returns -1?
    // print("Shader program. %\n", shader.program_);
    // if location == -1 {
    //     print("Could not get uniform location.\n%\n%\n%\n%\n", location, shader.program_, get_string(name), shader.vertex);
    //     assert(false);
    // }

    return location;
}

use_shader :: (shader: *Shader) {
    if !shader.program_ {
        print("Initializing shader.\n%\n", shader.vertex);
        
        if !initialize_shader(shader) {
            print("Error applying shader. %\n", << shader);
            return;
        }

        for *uniform: shader.uniforms {
            update_uniform_location(<< shader, uniform);
        }
    }

    if koda.shader != null && << shader == << koda.shader {
        // print("Early returning shader apply.\n%\n%\n", shader.vertex, koda.shader.vertex);
        return;
    }

    glUseProgram(shader.program_);

    koda.shader = shader;
}

apply_uniforms :: (shader: Shader) {
    for uniform: shader.uniforms {
        apply_uniform(uniform);
    }
}

#scope_module

DEFAULT_VERTEX_SHADER :: #string DONE
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;

out vec2 vTexCoord;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;

uniform vec2 uPos;
uniform vec2 uDim;
// uniform vec2 uOriginalDim;
uniform vec2 uScreenDim;
uniform vec4 uFrame;

void main() {
    vec2 dimScale = uDim / uScreenDim;
    vec2 posOffset = uPos / uScreenDim * vec2(2.0, -2.0);

    // gl_Position = vec4(aPos.xy, 0.0, 1.0);
    // gl_Position = projection * view * model * vec4((aPos + vec2(1.0, -1.0)) * dimScale + posOffset - vec2(1.0, -1.0), 0.0, 1.0);
    gl_Position = projection * view * model * vec4((aPos + 1.0) / 2.0 * uDim + uPos, 0.0, 1.0);
    
    // vTexCoord = aTexCoord; // aTexCoord * uFrame.zw + uFrame.xy;
    vTexCoord = aTexCoord * uFrame.zw + uFrame.xy;
}
DONE

DEFAULT_FRAGMENT_SHADER :: #string DONE
#version 330 core
out vec4 FragColor;
  
in vec2 vTexCoord;

uniform sampler2D uTexture;
uniform vec4 uTint;

void main() {
    FragColor = texture(uTexture, vTexCoord) * uTint;
}
DONE

DEFAULT_ELLIPSE_VERTEX_SHADER :: #string DONE
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;

out vec2 vTexCoord;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;

uniform vec2 uPos;
uniform vec2 uDim;
// uniform vec2 uOriginalDim;
uniform vec2 uScreenDim;
uniform vec4 uFrame;

void main() {
    vec2 dimScale = uDim / uScreenDim;
    vec2 posOffset = uPos / uScreenDim * vec2(2.0, -2.0);

    gl_Position = projection * view * model * vec4((aPos + 1.0) / 2.0 * uDim + uPos, 0.0, 1.0);
    
    vTexCoord = aTexCoord * uFrame.zw + uFrame.xy;
}
DONE

DEFAULT_ELLIPSE_FRAGMENT_SHADER :: #string DONE
#version 330 core
out vec4 FragColor;
  
in vec2 vTexCoord;

uniform vec4 uTint;
uniform vec4 uBorderTint;

void main() {
    vec2 fromCenter = vTexCoord * 2.0 - 1.0;
    float distance = length(fromCenter);
    // can use that one function to get the pixel density and scale appropriately instead of hard edges
    float color = distance <= 1.0 ? 1.0 : 0.0;
    float border = distance > 0.94 && distance <= 1.0 ? 1.0 : 0.0;

    // TODO use whatever that pixel density function is

    vec4 averageColor = (uTint * uTint.a * color + uBorderTint * uBorderTint.a * border) / (uTint.a * color + uBorderTint.a * border);

    FragColor = averageColor * max(uTint.a * color, uBorderTint.a * border);
}
DONE

#scope_file

get_uniform :: (shader: *Shader, name: string) -> *ShaderUniform {
    for i: 0..shader.uniforms.count - 1 {
        if shader.uniforms[i].name == name {
            return *shader.uniforms[i];
        }
    }

    return null;
}

set_uniform_data :: (shader: *Shader, name: string, pointer: *void, size: int, type: ShaderUniformType) {
    uniform: *ShaderUniform = get_uniform(shader, name);
    if !uniform {
        empty: ShaderUniform;
        empty.name = copy_string(name);
        empty.type = type;
        empty.data = alloc(size);
        empty.size = size;

        array_add(*shader.uniforms, empty);
        uniform = *shader.uniforms[shader.uniforms.count - 1];
    } else {
        assert(uniform.type == type, "You cannot change the types of uniforms between calls.");
        assert(uniform.size == size, "I don't think you can change the size of uniforms between calls?");
    }

    update_uniform_location(<< shader, uniform);

    // if uniform.size != size {
        // free(uniform.data);
        // uniform.data = alloc(size);
        // uniform.size = size;
    // }

    memcpy(uniform.data, pointer, size);
}

update_uniform_location :: (shader: Shader, uniform: *ShaderUniform) {
    if uniform.location != -1 || shader.program_ == 0 {
        return;
    }

    name := temp_c_string(uniform.name);
    uniform.location = glGetUniformLocation(shader.program_, name);
}

apply_uniform :: (uniform: ShaderUniform) {
    if uniform.location == -1 {
        return;
    }

    if uniform.type == {
        case .F1;
            data := << cast(*float) uniform.data;
            glUniform1f(uniform.location, data);
        case .F2;
            data := cast(*Vector2) uniform.data;
            glUniform2f(uniform.location, data.x, data.y);
        case .F3;
            data := cast(*Vector3) uniform.data;
            glUniform3f(uniform.location, data.x, data.y, data.z);
        case .F4;
            data := cast(*Vector4) uniform.data;
            glUniform4f(uniform.location, data.x, data.y, data.z, data.w);
        case .S1;
            data := << cast(*s32) uniform.data;
            glUniform1i(uniform.location, data);
        case .S2;
            data := << cast(*[2] s32) uniform.data;
            glUniform2i(uniform.location, data[0], data[1]);
        case .S3;
            data := << cast(*[3] s32) uniform.data;
            glUniform3i(uniform.location, data[0], data[1], data[2]);
        case .S4;
            data := << cast(*[4] s32) uniform.data;
            glUniform4i(uniform.location, data[0], data[1], data[2], data[3]);
        case .U1;
            data := << cast(*u32) uniform.data;
            glUniform1ui(uniform.location, data);
        case .U2;
            data := << cast(*[2] u32) uniform.data;
            glUniform2ui(uniform.location, data[0], data[1]);
        case .U3;
            data := << cast(*[3] u32) uniform.data;
            glUniform3ui(uniform.location, data[0], data[1], data[2]);
        case .U4;
            data := << cast(*[4] u32) uniform.data;
            glUniform4ui(uniform.location, data[0], data[1], data[2], data[3]);
        case .VF1;
            data := cast(*float) uniform.data;
            glUniform1fv(uniform.location, cast(u32) uniform.size / size_of(float), data);
        case .VF2;
            data := cast(*float) uniform.data;
            glUniform2fv(uniform.location, cast(u32) uniform.size / size_of(Vector2), data);
        case .VF3;
            data := cast(*float) uniform.data;
            glUniform3fv(uniform.location, cast(u32) uniform.size / size_of(Vector3), data);
        case .VF4;
            data := cast(*float) uniform.data;
            glUniform4fv(uniform.location, cast(u32) uniform.size / size_of(Vector4), data);
        case .VS1;
            data := cast(*s32) uniform.data;
            glUniform1iv(uniform.location, cast(u32) uniform.size / size_of(s32), data);
        case .VS2;
            data := cast(*s32) uniform.data;
            glUniform2iv(uniform.location, cast(u32) uniform.size / size_of([2] s32), data);
        case .VS3;
            data := cast(*s32) uniform.data;
            glUniform3iv(uniform.location, cast(u32) uniform.size / size_of([3] s32), data);
        case .VS4;
            data := cast(*s32) uniform.data;
            glUniform4iv(uniform.location, cast(u32) uniform.size / size_of([4] s32), data);
        case .VU1;
            data := cast(*u32) uniform.data;
            glUniform1uiv(uniform.location, cast(u32) uniform.size / size_of(u32), data);
        case .VU2;
            data := cast(*u32) uniform.data;
            glUniform2uiv(uniform.location, cast(u32) uniform.size / size_of([2] u32), data);
        case .VU3;
            data := cast(*u32) uniform.data;
            glUniform3uiv(uniform.location, cast(u32) uniform.size / size_of([3] u32), data);
        case .VU4;
            data := cast(*u32) uniform.data;
            glUniform4uiv(uniform.location, cast(u32) uniform.size / size_of([4] u32), data);
        case .M2;
            data := cast(*float) uniform.data;
            glUniform2fv(uniform.location, 1, data);
        case .M3;
            data := cast(*float) uniform.data;
            glUniform3fv(uniform.location, 1, data);
        case .M4;
            data := cast(*float) uniform.data;
            glUniform4fv(uniform.location, 1, data);
        case .VM2;
            data := cast(*float) uniform.data;
            glUniform2fv(uniform.location, cast(u32) uniform.size / size_of(Matrix2), data);
        case .VM3;
            data := cast(*float) uniform.data;
            glUniform3fv(uniform.location, cast(u32) uniform.size / size_of(Matrix3), data);
        case .VM4;
            data := cast(*float) uniform.data;
            glUniform4fv(uniform.location, cast(u32) uniform.size / size_of(Matrix4), data);
        case;
            assert(false, "Unknown uniform type.");
    }
}

#import "Basic";