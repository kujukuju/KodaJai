
float_copy_shader := #run create_shader(FLOAT_COPY_VERTEX_SHADER, FLOAT_COPY_FRAGMENT_SHADER);

#scope_module

FLOAT_COPY_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec2 aPos;

out vec2 vCoord;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

FLOAT_COPY_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out float FragColor;

uniform sampler2D uCopy;

in vec2 vCoord;

void main() {
    float value = texture(uCopy, vCoord).r;

    FragColor = value;
}
___glsl;