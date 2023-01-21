FlatGridShader3 :: struct {
    using #as shader: Shader;

    shader.vertex = FLAT_GRID_VERTEX_SHADER3;
    shader.fragment = FLAT_GRID_FRAGMENT_SHADER3;
}

#scope_module

FLAT_GRID_VERTEX_SHADER3 :: #string DONE
#version 330 core
layout (location = 0) in vec3 aPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 vPos;

void main() {
    vPos = aPos;

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
DONE

FLAT_GRID_FRAGMENT_SHADER3 :: #string DONE
#version 330 core
out vec4 FragColor;

uniform vec4 uTint;
uniform float uRadius;

in vec3 vPos;

void main() {
    float sub = 1.0;
    float alpha = 1.0;
    if (uRadius > 0.0) {
        sub = clamp((uRadius - length(vPos)) / 10.0, 0.0, 1.0);
        sub = pow(sub, 0.25);
        alpha = clamp((uRadius - length(vPos)) / uRadius, 0.0, 1.0);
        alpha = sqrt(alpha) * 0.75 + 0.25;
    }
    FragColor = uTint * alpha * sub;
}
DONE