ShadowProjectionShader :: struct {
    using #as shader: Shader;

    shader.vertex = SHADOW_PROJECTION_VERTEX_SHADER;
    // shader.fragment = SHADOW_PROJECTION_FRAGMENT_SHADER;
}

#scope_module

SHADOW_PROJECTION_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec3 aPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main() {
    vec4 clipSpace = projection * view * model * vec4(aPos, 1.0);
    clipSpace.z = max(clipSpace.z, -clipSpace.w);
    gl_Position = clipSpace;
}
___glsl

SHADOW_PROJECTION_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

void main() {

}
___glsl;