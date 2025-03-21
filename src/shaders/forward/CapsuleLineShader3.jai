
capsule_line_shader3 := #run create_shader(CAPSULE_LINE_VERTEX_SHADER3, CAPSULE_LINE_FRAGMENT_SHADER3);

#scope_module

CAPSULE_LINE_VERTEX_SHADER3 :: #string ___glsl
#version 330 core
layout (location = 0) in vec3 aPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;
uniform float uHalfLength;
uniform float uRadius;

void main() {
    vec3 pos = (aPos - vec3(0.0, sign(aPos.y), 0.0)) * uRadius;
    pos = pos + vec3(0.0, sign(aPos.y), 0.0) * uHalfLength;

    gl_Position = projection * view * model * vec4(pos, 1.0);
}
___glsl

CAPSULE_LINE_FRAGMENT_SHADER3 :: #string ___glsl
#version 330 core
out vec4 FragColor;

uniform vec4 uTint;

void main() {
    FragColor = uTint;
}
___glsl