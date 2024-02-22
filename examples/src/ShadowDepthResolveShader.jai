ShadowDepthResolveShader :: struct {
    using #as shader: Shader;

    shader.vertex = SHADOW_DEPTH_RESOLVE_VERTEX_SHADER;
    shader.fragment = SHADOW_DEPTH_RESOLVE_FRAGMENT_SHADER;
}

#scope_module

SHADOW_DEPTH_RESOLVE_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec2 aPos;

out vec2 vCoord;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

SHADOW_DEPTH_RESOLVE_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out vec4 FragColor;

uniform sampler2D uDepth;

in vec2 vCoord;

void main() {
    float depth = texture(uDepth, vCoord).r;
    depth = depth * 2.0;
    depth = pow(depth, 20.0);

    FragColor = vec4(vec3(depth), 1.0);
}
___glsl;