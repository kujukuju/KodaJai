
SharpenShader :: struct {
    using #as shader: Shader;

    shader.vertex = SHARPEN_VERTEX_SHADER;
    shader.fragment = SHARPEN_FRAGMENT_SHADER;
}

#scope_module

SHARPEN_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec2 aPos;

uniform mat4 view;

out vec2 vCoord;
out vec3 vCamera;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;
    vCamera = vec3(inverse(view) * vec4(0.0, 0.0, 0.0, 1.0));

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

SHARPEN_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out vec4 FragColor;

const float amount = 0.1;

uniform sampler2D uColor;

in vec2 vCoord;
in vec3 vCamera;

void main() {
    // vec3 color = texture(uColor, vCoord).rgb;
    vec2 textureSize = textureSize(uColor, 0);

    float neighbor = amount * -1.0;
    float center = amount * 4.0 + 1.0;

    vec3 color = texture(uColor, vCoord + vec2(0, 1) / textureSize).rgb * neighbor +
        texture(uColor, vCoord + vec2(-1, 0) / textureSize).rgb * neighbor +
        texture(uColor, vCoord + vec2(0, 0) / textureSize).rgb * center +
        texture(uColor, vCoord + vec2(1, 0) / textureSize).rgb * neighbor +
        texture(uColor, vCoord + vec2(0, -1) / textureSize).rgb * neighbor;

    FragColor = vec4(color, 1.0);
}
___glsl