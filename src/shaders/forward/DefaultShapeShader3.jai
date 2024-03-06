DefaultShapeShader3 :: struct {
    using #as shader: Shader;

    shader.name = "DefaultShapeShader3";
    shader.vertex = DEFAULT_SHAPE_VERTEX_SHADER3;
    shader.fragment = DEFAULT_SHAPE_FRAGMENT_SHADER3;
}

default_shape_shader3: DefaultShapeShader3;

#scope_module

DEFAULT_SHAPE_VERTEX_SHADER3 :: #string DONE
#version 330 core
layout (location = 0) in vec3 aPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main() {
    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
DONE

DEFAULT_SHAPE_FRAGMENT_SHADER3 :: #string DONE
#version 330 core
out vec4 FragColor;

uniform vec4 uTint;

void main() {
    FragColor = uTint;
}
DONE