
default_shape_color_shader3 := #run create_shader(DEFAULT_SHAPE_COLOR_VERTEX_SHADER3, DEFAULT_SHAPE_COLOR_FRAGMENT_SHADER3);

#scope_module

DEFAULT_SHAPE_COLOR_VERTEX_SHADER3 :: #string ___glsl
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 vColor;

void main() {
    vColor = aColor;

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
___glsl

DEFAULT_SHAPE_COLOR_FRAGMENT_SHADER3 :: #string ___glsl
#version 330 core
out vec4 FragColor;

uniform vec4 uTint = vec4(1.0, 1.0, 1.0, 1.0);

in vec3 vColor;

void main() {
    FragColor = uTint * vec4(vColor, 1.0);
}
___glsl