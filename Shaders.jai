Shader :: struct {
    vertex: string;
    fragment: string;
    program_: GLuint;
}

operator == :: (a: Shader, b: Shader) -> bool {
    return a.vertex == b.vertex && a.fragment == b.fragment;
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
    if << shader == koda.shader {
        // print("Early returning shader apply.\n%\n%\n", shader.vertex, koda.shader.vertex);
        return;
    }

    if !shader.program_ {
        print("Initializing shader.\n%\n", shader.vertex);
        
        if !initialize_shader(shader) {
            print("Error applying shader. %\n", << shader);
            return;
        }
    }

    glUseProgram(shader.program_);

    koda.shader = << shader;
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

#import "Basic";