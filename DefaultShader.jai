DefaultShader :: struct {
    using shader: Shader;

    shader.vertex = DEFAULT_VERTEX_SHADER;
    shader.fragment = DEFAULT_FRAGMENT_SHADER;
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
uniform float uRot;
uniform vec2 uDim;
// uniform vec2 uOriginalDim;
uniform vec2 uScreenDim;
uniform vec4 uFrame;

vec2 rotate(vec2 v, float theta) {
    float ct = cos(theta);
    float st = sin(theta);

    vec2 r = vec2(v.x * ct + v.y * -st, v.x * st + v.y * ct);

    return r;
}

void main() {
    vec2 dimScale = uDim / uScreenDim;
    vec2 posOffset = uPos / uScreenDim * vec2(2.0, -2.0);

    // gl_Position = vec4(aPos.xy, 0.0, 1.0);
    // gl_Position = projection * view * model * vec4((aPos + vec2(1.0, -1.0)) * dimScale + posOffset - vec2(1.0, -1.0), 0.0, 1.0);
    gl_Position = projection * view * model * vec4(rotate((aPos + 1.0) / 2.0 * uDim, uRot) + uPos, 0.0, 1.0);
    
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