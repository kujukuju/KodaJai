
default_shader := #run create_shader(DEFAULT_VERTEX_SHADER, DEFAULT_FRAGMENT_SHADER);

#scope_module

DEFAULT_VERTEX_SHADER :: #string ___glsl
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;

out vec2 vTexCoord;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;

uniform vec2 uDim;
uniform vec2 uScreenDim;
uniform vec4 uFrame;

void main() {
    gl_Position = projection * view * model * vec4(aPos, 0.0, 1.0);

    vTexCoord = aTexCoord * uFrame.zw + uFrame.xy;
}
___glsl

DEFAULT_FRAGMENT_SHADER :: #string ___glsl
#version 330 core
out vec4 FragColor;

in vec2 vTexCoord;

uniform sampler2D uTexture;
uniform vec4 uTint;

void main() {
    FragColor = texture(uTexture, vTexCoord) * uTint;
}
___glsl