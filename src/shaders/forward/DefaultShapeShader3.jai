
default_shape_shader3 := #run create_shader(DEFAULT_SHAPE_VERTEX_SHADER3, DEFAULT_SHAPE_FRAGMENT_SHADER3);

#scope_module

DEFAULT_SHAPE_VERTEX_SHADER3 :: #string ___glsl
#version 330 core
layout (location = 0) in vec3 aPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main() {
    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
___glsl

DEFAULT_SHAPE_FRAGMENT_SHADER3 :: #string ___glsl
#version 330 core
out vec4 FragColor;

uniform vec4 uTint = vec4(1.0, 1.0, 1.0, 1.0);

void main() {
    FragColor = uTint;
}
___glsl