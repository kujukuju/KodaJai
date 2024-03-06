InstancedShader2 :: struct {
    using #as shader: Shader;

    shader.name = "InstancedShader2";
    shader.vertex = INSTANCED_VERTEX_SHADER2;
    shader.fragment = INSTANCED_FRAGMENT_SHADER2;
}

instanced_shader2: InstancedShader2;

#scope_module

INSTANCED_VERTEX_SHADER2 :: #string DONE
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTex;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;
uniform vec2 offsets[1000];

out vec2 vTex;

void main() {
    vec2 pos = aPos + offsets[gl_InstanceID];
    vTex = aTex;

    gl_Position = projection * view * model * vec4(pos, 0.0, 1.0);
}
DONE

INSTANCED_FRAGMENT_SHADER2 :: #string DONE
#version 330 core
out vec4 FragColor;

uniform vec4 uTint;

in vec2 vTex;

void main() {
    vec2 fromCenter = vTex * 2.0 - 1.0;
    float distance = dot(fromCenter, fromCenter);

    // can use that one function to get the pixel density and scale appropriately instead of hard edges
    float color = distance <= 1.0 ? 1.0 : 0.0;

    FragColor = uTint * uTint.a * color;
}
DONE